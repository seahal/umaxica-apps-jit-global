# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class PasskeyMutationAuthorizationTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  # These token references must exist even on a newly migrated database.
  fixtures :client_token_binding_methods, :operator_token_binding_methods,
           :client_token_dbsc_statuses, :operator_token_dbsc_statuses

  test "passkey removal requires scoped evidence in app and org even when another key survives" do
    [[Client, ClientPasskey, ClientToken, :user_id],
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
      surface = { Client => "app", Operator => "org" }.fetch(actor_class)
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
        last_step_up_resource_ref: reference,
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

  test "login-blocked owners cannot remove Passkeys with earlier Step-Up" do
    [
      [Client, ClientPasskey, ClientToken, ClientStatus::ACTIVE, ClientStatus::RESERVED, :user_id, "app"],
      [Operator, OperatorPasskey, OperatorToken, OperatorStatus::ACTIVE, OperatorStatus::RESERVED, :staff_id, "org"],
    ].each do |values|
      actor_class, key_class, token_class, active, blocked, owner_key, surface = values
      actor = actor_class.create!(security_mode_id: SecurityModeTestDefault.id_for(actor_class), status_id: active)
      metadata = (key_class == ClientPasskey) ? { uv_verified_at: Time.current } : {}
      key_class.create!(
        owner_key => actor.id, :webauthn_id => SecureRandom.uuid, :public_key => "remaining", **metadata,
      )
      target = key_class.create!(
        owner_key => actor.id, :webauthn_id => SecureRandom.uuid, :public_key => "target", **metadata,
      )
      token = token_class.create!(:authentication_epoch => 0, owner_key => actor.id)
      reference = (key_class == OperatorPasskey) ? target.external_id : target.public_id
      token.update!(
        last_step_up_at: token_class.database_now, last_step_up_scope: "settings_passkey",
        last_step_up_method: "passkey",
        last_step_up_credential_ref: reference, last_step_up_session_public_id: token.public_id,
        last_step_up_purpose: "step_up", last_step_up_audience: "step_up:#{surface}",
        last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
        last_step_up_full_reauthentication: false, last_step_up_resource_ref: reference,
      )
      actor.reload.update!(status_id: blocked)
      step_up_at = token.last_step_up_at

      assert_not IdentityCredentialRemovalCommitter.call!(actor: actor, credential: target, current_session: token)
      assert_predicate target.reload, :persisted?
      assert_equal step_up_at, token.reload.last_step_up_at
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
        # adr/authentication-security-mode.md D3: the registration spent the settings Step-Up.
        assert_nil token.reload.last_step_up_at
        assert_not ClientPasskeyPolicy.new(ClientPasskey, user: actor).management_authorized?(
          token: token, now: ClientToken.database_now,
        )
      end
    end
  end

  test "org registration records the external ID and reconciles the same Passkey on retry" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    existing = actor.staff_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "existing-org-key", uv_verified_at: Time.current,
    )
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor, root_login_established_at: Time.current)
    token.update!(
      last_step_up_at: Time.current, last_step_up_scope: "settings_passkey", last_step_up_method: "passkey",
      last_step_up_credential_ref: existing.external_id, last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:org",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_full_reauthentication: false,
    )
    requirement = StepUpRequirement.new(
      scope: "settings_passkey", purpose: "credential_registration", step_up_required: false,
      allowed_methods: [:passkey], phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil, audience: "step_up:org", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true,
    )
    transaction = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/passkeys",
      base_browser_nonce: SecureRandom.urlsafe_base64, base_token: token,
    ).transaction
    record = OperatorStepUpSession.find_by!(step_up_ceremony_transaction_ref: transaction.transaction_id)
    ceremony, = OperatorAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "credential_registration_handoff",
      step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    fake = WebAuthn::FakeClient.new("https://auth.umaxica.org", encoding: :base64url)
    config = Webauthn::RelyingPartyConfig.new(rp_id: "auth.umaxica.org", origin: fake.origin)
    challenge = SecureRandom.urlsafe_base64(32)
    reference = record.issue_bound_passkey_registration_challenge!(
      transaction: transaction, challenge: challenge, rp_id: config.rp_id, origin: config.origin,
    )
    IdentityPasskeyRegistrationVerificationCommitter.call!(
      actor: actor, token: token, transaction: transaction, session_record: record, config: config,
      reference: reference,
      credential_params: fake.create(
        challenge: challenge, user_verified: true, extensions: { "credProps" => { "rk" => true } },
      ),
      description: "New org passkey",
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: transaction.reload, ceremony_session_ref: ceremony.id.to_s,
    )
    registered = IdentityPasskeyRegistrationFinalCommitter.call!(
      actor: actor, token: token, transaction: transaction, raw_result: result.code,
    )

    assert_equal registered.external_id, transaction.reload.verified_credential_ref
    assert_equal registered.id, IdentityPasskeyRegistrationFinalCommitter.call!(
      actor: actor, token: token, transaction: transaction, raw_result: result.code,
    ).id
  end

  test "org registration rejects a revoked device before credential and audit creation" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    existing = actor.staff_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "existing-org-key", uv_verified_at: Time.current,
    )
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor, root_login_established_at: Time.current)
    token.update!(
      last_step_up_at: Time.current, last_step_up_scope: "settings_passkey", last_step_up_method: "passkey",
      last_step_up_credential_ref: existing.external_id, last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:org",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_full_reauthentication: false,
    )
    requirement = StepUpRequirement.new(
      scope: "settings_passkey", purpose: "credential_registration", step_up_required: false,
      allowed_methods: [:passkey], phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil, audience: "step_up:org", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true,
    )
    transaction = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/passkeys",
      base_browser_nonce: SecureRandom.urlsafe_base64, base_token: token,
    ).transaction
    record = OperatorStepUpSession.find_by!(step_up_ceremony_transaction_ref: transaction.transaction_id)
    ceremony, = OperatorAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "credential_registration_handoff",
      step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    fake = WebAuthn::FakeClient.new("https://auth.umaxica.org", encoding: :base64url)
    config = Webauthn::RelyingPartyConfig.new(rp_id: "auth.umaxica.org", origin: fake.origin)
    challenge = SecureRandom.urlsafe_base64(32)
    reference = record.issue_bound_passkey_registration_challenge!(
      transaction: transaction, challenge: challenge, rp_id: config.rp_id, origin: config.origin,
    )
    IdentityPasskeyRegistrationVerificationCommitter.call!(
      actor: actor, token: token, transaction: transaction, session_record: record, config: config,
      reference: reference,
      credential_params: fake.create(
        challenge: challenge, user_verified: true, extensions: { "credProps" => { "rk" => true } },
      ),
      description: "New org passkey",
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: transaction.reload, ceremony_session_ref: ceremony.id.to_s,
    )
    token.device_session_record!.revoke!

    assert_no_difference ["OperatorPasskey.count", "OperatorPasskeyAuditOutbox.count"] do
      assert_raises(IdentityPasskeyCeremonyContract::Error) do
        IdentityPasskeyRegistrationFinalCommitter.call!(
          actor: actor, token: token, transaction: transaction, raw_result: result.code,
        )
      end
    end
    assert_not_predicate transaction.reload, :consumed?
  end

  test "org bootstrap refuses to record a candidate when the token changed to standby" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor, root_login_established_at: Time.current)
    requirement = StepUpRequirement.new(
      scope: "settings_passkey", purpose: "bootstrap", step_up_required: false,
      allowed_methods: [:passkey], phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil, audience: "step_up:org", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true,
    )
    transaction = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/passkeys",
      base_browser_nonce: SecureRandom.urlsafe_base64, base_token: token,
    ).transaction
    record = OperatorStepUpSession.find_by!(step_up_ceremony_transaction_ref: transaction.transaction_id)
    OperatorAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "bootstrap_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    fake = WebAuthn::FakeClient.new("https://auth.umaxica.org", encoding: :base64url)
    config = Webauthn::RelyingPartyConfig.new(rp_id: "auth.umaxica.org", origin: fake.origin)
    challenge = SecureRandom.urlsafe_base64(32)
    reference = record.issue_bound_passkey_registration_challenge!(
      transaction: transaction, challenge: challenge, rp_id: config.rp_id, origin: config.origin,
    )
    OperatorToken.find(token.id).update!(authentication_context: AuthenticationContextValue::STANDBY_KEY)
    attestation = fake.create(
      challenge: challenge, user_verified: true, extensions: { "credProps" => { "rk" => true } },
    )

    assert_no_difference "OperatorPasskeyCeremonyCandidate.count" do
      assert_raises(IdentityPasskeyCeremonyContract::Error) do
        IdentityPasskeyRegistrationVerificationCommitter.call!(
          actor: actor, token: token, transaction: transaction, session_record: record, config: config,
          reference: reference, credential_params: attestation, description: "New org passkey",
        )
      end
    end
    assert_equal "pending", transaction.reload.status
  end

  test "org bootstrap refuses to record a candidate after device revocation" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor, root_login_established_at: Time.current)
    requirement = StepUpRequirement.new(
      scope: "settings_passkey", purpose: "bootstrap", step_up_required: false,
      allowed_methods: [:passkey], phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil, audience: "step_up:org", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true,
    )
    transaction = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/passkeys",
      base_browser_nonce: SecureRandom.urlsafe_base64, base_token: token,
    ).transaction
    record = OperatorStepUpSession.find_by!(step_up_ceremony_transaction_ref: transaction.transaction_id)
    OperatorAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "bootstrap_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    fake = WebAuthn::FakeClient.new("https://auth.umaxica.org", encoding: :base64url)
    config = Webauthn::RelyingPartyConfig.new(rp_id: "auth.umaxica.org", origin: fake.origin)
    challenge = SecureRandom.urlsafe_base64(32)
    reference = record.issue_bound_passkey_registration_challenge!(
      transaction: transaction, challenge: challenge, rp_id: config.rp_id, origin: config.origin,
    )
    token.device_session_record!.revoke!
    attestation = fake.create(
      challenge: challenge, user_verified: true, extensions: { "credProps" => { "rk" => true } },
    )

    assert_no_difference "OperatorPasskeyCeremonyCandidate.count" do
      assert_raises(IdentityPasskeyCeremonyContract::Error) do
        IdentityPasskeyRegistrationVerificationCommitter.call!(
          actor: actor, token: token, transaction: transaction, session_record: record, config: config,
          reference: reference, credential_params: attestation, description: "New org passkey",
        )
      end
    end
    assert_equal "pending", transaction.reload.status
  end

  test "org bootstrap refuses to record a candidate after token supersession" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor, root_login_established_at: Time.current)
    requirement = StepUpRequirement.new(
      scope: "settings_passkey", purpose: "bootstrap", step_up_required: false,
      allowed_methods: [:passkey], phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil, audience: "step_up:org", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true,
    )
    transaction = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/passkeys",
      base_browser_nonce: SecureRandom.urlsafe_base64, base_token: token,
    ).transaction
    record = OperatorStepUpSession.find_by!(step_up_ceremony_transaction_ref: transaction.transaction_id)
    OperatorAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "bootstrap_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    fake = WebAuthn::FakeClient.new("https://auth.umaxica.org", encoding: :base64url)
    config = Webauthn::RelyingPartyConfig.new(rp_id: "auth.umaxica.org", origin: fake.origin)
    challenge = SecureRandom.urlsafe_base64(32)
    reference = record.issue_bound_passkey_registration_challenge!(
      transaction: transaction, challenge: challenge, rp_id: config.rp_id, origin: config.origin,
    )
    device = token.device_session_record!
    replacement = OperatorToken.create!(authentication_epoch: 0, staff: actor, device_session: device)
    device.update!(current_refresh_token_id: replacement.id)
    attestation = fake.create(
      challenge: challenge, user_verified: true, extensions: { "credProps" => { "rk" => true } },
    )

    assert_no_difference "OperatorPasskeyCeremonyCandidate.count" do
      assert_raises(IdentityPasskeyCeremonyContract::Error) do
        IdentityPasskeyRegistrationVerificationCommitter.call!(
          actor: actor, token: token, transaction: transaction, session_record: record, config: config,
          reference: reference, credential_params: attestation, description: "New org passkey",
        )
      end
    end
    assert_equal "pending", transaction.reload.status
  end

  test "org bootstrap refuses a token that changed to standby after it was read" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor, root_login_established_at: Time.current)
    requirement = StepUpRequirement.new(
      scope: "settings_passkey", purpose: "bootstrap", step_up_required: false,
      allowed_methods: [:passkey], phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil, audience: "step_up:org", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true,
    )
    transaction = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/passkeys",
      base_browser_nonce: SecureRandom.urlsafe_base64, base_token: token,
    ).transaction
    record = OperatorStepUpSession.find_by!(step_up_ceremony_transaction_ref: transaction.transaction_id)
    ceremony, = OperatorAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "bootstrap_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    fake = WebAuthn::FakeClient.new("https://auth.umaxica.org", encoding: :base64url)
    config = Webauthn::RelyingPartyConfig.new(rp_id: "auth.umaxica.org", origin: fake.origin)
    challenge = SecureRandom.urlsafe_base64(32)
    reference = record.issue_bound_passkey_registration_challenge!(
      transaction: transaction, challenge: challenge, rp_id: config.rp_id, origin: config.origin,
    )
    IdentityPasskeyRegistrationVerificationCommitter.call!(
      actor: actor, token: token, transaction: transaction, session_record: record, config: config,
      reference: reference, credential_params: fake.create(
        challenge: challenge, user_verified: true, extensions: { "credProps" => { "rk" => true } },
      ),
      description: "New org passkey",
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: transaction.reload, ceremony_session_ref: ceremony.id.to_s,
    )
    OperatorToken.find(token.id).update!(authentication_context: AuthenticationContextValue::STANDBY_KEY)

    assert_no_difference ["OperatorPasskey.count", "OperatorPasskeyAuditOutbox.count"] do
      assert_raises(IdentityPasskeyCeremonyContract::Error) do
        IdentityPasskeyRegistrationFinalCommitter.call!(
          actor: actor, token: token, transaction: transaction, raw_result: result.code,
        )
      end
    end
    assert_not_predicate transaction.reload, :consumed?
  end

  test "org registration rejects a superseded token before credential and audit creation" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    existing = actor.staff_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "existing-org-key", uv_verified_at: Time.current,
    )
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor, root_login_established_at: Time.current)
    token.update!(
      last_step_up_at: Time.current, last_step_up_scope: "settings_passkey", last_step_up_method: "passkey",
      last_step_up_credential_ref: existing.external_id, last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:org",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_full_reauthentication: false,
    )
    requirement = StepUpRequirement.new(
      scope: "settings_passkey", purpose: "credential_registration", step_up_required: false,
      allowed_methods: [:passkey], phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil, audience: "step_up:org", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true,
    )
    transaction = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/passkeys",
      base_browser_nonce: SecureRandom.urlsafe_base64, base_token: token,
    ).transaction
    record = OperatorStepUpSession.find_by!(step_up_ceremony_transaction_ref: transaction.transaction_id)
    ceremony, = OperatorAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "credential_registration_handoff",
      step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    fake = WebAuthn::FakeClient.new("https://auth.umaxica.org", encoding: :base64url)
    config = Webauthn::RelyingPartyConfig.new(rp_id: "auth.umaxica.org", origin: fake.origin)
    challenge = SecureRandom.urlsafe_base64(32)
    reference = record.issue_bound_passkey_registration_challenge!(
      transaction: transaction, challenge: challenge, rp_id: config.rp_id, origin: config.origin,
    )
    IdentityPasskeyRegistrationVerificationCommitter.call!(
      actor: actor, token: token, transaction: transaction, session_record: record, config: config,
      reference: reference,
      credential_params: fake.create(
        challenge: challenge, user_verified: true, extensions: { "credProps" => { "rk" => true } },
      ),
      description: "New org passkey",
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: transaction.reload, ceremony_session_ref: ceremony.id.to_s,
    )
    device = token.device_session_record!
    replacement = OperatorToken.create!(authentication_epoch: 0, staff: actor, device_session: device)
    device.update!(current_refresh_token_id: replacement.id)

    assert_no_difference ["OperatorPasskey.count", "OperatorPasskeyAuditOutbox.count"] do
      assert_raises(IdentityPasskeyCeremonyContract::Error) do
        IdentityPasskeyRegistrationFinalCommitter.call!(
          actor: actor, token: token, transaction: transaction, raw_result: result.code,
        )
      end
    end
    assert_not_predicate transaction.reload, :consumed?
  end

  test "passkey freshness ends exactly at the Security Mode window and refuses a future event (microseconds)" do
    [[Client, ClientPasskey, ClientToken, ClientPasskeyPolicy, :user_id, "app"],
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
        last_step_up_full_reauthentication: false, last_step_up_resource_ref: reference,
      )
      policy = policy_class.new(key, user: actor)
      microsecond = Rational(1, 1_000_000)
      # Consolidation ADR 2.3: NORMAL keeps 15 minutes; ADVANCED (every Operator) at most 5.
      window = actor.security_mode_advanced? ? 5.minutes : 15.minutes
      [[now - window - microsecond, false], [now - window, false],
       [now - window + microsecond, true], [now - microsecond, true],
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

  test "app passkey management accepts active verified and signup-verified email evidence" do
    [[Client, ClientEmail, ClientToken, ClientPasskeyPolicy, :user_id, :user_email_status_id,
      "app",]].each do |actor_class, email_class, token_class, policy_class, owner_key, status_key, surface|
      statuses =
        if actor_class == Client
          [ClientEmailStatus::VERIFIED, ClientEmailStatus::VERIFIED_WITH_SIGN_UP]
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
