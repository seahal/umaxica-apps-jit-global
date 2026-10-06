# frozen_string_literal: true

require "test_helper"

class IdentityCredentialRemovalCommitterTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a temporarily locked Email refuses last Passkey removal without clearing authority" do
    %i(app com).each do |surface|
      actor, token, passkey, email =
        if surface == :app
          actor = Client.create!(id: 9_111_000_000_000)
          email = actor.client_emails.create!(
            address: "locked-app-#{SecureRandom.hex(8)}@example.com",
            user_email_status_id: ClientEmailStatus::VERIFIED,
            step_up_otp_locked_until: Client.database_now + 1.hour,
          )
          passkey = actor.client_passkeys.create!(
            webauthn_id: SecureRandom.uuid, public_key: "last-key",
            uv_verified_at: Time.current,
          )
          [actor, ClientToken.create!(user: actor), passkey, email]
        else
          actor = Visitor.create!(id: 9_111_000_000_000)
          email = actor.visitor_emails.create!(
            address: "locked-com-#{SecureRandom.hex(8)}@example.com",
            visitor_email_status_id: VisitorEmailStatus::VERIFIED,
            step_up_otp_locked_until: Visitor.database_now + 1.hour,
          )
          passkey = actor.visitor_passkeys.create!(
            webauthn_id: SecureRandom.uuid, public_key: "last-key",
            uv_verified_at: Time.current,
          )
          [actor, VisitorToken.create!(visitor: actor), passkey, email]
        end
      token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_passkey")
      event = token.last_step_up_at
      status = passkey.status_id
      locked_until = email.step_up_otp_locked_until

      assert_not IdentityCredentialRemovalCommitter.call!(actor: actor, credential: passkey, current_session: token)
      assert_equal status, passkey.reload.status_id
      assert_equal event, token.reload.last_step_up_at
      assert_equal locked_until, email.reload.step_up_otp_locked_until
      assert_predicate token, :currently_usable?
    end
  end

  test "an expired Passkey or Email fallback cannot authorize removal of the usable Passkey" do
    %i(app com).each do |surface|
      %i(passkey email).each_with_index do |fallback_kind, index|
        actor, token, target, fallback =
          if surface == :app
            actor = Client.create!(id: 9_109_000_000_000 + index)
            target = actor.client_passkeys.create!(
              webauthn_id: SecureRandom.uuid, public_key: "usable-key",
              uv_verified_at: Time.current,
            )
            fallback =
              if fallback_kind == :passkey
                actor.client_passkeys.create!(
                  webauthn_id: SecureRandom.uuid, public_key: "expired-key",
                  uv_verified_at: Time.current,
                )
              else
                actor.client_emails.create!(
                  address: "expired-app-#{SecureRandom.hex(8)}@example.com",
                  user_email_status_id: ClientEmailStatus::VERIFIED,
                )
              end
            [actor, ClientToken.create!(user: actor), target, fallback]
          else
            actor = Visitor.create!(id: 9_109_000_000_000 + index)
            recovery = actor.visitor_emails.create!(
              address: "expired-com-#{SecureRandom.hex(8)}@example.com",
              visitor_email_status_id: VisitorEmailStatus::VERIFIED,
            )
            target = actor.visitor_passkeys.create!(
              webauthn_id: SecureRandom.uuid, public_key: "usable-key",
              uv_verified_at: Time.current,
            )
            fallback =
              (fallback_kind == :passkey) ? actor.visitor_passkeys.create!(
                webauthn_id: SecureRandom.uuid,
                public_key: "expired-key", uv_verified_at: Time.current,
              ) : recovery
            recovery.update!(discard_at: Visitor.database_now)
            [actor, VisitorToken.create!(visitor: actor), target, fallback]
          end
        fallback.update!(discard_at: actor.class.database_now)
        token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_passkey")
        event = token.last_step_up_at

        assert_not IdentityCredentialRemovalCommitter.call!(actor: actor, credential: target, current_session: token)
        assert_equal event, token.reload.last_step_up_at
        expected_status = (surface == :app) ? ClientPasskeyStatus::ACTIVE : VisitorPasskeyStatus::ACTIVE

        assert_equal expected_status, target.reload.status_id
        assert_predicate token, :currently_usable?
      end
    end
  end

  test "removal retains terminal history and invalidates authority while preserving root sessions" do
    %i(app com org totp).each do |surface|
      actor, token, credential, terminal_status =
        case surface
        when :app, :totp
          actor = Client.create!

          assert_equal 0, actor.client_passkeys.count
          actor.client_passkeys.create!(
            webauthn_id: SecureRandom.uuid, public_key: "fallback-key",
            uv_verified_at: Time.current,
          )
          credential =
            if surface == :totp
              actor.client_totp_credentials.create!(user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE)
            else
              actor.client_passkeys.create!(
                webauthn_id: SecureRandom.uuid, public_key: "removed-key",
                uv_verified_at: Time.current,
              )
            end
          [actor, ClientToken.create!(user: actor), credential,
           (surface == :totp) ? ClientTotpCredentialStatus::DELETED : ClientPasskeyStatus::DELETED,]
        when :com
          actor = Visitor.create!
          actor.visitor_emails.create!(
            address: "removal-#{SecureRandom.hex(8)}@example.com", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
          ).finalize_binding!
          credential = actor.visitor_passkeys.create!(
            webauthn_id: SecureRandom.uuid, public_key: "removed-key",
            uv_verified_at: Time.current,
          )
          [actor, VisitorToken.create!(visitor: actor), credential, VisitorPasskeyStatus::DELETED]
        when :org
          actor = Operator.create!
          actor.staff_passkeys.create!(
            webauthn_id: SecureRandom.uuid, public_key: "fallback-key",
            uv_verified_at: Time.current,
          )
          credential = actor.staff_passkeys.create!(
            webauthn_id: SecureRandom.uuid, public_key: "removed-key",
            uv_verified_at: Time.current,
          )
          [actor, OperatorToken.create!(staff: actor), credential, OperatorPasskeyStatus::REVOKED]
        end
      token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_passkey")
      transaction_model, ceremony_model =
        case actor
        when Client then [ClientStepUpCeremonyTransaction, ClientAuthCeremonySession]
        when Visitor then [VisitorStepUpCeremonyTransaction, VisitorAuthCeremonySession]
        when Operator then [OperatorStepUpCeremonyTransaction, OperatorAuthCeremonySession]
        end
      unfinished = transaction_model.create_transaction!(
        actor_ref: actor.public_id, session_ref: token.public_id, required_scope: "settings_passkey",
        required_aal: "none", allowed_methods: ["passkey"], return_to: "/identity/birthdate",
      )
      continuity, = ceremony_model.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: unfinished.transaction_id,
      )
      removed_id = credential.id

      assert IdentityCredentialRemovalCommitter.call!(actor: actor, credential: credential, current_session: token),
             surface

      credential.reload
      status = (surface == :totp) ? credential.user_identity_totp_credential_status_id : credential.status_id

      assert_equal terminal_status, status
      assert_equal removed_id, credential.id
      assert_nil token.reload.last_step_up_at
      assert_equal "revoked", unfinished.reload.status
      assert_not_nil continuity.reload.revoked_at
      assert_predicate token, :currently_usable?
      assert_not StepUpBootstrapEligibilityQuery.call(actor: actor)
      assert_not IdentityCredentialRemovalCommitter.call!(actor: actor, credential: credential, current_session: token)
    end
  end

  test "the last ORG Passkey and a foreign actor credential are refused without changing authority" do
    actor = Operator.create!
    foreign_actor = Operator.create!
    token = OperatorToken.create!(staff: actor)
    token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_passkey")
    credential = actor.staff_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "last-key",
      uv_verified_at: Time.current,
    )
    foreign = foreign_actor.staff_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "foreign-key",
      uv_verified_at: Time.current,
    )
    timestamp = token.last_step_up_at

    assert_not IdentityCredentialRemovalCommitter.call!(actor: actor, credential: credential, current_session: token)
    assert_raises(ArgumentError) do
      IdentityCredentialRemovalCommitter.call!(actor: actor, credential: foreign, current_session: token)
    end
    assert_equal OperatorPasskeyStatus::ACTIVE, credential.reload.status_id
    assert_equal OperatorPasskeyStatus::ACTIVE, foreign.reload.status_id
    assert_equal timestamp, token.reload.last_step_up_at
  end
  test "revoked session and ticket failure leave an owned credential active" do
    actor = Operator.create!
    token = OperatorToken.create!(staff: actor)
    actor.staff_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "fallback-key",
      uv_verified_at: Time.current,
    )
    credential = actor.staff_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "removed-key",
      uv_verified_at: Time.current,
    )
    token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_passkey")
    timestamp = token.last_step_up_at

    CredentialSecurityTransition.stub(
      :call, ->(**) {
               raise ActiveRecord::ConnectionNotEstablished, "injected ticket outage"
             },
    ) do
      assert_raises(ActiveRecord::ConnectionNotEstablished) do
        IdentityCredentialRemovalCommitter.call!(actor: actor, credential: credential, current_session: token)
      end
    end
    assert_equal OperatorPasskeyStatus::ACTIVE, credential.reload.status_id
    assert_equal timestamp, token.reload.last_step_up_at
    token.revoke!

    assert_raises(ArgumentError) do
      IdentityCredentialRemovalCommitter.call!(actor: actor, credential: credential, current_session: token)
    end
    assert_equal OperatorPasskeyStatus::ACTIVE, credential.reload.status_id
  end
  test "missing bindings, another session owner and Emergency context cannot remove a credential" do
    actor = Operator.create!
    other = Operator.create!
    credential = actor.staff_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "owned-key")
    token = OperatorToken.create!(staff: actor)
    foreign_token = OperatorToken.create!(staff: other)
    emergency = OperatorToken.create!(staff: actor, authentication_context: AuthenticationContextValue::EMERGENCY_KEY)

    [[nil, credential, token], [actor, nil, token], [actor, credential, nil],
     [actor, credential, foreign_token], [actor, credential, emergency],].each do |owner, target, session|
      assert_raises(ArgumentError) do
        IdentityCredentialRemovalCommitter.call!(actor: owner, credential: target, current_session: session)
      end
      assert_equal OperatorPasskeyStatus::ACTIVE, credential.reload.status_id
    end
  end
end
