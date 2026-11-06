# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

# Auth verifies the attestation and records a candidate; only Base turns that candidate into a
# credential. The principal database's unique index is the final authority on uniqueness.
class IdentityPasskeyRegistrationCommittersTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  self.use_transactional_tests = false

  fixtures :client_statuses

  setup do
    @actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @actor_ids = [@actor.id]
    @token = ClientToken.create!(authentication_epoch: 0, user: @actor, root_login_established_at: Time.current)
    @requirement = StepUpRequirement.new(
      scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false, allowed_methods: [:passkey],
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, actor_ref: @actor.public_id,
      resource_ref: nil, tenant_ref: nil,
      audience: "step_up:app", session_binding: @token.public_id, token_binding: @token.public_id,
      require_session_binding: true,
    )
    @transaction = BaseStepUpAdmissionIssuer.call!(
      actor: @actor, token: @token, requirement: @requirement, return_to: "/identity/birthdate",
      base_browser_nonce: SecureRandom.urlsafe_base64, base_token: @token,
    ).transaction
    @record = ClientStepUpSession.find_by!(step_up_ceremony_transaction_ref: @transaction.transaction_id)
    @ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "bootstrap_handoff", step_up_ceremony_transaction_ref: @transaction.transaction_id,
    )
    @fake = WebAuthn::FakeClient.new("https://auth.umaxica.app", encoding: :base64url)
    @config = Webauthn::RelyingPartyConfig.new(rp_id: "auth.umaxica.app", origin: @fake.origin)
    @challenge = SecureRandom.urlsafe_base64(32)
    @reference = @record.issue_bound_passkey_registration_challenge!(
      transaction: @transaction, challenge: @challenge, rp_id: @config.rp_id, origin: @config.origin,
    )
  end

  teardown do
    actor_refs = Client.where(id: @actor_ids).pluck(:public_id)
    token_ids = ClientToken.where(user_id: @actor_ids).pluck(:id)
    transaction_ids = ClientStepUpCeremonyTransaction.where(actor_ref: actor_refs).pluck(:id)
    transaction_refs = ClientStepUpCeremonyTransaction.where(id: transaction_ids).pluck(:transaction_id)
    ClientAuthAdmissionBinding.where(step_up_ceremony_transaction_id: transaction_ids).delete_all
    ClientAuthCeremonySession.where(step_up_ceremony_transaction_ref: transaction_refs).delete_all
    IdentityPasskeyCeremonyCandidate.where(step_up_ceremony_transaction_ref: transaction_refs).delete_all
    ClientStepUpSession.where(user_token_id: token_ids).delete_all
    ClientStepUpCeremonyTransaction.where(id: transaction_ids).delete_all
    ClientPasskeyAuditOutbox.where(actor_ref: actor_refs).delete_all
    ClientPasskey.where(user_id: @actor_ids).delete_all
    OpAppGrant.where(client_token_id: token_ids).delete_all
    ClientDeviceSession.where(user_id: @actor_ids).update_all(current_refresh_token_id: nil)
    ClientToken.where(id: token_ids).delete_all
    ClientDeviceSession.where(user_id: @actor_ids).delete_all
    ClientAuthorityLock.where(client_id: @actor_ids).delete_all
    ClientPreference.where(client_id: @actor_ids).delete_all
    ClientAccount.where(user_id: @actor_ids).delete_all
    Client.where(id: @actor_ids).delete_all
  end

  test "a revoked device cannot finalize a verified Passkey registration" do
    attestation = @fake.create(challenge: @challenge, user_verified: true)
    IdentityPasskeyRegistrationVerificationCommitter.call!(
      actor: @actor, token: @token, transaction: @transaction, session_record: @record, config: @config,
      reference: @reference, credential_params: attestation, description: "Laptop",
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: @transaction, ceremony_session_ref: @ceremony.id.to_s,
    )
    @token.device_session_record!.revoke!

    assert_no_difference ["ClientPasskey.count", "ClientPasskeyAuditOutbox.count"] do
      assert_raises(IdentityPasskeyCeremonyContract::Error) do
        IdentityPasskeyRegistrationFinalCommitter.call!(
          actor: @actor, token: @token, transaction: @transaction, raw_result: result.code,
          step_up_evidence: nil,
        )
      end
    end
    assert_not_predicate @transaction.reload, :consumed?
  end

  test "a revoked device cannot record a Passkey registration candidate" do
    attestation = @fake.create(challenge: @challenge, user_verified: true)
    @token.device_session_record!.revoke!

    assert_no_difference "IdentityPasskeyCeremonyCandidate.count" do
      assert_raises(IdentityPasskeyCeremonyContract::Error) do
        IdentityPasskeyRegistrationVerificationCommitter.call!(
          actor: @actor, token: @token, transaction: @transaction, session_record: @record, config: @config,
          reference: @reference, credential_params: attestation, description: "Laptop",
        )
      end
    end
    assert_equal "pending", @transaction.reload.status
  end

  test "a superseded token cannot record a Passkey registration candidate" do
    attestation = @fake.create(challenge: @challenge, user_verified: true)
    device = @token.device_session_record!
    replacement = ClientToken.create!(authentication_epoch: 0, user: @actor, device_session: device)
    device.update!(current_refresh_token_id: replacement.id)

    assert_no_difference "IdentityPasskeyCeremonyCandidate.count" do
      assert_raises(IdentityPasskeyCeremonyContract::Error) do
        IdentityPasskeyRegistrationVerificationCommitter.call!(
          actor: @actor, token: @token, transaction: @transaction, session_record: @record, config: @config,
          reference: @reference, credential_params: attestation, description: "Laptop",
        )
      end
    end
    assert_equal "pending", @transaction.reload.status
  end

  test "a superseded device token cannot finalize a verified Passkey registration" do
    attestation = @fake.create(challenge: @challenge, user_verified: true)
    IdentityPasskeyRegistrationVerificationCommitter.call!(
      actor: @actor, token: @token, transaction: @transaction, session_record: @record, config: @config,
      reference: @reference, credential_params: attestation, description: "Laptop",
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: @transaction, ceremony_session_ref: @ceremony.id.to_s,
    )
    device = @token.device_session_record!
    replacement = ClientToken.create!(authentication_epoch: 0, user: @actor, device_session: device)
    device.update!(current_refresh_token_id: replacement.id)

    assert_no_difference ["ClientPasskey.count", "ClientPasskeyAuditOutbox.count"] do
      assert_raises(IdentityPasskeyCeremonyContract::Error) do
        IdentityPasskeyRegistrationFinalCommitter.call!(
          actor: @actor, token: @token, transaction: @transaction, raw_result: result.code,
          step_up_evidence: nil,
        )
      end
    end
    assert_not_predicate @transaction.reload, :consumed?
  end

  test "Auth records a verified candidate without creating a Base credential" do
    attestation = @fake.create(challenge: @challenge, user_verified: true)

    assert_no_difference -> { ClientPasskey.count } do
      IdentityPasskeyRegistrationVerificationCommitter.call!(
        actor: @actor, token: @token, transaction: @transaction, session_record: @record, config: @config,
        reference: @reference, credential_params: attestation, description: "Laptop",
      )
    end

    @transaction.reload
    candidate = IdentityPasskeyCeremonyCandidate.find_by!(step_up_ceremony_transaction_ref: @transaction.transaction_id)

    assert_match(/\A[A-Za-z0-9_-]{21}\z/, candidate.ref)
    assert_equal "verified", @transaction.status
    assert_equal "passkey", @transaction.method
    assert_equal "none", @transaction.aal
    assert_nil @transaction.verified_credential_ref
    assert_equal attestation.fetch("id"), candidate.webauthn_id
    assert_equal "Laptop", candidate.description
    assert_equal @actor.public_id, candidate.actor_ref
    assert_equal @token.public_id, candidate.session_ref
    assert_nil candidate.consumed_at
    assert_raises(StepUpSessionConsumable::ChallengeError) do
      IdentityPasskeyRegistrationVerificationCommitter.call!(
        actor: @actor, token: @token, transaction: @transaction, session_record: @record, config: @config,
        reference: @reference, credential_params: attestation, description: "Laptop",
      )
    end
    assert_equal 1, IdentityPasskeyCeremonyCandidate.where(
      step_up_ceremony_transaction_ref: @transaction.transaction_id,
    ).count
  end

  test "an attestation without user verification burns the challenge and records nothing" do
    attestation = @fake.create(challenge: @challenge, user_verified: false)

    assert_raises(Webauthn::RegistrationVerifier::VerificationError, WebAuthn::Error) do
      IdentityPasskeyRegistrationVerificationCommitter.call!(
        actor: @actor, token: @token, transaction: @transaction, session_record: @record, config: @config,
        reference: @reference, credential_params: attestation, description: "Laptop",
      )
    end

    assert_equal "pending", @transaction.reload.status
    assert_not_nil @record.reload.passkey_challenge_consumed_at
    assert_equal 0, IdentityPasskeyCeremonyCandidate.count
    assert_equal 0, @actor.client_passkeys.count
  end

  # Sentinels of the challenge reference: missing, empty, zero, unknown and NUL-bearing.
  [nil, "", "0", "unknown-reference", "abc\u0000def"].each do |reference|
    test "the challenge reference #{reference.inspect} is refused without recording a candidate" do
      attestation = @fake.create(challenge: @challenge, user_verified: true)

      assert_raises(StepUpSessionConsumable::ChallengeError) do
        IdentityPasskeyRegistrationVerificationCommitter.call!(
          actor: @actor, token: @token, transaction: @transaction, session_record: @record, config: @config,
          reference: reference, credential_params: attestation, description: "Laptop",
        )
      end

      assert_equal "pending", @transaction.reload.status
      assert_equal 0, IdentityPasskeyCeremonyCandidate.count
    end
  end

  test "a registration challenge cannot be issued for an ordinary step-up transaction" do
    stranger = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @actor_ids << stranger.id
    token = ClientToken.create!(
      authentication_epoch: 0, user: stranger, root_login_established_at: Time.current,
      established_authentication_method: "passkey",
    )
    now = ClientToken.database_now
    token.rotate_refresh_token!(now:)
    token.device_session_record!
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token,
      oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(stranger, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    transaction = BaseStepUpAdmissionIssuer.call!(
      actor: stranger, token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_birthdate", step_up_required: true, allowed_methods: [:passkey],
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: true, ttl: 15.minutes, actor_ref: stranger.public_id,
        resource_ref: nil, tenant_ref: nil, purpose: "reauthentication", audience: "step_up:app",
        session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
      ), return_to: "/identity/birthdate",
      base_browser_nonce: SecureRandom.urlsafe_base64, base_token: token, step_up_evidence: evidence,
    ).transaction
    record = ClientStepUpSession.find_by!(step_up_ceremony_transaction_ref: transaction.transaction_id)

    assert_raises(StepUpSessionConsumable::ChallengeError) do
      record.issue_bound_passkey_registration_challenge!(
        transaction: transaction, challenge: SecureRandom.urlsafe_base64(32),
        rp_id: @config.rp_id, origin: @config.origin,
      )
    end
    assert_nil record.reload.passkey_challenge_ref
  end

  test "Base creates the credential from the candidate once and a retry returns the same credential" do
    attestation = @fake.create(challenge: @challenge, user_verified: true)
    IdentityPasskeyRegistrationVerificationCommitter.call!(
      actor: @actor, token: @token, transaction: @transaction, session_record: @record, config: @config,
      reference: @reference, credential_params: attestation, description: "Laptop",
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: @transaction.reload, ceremony_session_ref: @ceremony.id.to_s,
    )

    first = nil
    assert_difference -> { @actor.client_passkeys.count }, 1 do
      first = IdentityPasskeyRegistrationFinalCommitter.call!(
        actor: @actor, token: @token, transaction: @transaction, raw_result: result.code,
        step_up_evidence: nil,
      )
    end

    @transaction.reload
    candidate = IdentityPasskeyCeremonyCandidate.find_by!(step_up_ceremony_transaction_ref: @transaction.transaction_id)

    assert_equal attestation.fetch("id"), first.webauthn_id
    assert_equal candidate.public_key, first.public_key
    assert_equal "Laptop", first.description
    assert_equal "consumed", @transaction.status
    assert_equal first.public_id, @transaction.verified_credential_ref
    assert_equal @transaction.consumed_at, candidate.consumed_at
    assert_predicate @ceremony.reload, :completed?

    assert_no_difference -> { ClientPasskey.count } do
      again = IdentityPasskeyRegistrationFinalCommitter.call!(
        actor: @actor, token: @token, transaction: @transaction, raw_result: result.code,
        step_up_evidence: nil,
      )

      assert_equal first.id, again.id
    end
  end

  test "the unique index decides uniqueness: a credential registered elsewhere after Auth verified is refused" do
    attestation = @fake.create(challenge: @challenge, user_verified: true)
    IdentityPasskeyRegistrationVerificationCommitter.call!(
      actor: @actor, token: @token, transaction: @transaction, session_record: @record, config: @config,
      reference: @reference, credential_params: attestation, description: "Laptop",
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: @transaction.reload, ceremony_session_ref: @ceremony.id.to_s,
    )
    other = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @actor_ids << other.id
    other.client_passkeys.create!(
      webauthn_id: attestation.fetch("id"), public_key: "other-owner-key", description: "Other", sign_count: 0,
    )

    assert_no_difference -> { ClientPasskey.count } do
      assert_raises(IdentityPasskeyCeremonyContract::Error) do
        IdentityPasskeyRegistrationFinalCommitter.call!(
          actor: @actor, token: @token, transaction: @transaction, raw_result: result.code,
          step_up_evidence: nil,
        )
      end
    end

    assert_equal 0, @actor.client_passkeys.count
    assert_equal "verified", @transaction.reload.status
    assert_nil @transaction.consumed_at
  end

  test "Auth refuses an attestation whose credential is already registered" do
    attestation = @fake.create(challenge: @challenge, user_verified: true)
    other = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @actor_ids << other.id
    other.client_passkeys.create!(
      webauthn_id: attestation.fetch("id"), public_key: "other-owner-key", description: "Other", sign_count: 0,
    )

    assert_raises(IdentityPasskeyCeremonyContract::Error) do
      IdentityPasskeyRegistrationVerificationCommitter.call!(
        actor: @actor, token: @token, transaction: @transaction, session_record: @record, config: @config,
        reference: @reference, credential_params: attestation, description: "Laptop",
      )
    end

    assert_equal "pending", @transaction.reload.status
    assert_equal 0, IdentityPasskeyCeremonyCandidate.count
  end

  test "Base refuses a candidate whose stored material no longer matches its digest" do
    attestation = @fake.create(challenge: @challenge, user_verified: true)
    IdentityPasskeyRegistrationVerificationCommitter.call!(
      actor: @actor, token: @token, transaction: @transaction, session_record: @record, config: @config,
      reference: @reference, credential_params: attestation, description: "Laptop",
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: @transaction.reload, ceremony_session_ref: @ceremony.id.to_s,
    )
    # Written past the model on purpose: nothing in the application rewrites a verified candidate.
    IdentityPasskeyCeremonyCandidate.find_by!(
      step_up_ceremony_transaction_ref: @transaction.transaction_id,
    ).update_columns(public_key: "attacker-key")

    assert_no_difference -> { ClientPasskey.count } do
      assert_raises(IdentityPasskeyCeremonyContract::Error) do
        IdentityPasskeyRegistrationFinalCommitter.call!(
          actor: @actor, token: @token, transaction: @transaction, raw_result: result.code,
          step_up_evidence: nil,
        )
      end
    end
    assert_equal "verified", @transaction.reload.status
  end

  test "Base refuses finalization through another session of the same actor" do
    attestation = @fake.create(challenge: @challenge, user_verified: true)
    IdentityPasskeyRegistrationVerificationCommitter.call!(
      actor: @actor, token: @token, transaction: @transaction, session_record: @record, config: @config,
      reference: @reference, credential_params: attestation, description: "Laptop",
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: @transaction.reload, ceremony_session_ref: @ceremony.id.to_s,
    )
    other_token = ClientToken.create!(authentication_epoch: 0, user: @actor, root_login_established_at: Time.current)

    assert_no_difference -> { ClientPasskey.count } do
      assert_raises(IdentityPasskeyCeremonyContract::Error) do
        IdentityPasskeyRegistrationFinalCommitter.call!(
          actor: @actor, token: other_token, transaction: @transaction, raw_result: result.code,
          step_up_evidence: nil,
        )
      end
    end
    assert_equal "verified", @transaction.reload.status
  end
end
