# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class OrgStepUpPasskeyCommittersTest < ActiveSupport::TestCase
  fixtures :operators, :operator_passkeys

  setup do
    @actor = operators(:one)
    @token = OperatorToken.create!(authentication_epoch: 0, staff: @actor)
    client = OidcClientRegistry.find!("core-org-jp")
    now = OpBaseOrgRecord.database_now
    grant = OpOrgGrant.create!(
      authentication_epoch: @token.authentication_epoch,
      operator_token: @token,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now - 1.hour,
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
    redirect_uri = client.redirect_uris_by_realm.fetch("operator").first
    verifier = SecureRandom.urlsafe_base64(32)
    params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri:,
      scope: grant.oidc_scope,
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false),
      code_challenge_method: "S256",
      prompt: "login",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    }
    validated_request = OidcAuthorizeRequestResolver.call(params:, resource: @actor, resource_type: "operator")
    issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "org", actor: @actor, token: @token, client:, params:, validated_request:,
    )
    @context = issuance.context
    @authorization = issuance.authorization_transaction
    @entry_ref = issuance.entry_ref
    @binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "org", reference: @entry_ref)
    @attached_ceremony, raw_sid = OperatorAuthCeremonySession.issue!
    @binding.attach_auth_session!(auth_session: @attached_ceremony, confirmation_ref: SecureRandom.uuid)
    @binding.confirm_base!(
      base_token: @token,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "org", entry_ref: @entry_ref, nonce: @authorization.login_challenge,
      ),
    )
    @admitted_ceremony, = OperatorAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", previous_raw_sid: raw_sid,
      step_up_ceremony_transaction_ref: issuance.ticket.transaction_id,
    )
    @binding.redeem!(auth_session: @attached_ceremony, admitted_auth_session: @admitted_ceremony)
    @fake = WebAuthn::FakeClient.new("https://auth.umaxica.org", encoding: :base64url)
    registration = @fake.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
    relying_party = WebAuthn::RelyingParty.new(
      id: "auth.umaxica.org", allowed_origins: [@fake.origin], encoding: :base64url,
    )
    credential = WebAuthn::Credential.from_create(registration, relying_party: relying_party)
    @credential = @actor.staff_passkeys.create!(
      webauthn_id: credential.id, public_key: credential.public_key, sign_count: 0,
    )
    @transaction = issuance.ticket
    @record = OperatorStepUpSession.find_by!(step_up_ceremony_transaction_ref: @transaction.transaction_id)
    @config = Webauthn::RelyingPartyConfig.new(rp_id: "auth.umaxica.org", origin: @fake.origin)
    options = Webauthn::AssertionVerifier.options_for(
      config: @config, allow_ids: [@credential.webauthn_id], purpose: :ordinary_step_up,
    )
    @reference = @record.issue_bound_passkey_challenge!(
      transaction: @transaction, challenge: options.challenge, rp_id: @config.rp_id, origin: @config.origin,
    )
    @assertion = @fake.get(challenge: options.challenge, user_verified: true, sign_count: 5)
  end

  test "a revoked device cannot consume a Passkey challenge or record evidence" do
    @token.device_session_record!.revoke!

    assert_raises(IdentityStepUpCeremonyContract::Error) do
      IdentityStepUpPasskeyVerificationCommitter.call!(
        actor: @actor, transaction: @transaction, session_record: @record, config: @config,
        reference: @reference, credential_params: @assertion,
      )
    end
    assert_nil @record.reload.passkey_challenge_consumed_at
    assert_equal "pending", @transaction.reload.status
    assert_equal 0, @credential.reload.sign_count
  end

  test "a superseded token cannot use a consumed Passkey challenge" do
    device = @token.device_session_record!
    @token.revoke!
    replacement = OperatorToken.create!(authentication_epoch: 0, staff: @actor, device_session: device)
    device.update!(current_refresh_token_id: replacement.id)

    assert_raises(IdentityStepUpCeremonyContract::Error) do
      IdentityStepUpPasskeyVerificationCommitter.call!(
        actor: @actor, transaction: @transaction, session_record: @record, config: @config,
        reference: @reference, credential_params: @assertion,
      )
    end
    assert_not_nil @record.reload.passkey_challenge_consumed_at
    assert_equal "revoked", @transaction.reload.status
    assert_equal 0, @credential.reload.sign_count
  end

  test "a Passkey revoked during verification cannot create evidence" do
    verifier = Webauthn::AssertionVerifier.method(:verify!)
    verify_then_revoke =
      lambda do |**arguments|
        result = verifier.call(**arguments)
        @credential.update!(status_id: OperatorPasskeyStatus::REVOKED)
        result
      end

    Webauthn::AssertionVerifier.stub(:verify!, verify_then_revoke) do
      assert_raises(IdentityStepUpCeremonyContract::Error) do
        IdentityStepUpPasskeyVerificationCommitter.call!(
          actor: @actor, transaction: @transaction, session_record: @record, config: @config,
          reference: @reference, credential_params: @assertion,
        )
      end
    end
    assert_not_nil @record.reload.passkey_challenge_consumed_at
    assert_equal "pending", @transaction.reload.status
    assert_equal OperatorPasskeyStatus::REVOKED, @credential.reload.status_id
    assert_nil @token.reload.last_step_up_at
  end

  test "an owner stopped during Passkey verification cannot receive evidence" do
    verifier = Webauthn::AssertionVerifier.method(:verify!)
    verify_then_stop =
      lambda do |**arguments|
        result = verifier.call(**arguments)
        @actor.update!(status_id: OperatorStatus::RESERVED)
        result
      end

    Webauthn::AssertionVerifier.stub(:verify!, verify_then_stop) do
      assert_raises(IdentityStepUpCeremonyContract::Error) do
        IdentityStepUpPasskeyVerificationCommitter.call!(
          actor: @actor, transaction: @transaction, session_record: @record, config: @config,
          reference: @reference, credential_params: @assertion,
        )
      end
    end
    assert_not_nil @record.reload.passkey_challenge_consumed_at
    assert_equal "pending", @transaction.reload.status
    assert_equal 5, @credential.reload.sign_count
    assert_nil @token.reload.last_step_up_at
  end

  test "device revocation during Passkey verification prevents evidence" do
    verifier = Webauthn::AssertionVerifier.method(:verify!)
    verify_then_revoke =
      lambda do |**arguments|
        result = verifier.call(**arguments)
        @token.device_session_record!.revoke!
        result
      end

    Webauthn::AssertionVerifier.stub(:verify!, verify_then_revoke) do
      assert_raises(IdentityStepUpCeremonyContract::Error) do
        IdentityStepUpPasskeyVerificationCommitter.call!(
          actor: @actor, transaction: @transaction, session_record: @record, config: @config,
          reference: @reference, credential_params: @assertion,
        )
      end
    end
    assert_not_nil @record.reload.passkey_challenge_consumed_at
    assert_equal "pending", @transaction.reload.status
    assert_equal 5, @credential.reload.sign_count
    assert_nil @token.reload.last_step_up_at
  end

  test "Auth evidence reaches OIDC completion once without changing root freshness" do
    IdentityStepUpPasskeyVerificationCommitter.call!(
      actor: @actor, transaction: @transaction, session_record: @record, config: @config,
      reference: @reference, credential_params: @assertion,
    )

    assert_equal "verified", @transaction.reload.status
    assert_equal @credential.external_id, @transaction.verified_credential_ref
    assert_equal 5, @credential.reload.sign_count
    assert_not_nil @credential.uv_verified_at
    assert_nil @token.reload.last_step_up_at

    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: @transaction, ceremony_session_ref: @admitted_ceremony.id.to_s,
    )
    result_payload = BaseAuthAdmissionCoordinator.read_result_reference!(
      reference: result.reference, surface: "org", transaction_ref: @transaction.transaction_id,
      expected_intent: "step_up",
    )
    outcome = OidcStepUpAuthorizationCompletionCommitter.call!(
      surface: "org", actor: @actor, token: @token, context: @context, ticket: @transaction,
      authorization_transaction: @authorization, admission_binding: @binding, result_payload:,
    )

    assert_equal :completed, outcome
    assert_equal "consumed", @transaction.reload.status
    assert_nil @token.reload.last_step_up_at
    assert_equal "authenticated", @authorization.reload.status_name
    assert_predicate @admitted_ceremony.reload, :completed?
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      OidcStepUpAuthorizationCompletionCommitter.call!(
        surface: "org", actor: @actor, token: @token, context: @context, ticket: @transaction,
        authorization_transaction: @authorization, admission_binding: @binding, result_payload:,
      )
    end
    assert_raises(StepUpSessionConsumable::ChallengeError) do
      IdentityStepUpPasskeyVerificationCommitter.call!(
        actor: @actor, transaction: @transaction, session_record: @record, config: @config,
        reference: @reference, credential_params: @assertion,
      )
    end
  end

  test "ORG revoked credential cannot verify a valid signature" do
    @credential.update!(status_id: OperatorPasskeyStatus::REVOKED)

    assert_raises(ActiveRecord::RecordNotFound) do
      IdentityStepUpPasskeyVerificationCommitter.call!(
        actor: @actor, transaction: @transaction, session_record: @record, config: @config,
        reference: @reference, credential_params: @assertion,
      )
    end
    assert_equal "pending", @transaction.reload.status
    assert_not_nil @record.reload.passkey_challenge_consumed_at
    assert_equal 0, @credential.reload.sign_count
    assert_nil @token.reload.last_step_up_at
  end

  test "credential security transition after verification prevents OP authorization" do
    IdentityStepUpPasskeyVerificationCommitter.call!(
      actor: @actor, transaction: @transaction, session_record: @record, config: @config,
      reference: @reference, credential_params: @assertion,
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: @transaction, ceremony_session_ref: @admitted_ceremony.id.to_s,
    )
    result_payload = BaseAuthAdmissionCoordinator.read_result_reference!(
      reference: result.reference, surface: "org", transaction_ref: @transaction.transaction_id,
      expected_intent: "step_up",
    )
    CredentialSecurityTransition.call(
      actor: @actor, current_session: @token, reason: :mfa_reset, affected_surface: "org",
      revoke_current: false, revoke_other_sessions: false,
    )

    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      OidcStepUpAuthorizationCompletionCommitter.call!(
        surface: "org", actor: @actor, token: @token, context: @context, ticket: @transaction,
        authorization_transaction: @authorization, admission_binding: @binding, result_payload:,
      )
    end
    assert_equal "revoked", @transaction.reload.status
    assert_nil @transaction.consumed_at
    assert_nil @token.reload.last_step_up_at
    assert_not_predicate @admitted_ceremony.reload, :completed?
  end
end
