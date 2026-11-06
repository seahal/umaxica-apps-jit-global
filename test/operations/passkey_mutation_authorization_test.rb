# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class PasskeyMutationAuthorizationTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  self.use_transactional_tests = false
  # These token references must exist even on a newly migrated database.
  fixtures :client_token_binding_methods, :operator_token_binding_methods,
           :client_token_dbsc_statuses, :operator_token_dbsc_statuses

  setup do
    @created_clients = []
    @created_operators = []
  end

  teardown do
    client_ids = @created_clients.map(&:id)
    client_refs = @created_clients.map(&:public_id)
    if client_ids.any?
      client_tokens = ClientToken.where(user_id: client_ids).select(:id)
      OpAppGrant.where(client_token_id: client_tokens).delete_all
      client_transactions = ClientStepUpCeremonyTransaction.where(actor_ref: client_refs)
      client_transaction_ids = client_transactions.select(:id)
      client_transaction_refs = client_transactions.select(:transaction_id)
      ClientAuthAdmissionBinding.where(step_up_ceremony_transaction_id: client_transaction_ids).delete_all
      ClientAuthCeremonySession.where(step_up_ceremony_transaction_ref: client_transaction_refs).delete_all
      ClientStepUpSession.where(user_token_id: client_tokens).delete_all
      IdentityPasskeyCeremonyCandidate.where(step_up_ceremony_transaction_ref: client_transaction_refs).delete_all
      client_transactions.delete_all
      ClientPasskeyAuditOutbox.where(actor_ref: client_refs).delete_all
      ClientPasskey.where(user_id: client_ids).delete_all
      ClientDeviceSession.where(user_id: client_ids).update_all(current_refresh_token_id: nil)
      ClientToken.where(user_id: client_ids).delete_all
      ClientDeviceSession.where(user_id: client_ids).delete_all
      ClientAuthorityLock.where(client_id: client_ids).delete_all
      ClientChronicle.where(subject_type: "Client", subject_id: client_ids.map(&:to_s)).delete_all
      Client.where(id: client_ids).delete_all
    end

    operator_ids = @created_operators.map(&:id)
    operator_refs = @created_operators.map(&:public_id)
    if operator_ids.any?
      operator_tokens = OperatorToken.where(staff_id: operator_ids).select(:id)
      OpOrgGrant.where(operator_token_id: operator_tokens).delete_all
      operator_transactions = OperatorStepUpCeremonyTransaction.where(actor_ref: operator_refs)
      operator_transaction_ids = operator_transactions.select(:id)
      operator_transaction_refs = operator_transactions.select(:transaction_id)
      OperatorAuthAdmissionBinding.where(step_up_ceremony_transaction_id: operator_transaction_ids).delete_all
      OperatorAuthCeremonySession.where(step_up_ceremony_transaction_ref: operator_transaction_refs).delete_all
      OperatorStepUpSession.where(staff_token_id: operator_tokens).delete_all
      OperatorPasskeyCeremonyCandidate.where(step_up_ceremony_transaction_ref: operator_transaction_refs).delete_all
      operator_transactions.delete_all
      OperatorPasskeyAuditOutbox.where(actor_ref: operator_refs).delete_all
      OperatorPasskey.where(staff_id: operator_ids).delete_all
      OperatorDeviceSession.where(staff_id: operator_ids).update_all(current_refresh_token_id: nil)
      OperatorToken.where(staff_id: operator_ids).delete_all
      OperatorDeviceSession.where(staff_id: operator_ids).delete_all
      OperatorAuthorityLock.where(operator_id: operator_ids).delete_all
      OperatorChronicle.where(subject_type: "Operator", subject_id: operator_ids.map(&:to_s)).delete_all
      Operator.where(id: operator_ids).delete_all
    end
  end

  [false, true].each do |revoked|
    test "registration finalization accepts OP evidence with authenticating passkey revoked=#{revoked}" do
      actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
      @created_clients << actor
      existing = actor.client_passkeys.create!(
        webauthn_id: SecureRandom.uuid, public_key: "existing-key", uv_verified_at: Time.current,
      )
      token = ClientToken.create!(authentication_epoch: 0, user: actor, root_login_established_at: Time.current)
      now = OpBaseAppRecord.database_now
      token.device_session_record!
      token.update!(root_login_established_at: now, established_authentication_method: "passkey")
      token.rotate_refresh_token!(now:)
      oidc_client = OidcClientRegistry.find!("base-app-ww")
      grant = OpAppGrant.create!(
        authentication_epoch: token.authentication_epoch, client_token: token,
        oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
        oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
        oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
        refresh_token_expires_at: now + 1.hour,
      )
      grant.issue_refresh_token!(now:)
      step_up_evidence = StepUpEvidenceValue.new(
        acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
        sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
        aud: [oidc_client.aud], jti: grant.oidc_jti,
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
        base_browser_nonce: SecureRandom.urlsafe_base64, base_token: token, step_up_evidence: step_up_evidence,
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

      assert_difference -> { actor.client_passkeys.count }, 1 do
        IdentityPasskeyRegistrationFinalCommitter.call!(
          actor: actor, token: token, transaction: transaction, raw_result: result.code,
          step_up_evidence: step_up_evidence,
        )
      end
      assert_equal "consumed", transaction.reload.status
      assert_equal(revoked ? ClientPasskeyStatus::REVOKED : ClientPasskeyStatus::ACTIVE, existing.reload.status_id)
      OpBaseAppRecord.transaction do
        assert StepUpEvidenceVerifier.call(evidence: step_up_evidence, actor: actor, token: token.reload)
      end
      assert ClientPasskeyPolicy.new(ClientPasskey, user: actor).management_authorized?(
        token: token, now: ClientToken.database_now,
      )
    end
  end

  test "org registration records the external ID and reconciles the same Passkey on retry" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    @created_operators << actor
    actor.staff_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "existing-org-key", uv_verified_at: Time.current,
    )
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor, root_login_established_at: Time.current)
    now = OpBaseOrgRecord.database_now
    token.device_session_record!
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    oidc_client = OidcClientRegistry.find!("base-org-ww")
    grant = OpOrgGrant.create!(
      authentication_epoch: token.authentication_epoch, operator_token: token,
      oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    step_up_evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "operator"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
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
      base_browser_nonce: SecureRandom.urlsafe_base64, base_token: token, step_up_evidence: step_up_evidence,
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
      step_up_evidence: step_up_evidence,
    )

    assert_equal registered.external_id, transaction.reload.verified_credential_ref
    assert_equal registered.id, IdentityPasskeyRegistrationFinalCommitter.call!(
      actor: actor, token: token, transaction: transaction, raw_result: result.code,
      step_up_evidence: step_up_evidence,
    ).id
    OpBaseOrgRecord.transaction do
      assert StepUpEvidenceVerifier.call(evidence: step_up_evidence, actor: actor, token: token.reload)
    end
  end

  test "org registration rejects a revoked device before credential and audit creation" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    @created_operators << actor
    actor.staff_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "existing-org-key", uv_verified_at: Time.current,
    )
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor, root_login_established_at: Time.current)
    now = OpBaseOrgRecord.database_now
    token.device_session_record!
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    oidc_client = OidcClientRegistry.find!("base-org-ww")
    grant = OpOrgGrant.create!(
      authentication_epoch: token.authentication_epoch, operator_token: token,
      oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    step_up_evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "operator"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
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
      base_browser_nonce: SecureRandom.urlsafe_base64, base_token: token, step_up_evidence: step_up_evidence,
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
          step_up_evidence: step_up_evidence,
        )
      end
    end
    assert_not_predicate transaction.reload, :consumed?
  end

  test "org bootstrap refuses to record a candidate when the token changed to standby" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    @created_operators << actor
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
    @created_operators << actor
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
    @created_operators << actor
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
    @created_operators << actor
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
          step_up_evidence: nil,
        )
      end
    end
    assert_not_predicate transaction.reload, :consumed?
  end

  test "org registration rejects a superseded token before credential and audit creation" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    @created_operators << actor
    actor.staff_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "existing-org-key", uv_verified_at: Time.current,
    )
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor, root_login_established_at: Time.current)
    now = OpBaseOrgRecord.database_now
    token.device_session_record!
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    oidc_client = OidcClientRegistry.find!("base-org-ww")
    grant = OpOrgGrant.create!(
      authentication_epoch: token.authentication_epoch, operator_token: token,
      oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    step_up_evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "operator"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
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
      base_browser_nonce: SecureRandom.urlsafe_base64, base_token: token, step_up_evidence: step_up_evidence,
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
          step_up_evidence: step_up_evidence,
        )
      end
    end
    assert_not_predicate transaction.reload, :consumed?
  end

  test "APP passkey management does not require the authenticating Passkey to remain active" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    @created_clients << actor
    authenticating_passkey = actor.client_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "app-authenticator-key", uv_verified_at: Time.current,
    )
    managed_passkey = actor.client_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "app-managed-key", uv_verified_at: Time.current,
    )
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    now = OpBaseAppRecord.database_now
    token.device_session_record!
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token,
      oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    step_up_evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    policy = ClientPasskeyPolicy.new(managed_passkey, user: actor)

    assert policy.management_authorized?(token: token, now: now)
    OpBaseAppRecord.transaction do
      assert StepUpEvidenceVerifier.call(evidence: step_up_evidence, actor: actor, token: token.reload)
    end
    authenticating_passkey.update!(status_id: ClientPasskeyStatus::REVOKED)

    assert policy.management_authorized?(token: token.reload, now: now)
    OpBaseAppRecord.transaction do
      assert StepUpEvidenceVerifier.call(evidence: step_up_evidence, actor: actor, token: token.reload)
    end
    assert_predicate policy, :update?
    token.revoke!

    assert_not policy.management_authorized?(token: token.reload, now: ClientToken.database_now)
  end

  test "ORG passkey management does not require the authenticating Passkey to remain active" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    @created_operators << actor
    authenticating_passkey = actor.staff_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "org-authenticator-key", uv_verified_at: Time.current,
    )
    actor.staff_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "org-second-key")
    managed_passkey = actor.staff_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "org-managed-key", uv_verified_at: Time.current,
    )
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor)
    now = OpBaseOrgRecord.database_now
    token.device_session_record!
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    oidc_client = OidcClientRegistry.find!("base-org-ww")
    grant = OpOrgGrant.create!(
      authentication_epoch: token.authentication_epoch, operator_token: token,
      oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    step_up_evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "operator"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    policy = OperatorPasskeyPolicy.new(managed_passkey, user: actor)

    assert policy.management_authorized?(token: token, now: now)
    OpBaseOrgRecord.transaction do
      assert StepUpEvidenceVerifier.call(evidence: step_up_evidence, actor: actor, token: token.reload)
    end
    authenticating_passkey.update!(status_id: OperatorPasskeyStatus::REVOKED)

    assert policy.management_authorized?(token: token.reload, now: now)
    OpBaseOrgRecord.transaction do
      assert StepUpEvidenceVerifier.call(evidence: step_up_evidence, actor: actor, token: token.reload)
    end
    assert_predicate policy, :update?
    token.revoke!

    assert_not policy.management_authorized?(token: token.reload, now: OperatorToken.database_now)
  end
end
