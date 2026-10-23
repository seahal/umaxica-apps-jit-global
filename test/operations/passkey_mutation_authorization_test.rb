# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class PasskeyMutationAuthorizationTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  # These token references must exist even on a newly migrated database.
  fixtures :client_token_binding_methods, :visitor_token_binding_methods, :operator_token_binding_methods,
           :client_token_dbsc_statuses, :visitor_token_dbsc_statuses, :operator_token_dbsc_statuses

  test "passkey removal requires scoped evidence in app com and org even when another key survives" do
    [[Client, ClientPasskey, ClientToken, :user_id],
     [Visitor, VisitorPasskey, VisitorToken, :visitor_id],
     [Operator, OperatorPasskey, OperatorToken, :staff_id],].each do |actor_class, key_class, token_class, owner_key|
      actor = actor_class.create!(security_mode_id: SecurityModeTestDefault.id_for(actor_class))
      token = token_class.create!(:authentication_epoch => 0, owner_key => actor.id)
      metadata = (key_class == OperatorPasskey) ? {} : { uv_verified_at: Time.current }
      key_class.create!(
        owner_key => actor.id, :webauthn_id => SecureRandom.uuid,
        :public_key => "surviving-key", **metadata,
      )
      target = key_class.create!(
        owner_key => actor.id, :webauthn_id => SecureRandom.uuid,
        :public_key => "target-key", **metadata,
      )
      status = target.status_id

      assert_not IdentityCredentialRemovalCommitter.call!(actor: actor, credential: target, current_session: token),
                 "#{actor_class} must refuse missing step-up evidence"
      assert_equal status, target.reload.status_id
      assert_nil token.reload.last_step_up_at

      reference = (key_class == OperatorPasskey) ? target.external_id : target.public_id
      surface = { Client => "app", Visitor => "com", Operator => "org" }.fetch(actor_class)
      evidence = {
        last_step_up_at: Time.current,
        last_step_up_scope: "settings_passkey",
        last_step_up_method: "passkey",
        last_step_up_credential_ref: reference,
        last_step_up_session_public_id: token.public_id,
        last_step_up_purpose: "step_up",
        last_step_up_audience: "step_up:#{surface}",
        last_step_up_phishing_resistant: true,
        last_step_up_user_verified: true,
        last_step_up_full_reauthentication: false,
      }
      [{ last_step_up_scope: "settings_email" }, { last_step_up_scope: "" },
       { last_step_up_at: 16.minutes.ago }, { last_step_up_at: 1.minute.from_now },
       { last_step_up_session_public_id: "foreign-session" }, { last_step_up_audience: "step_up:foreign" },
       { last_step_up_credential_ref: "missing-credential" }, { last_step_up_user_verified: nil },].each do |invalid|
        token.update!(evidence.merge(invalid))

        assert_not IdentityCredentialRemovalCommitter.call!(actor: actor, credential: target, current_session: token),
                   "#{actor_class} must refuse #{invalid.keys.join(", ")}"
        assert_equal status, target.reload.status_id
      end
    end
  end

  [false, true].each do |revoked|
    test "registration finalization #{revoked ? "refuses revoked" : "accepts current"} existing authority" do
      actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
      existing = actor.client_passkeys.create!(
        webauthn_id: SecureRandom.uuid, public_key: "existing-key", uv_verified_at: Time.current,
      )
      token = ClientToken.create!(authentication_epoch: 0, user: actor, root_login_established_at: Time.current)
      token.update!(
        last_step_up_at: Time.current, last_step_up_scope: "settings_passkey", last_step_up_method: "passkey",
        last_step_up_credential_ref: existing.public_id, last_step_up_session_public_id: token.public_id,
        last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
        last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
        last_step_up_full_reauthentication: false,
      )
      requirement = StepUpRequirement.new(
        scope: "settings_passkey", purpose: "credential_registration", step_up_required: false,
        allowed_methods: [:passkey], phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
        resource_ref: nil, tenant_ref: nil, audience: "step_up:app", session_binding: token.public_id,
        token_binding: token.public_id, require_session_binding: true,
      )
      transaction = BaseStepUpAdmissionIssuer.call!(
        actor: actor, token: token, requirement: requirement, return_to: "/identity/passkeys",
        base_browser_nonce: SecureRandom.urlsafe_base64, base_token: token,
      ).transaction
      record = ClientStepUpSession.find_by!(step_up_ceremony_transaction_ref: transaction.transaction_id)
      ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
        admission_purpose: "credential_registration_handoff",
        step_up_ceremony_transaction_ref: transaction.transaction_id,
      )
      fake = WebAuthn::FakeClient.new("https://auth.umaxica.app", encoding: :base64url)
      config = Webauthn::RelyingPartyConfig.new(rp_id: "auth.umaxica.app", origin: fake.origin)
      challenge = SecureRandom.urlsafe_base64(32)
      reference = record.issue_bound_passkey_registration_challenge!(
        transaction: transaction, challenge: challenge, rp_id: config.rp_id, origin: config.origin,
      )
      IdentityPasskeyRegistrationVerificationCommitter.call!(
        actor: actor, token: token, transaction: transaction, session_record: record, config: config,
        reference: reference, credential_params: fake.create(challenge: challenge, user_verified: true),
        description: "New passkey",
      )
      result = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: transaction.reload, ceremony_session_ref: ceremony.id.to_s,
      )
      existing.update!(status_id: ClientPasskeyStatus::REVOKED) if revoked

      if revoked
        assert_no_difference -> { actor.client_passkeys.count } do
          assert_raises(IdentityPasskeyCeremonyContract::Error) do
            IdentityPasskeyRegistrationFinalCommitter.call!(
              actor: actor, token: token, transaction: transaction, raw_result: result.code,
            )
          end
        end
        assert_equal "verified", transaction.reload.status
      else
        assert_difference -> { actor.client_passkeys.count }, 1 do
          IdentityPasskeyRegistrationFinalCommitter.call!(
            actor: actor, token: token, transaction: transaction, raw_result: result.code,
          )
        end
        assert_equal "consumed", transaction.reload.status
      end
    end
  end

  test "passkey policy freshness is exclusive at fifteen minutes and refuses a future event at microsecond precision" do
    [[Client, ClientPasskey, ClientToken, ClientPasskeyPolicy, :user_id, "app"],
     [Visitor, VisitorPasskey, VisitorToken, VisitorPasskeyPolicy, :visitor_id, "com"],
     [Operator, OperatorPasskey, OperatorToken, OperatorPasskeyPolicy, :staff_id, "org"],].each do |
      actor_class, key_class, token_class, policy_class, owner_key, surface|
      actor = actor_class.create!(security_mode_id: SecurityModeTestDefault.id_for(actor_class))
      token = token_class.create!(:authentication_epoch => 0, owner_key => actor.id)
      token.rotate_refresh_token!
      metadata = (key_class == OperatorPasskey) ? {} : { uv_verified_at: Time.current }
      key = key_class.create!(
        owner_key => actor.id, :webauthn_id => SecureRandom.uuid, :public_key => "evidence-key", **metadata,
      )
      reference = (key_class == OperatorPasskey) ? key.external_id : key.public_id
      now = token_class.database_now
      token.update!(
        last_step_up_scope: "settings_passkey", last_step_up_method: "passkey",
        last_step_up_credential_ref: reference, last_step_up_session_public_id: token.public_id,
        last_step_up_purpose: "step_up", last_step_up_audience: "step_up:#{surface}",
        last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
        last_step_up_full_reauthentication: false,
      )
      policy = policy_class.new(key, user: actor)
      microsecond = Rational(1, 1_000_000)
      [[now - 15.minutes - microsecond, false], [now - 15.minutes, false],
       [now - 15.minutes + microsecond, true], [now - microsecond, true],
       [now, true], [now + microsecond, false],].each do |event_at, expected|
        token.update!(last_step_up_at: event_at)

        assert_equal expected, policy.management_authorized?(token: token.reload, now: now),
                     "#{surface}: event #{event_at.iso8601(6)} evaluated at #{now.iso8601(6)}"
      end
      token.update!(last_step_up_at: now)
      foreign_actor = actor_class.create!(security_mode_id: SecurityModeTestDefault.id_for(actor_class))
      foreign_key = key_class.create!(
        owner_key => foreign_actor.id, :webauthn_id => SecureRandom.uuid,
        :public_key => "foreign-key", :description => "Foreign", **metadata,
      )

      assert_raises(IdentityPasskeyNameCommitter::Denied) do
        IdentityPasskeyNameCommitter.call!(actor: actor, token: token, passkey: foreign_key, description: "Changed")
      end
      assert_equal "Foreign", foreign_key.reload.description
      assert_raises(ArgumentError) do
        IdentityCredentialRemovalCommitter.call!(actor: actor, credential: foreign_key, current_session: token)
      end
    end
  end

  test "app and com passkey management accept active verified and signup-verified email evidence" do
    [[Client, ClientEmail, ClientToken, ClientPasskeyPolicy, :user_id, :user_email_status_id, "app"],
     [Visitor, VisitorEmail, VisitorToken, VisitorPasskeyPolicy, :visitor_id, :visitor_email_status_id,
      "com",],].each do |actor_class, email_class, token_class, policy_class, owner_key, status_key, surface|
      statuses =
        if actor_class == Client
          [ClientEmailStatus::VERIFIED, ClientEmailStatus::VERIFIED_WITH_SIGN_UP]
        elsif actor_class == Visitor
          [VisitorEmailStatus::VERIFIED, VisitorEmailStatus::VERIFIED_WITH_SIGN_UP]
        else
          raise ArgumentError, "unsupported email owner"
        end
      statuses.each do |status|
        actor = actor_class.create!(security_mode_id: SecurityModeTestDefault.id_for(actor_class))
        email = email_class.create!(
          owner_key => actor.id, status_key => status, :address => "policy-#{SecureRandom.hex(8)}@example.test",
        )
        email.finalize_binding!
        token = token_class.create!(:authentication_epoch => 0, owner_key => actor.id)
        now = token_class.database_now
        token.update!(
          last_step_up_at: now, last_step_up_scope: "settings_passkey", last_step_up_method: "email_otp",
          last_step_up_credential_ref: email.public_id, last_step_up_session_public_id: token.public_id,
          last_step_up_purpose: "step_up", last_step_up_audience: "step_up:#{surface}",
          last_step_up_phishing_resistant: false, last_step_up_user_verified: false,
          last_step_up_full_reauthentication: false,
        )

        assert policy_class.new(user: actor).management_authorized?(token: token, now: now), "#{surface}: #{status}"
        email.release_binding!(at: email_class.database_now)

        assert_not policy_class.new(user: actor).management_authorized?(token: token, now: now)
      end
    end
  end

  test "app passkey management accepts usable TOTP evidence and refuses it after revocation" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    totp = actor.client_totp_credentials.create!(
      private_key: ROTP::Base32.random_base32,
      user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    now = ClientToken.database_now
    token.update!(
      last_step_up_at: now, last_step_up_scope: "settings_passkey", last_step_up_method: "totp",
      last_step_up_credential_ref: totp.public_id, last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
      last_step_up_phishing_resistant: false, last_step_up_user_verified: false,
      last_step_up_full_reauthentication: false,
    )

    assert ClientPasskeyPolicy.new(user: actor).management_authorized?(token: token, now: now)
    totp.update!(user_identity_totp_credential_status_id: ClientTotpCredentialStatus::REVOKED)

    assert_not ClientPasskeyPolicy.new(user: actor).management_authorized?(token: token, now: now)
  end
end
