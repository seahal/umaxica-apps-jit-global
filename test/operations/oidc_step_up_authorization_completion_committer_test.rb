# frozen_string_literal: true

require "test_helper"

class OidcStepUpAuthorizationCompletionCommitterTest < ActiveSupport::TestCase
  fixtures :clients, :operators, :operator_passkeys

  test "a TOTP result is refused if APP Security Mode becomes ADVANCED before OP completion" do
    actor = clients(:one)
    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    client = OidcClientRegistry.find!("core-app-jp")
    now = OpBaseAppRecord.database_now
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch,
      client_token: token,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now - 1.hour,
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
    redirect_uri = client.redirect_uris_by_realm.fetch("client").first
    params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri:,
      scope: grant.oidc_scope,
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest("app-policy-step-up"), padding: false),
      code_challenge_method: "S256",
      prompt: "login",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    }
    validated_request = OidcAuthorizeRequestResolver.call(params:, resource: actor, resource_type: "client")
    issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "app", actor:, token:, client:, params:, validated_request:,
    )
    context = issuance.context
    authorization = issuance.authorization_transaction
    ticket = issuance.ticket
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.entry_ref)
    attached_ceremony, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached_ceremony, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: token,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref: issuance.entry_ref, nonce: authorization.login_challenge,
      ),
    )
    admitted_ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff",
      previous_raw_sid: raw_sid,
      step_up_ceremony_transaction_ref: ticket.transaction_id,
    )
    binding.redeem!(auth_session: attached_ceremony, admitted_auth_session: admitted_ceremony)
    verification_time = ticket.class.database_now
    ticket.record_verification!(
      method: "totp", aal: "aal1", phishing_resistant: false, user_verified: false,
      verified_at: verification_time, verified_credential_ref: credential.public_id,
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: ticket, ceremony_session_ref: admitted_ceremony.id.to_s,
    )
    result_payload = BaseAuthAdmissionCoordinator.read_result_reference!(
      reference: result.reference, surface: "app", transaction_ref: ticket.transaction_id,
      expected_intent: "step_up",
    )
    token_before = token.attributes.slice(
      "refresh_token_digest", "refresh_token_generation", "root_login_established_at", "last_step_up_at",
    )

    actor.update!(security_mode_id: SecurityModeConfigurable::ADVANCED)

    outcome = OidcStepUpAuthorizationCompletionCommitter.call!(
      surface: "app", actor:, token:, context:, ticket:, authorization_transaction: authorization,
      admission_binding: binding, result_payload:,
    )

    assert_equal :policy_refused, outcome
    assert_equal ClientStepUpContextState::FAILED, context.reload.state_id
    assert_equal "policy_refused", ClientStepUpContextTransition.find_by!(owner_id: context.id).reason_code
    assert_equal "revoked", ticket.reload.status
    assert_equal AuthCeremonySession::STATUS_REVOKED, admitted_ceremony.reload.status_id
    assert_predicate authorization.reload, :pending?
    assert_equal token_before, token.reload.attributes.slice(*token_before.keys)
    outbox = ClientStepUpAuditOutbox.find_by!(context_ref: context.public_id)

    assert_equal "step_up.failed", outbox.event_type
    assert_equal "policy_refused", outbox.payload.fetch("failure_code")
    assert_empty ClientStepUpCommit.where(context_ref: context.public_id)
  end

  test "ORG ticket result completes the OP authorization without establishing or rotating a root login" do
    actor = operators(:one)
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor)
    client = OidcClientRegistry.find!("core-org-jp")
    now = OpBaseOrgRecord.database_now
    grant = OpOrgGrant.create!(
      authentication_epoch: token.authentication_epoch,
      operator_token: token,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now - 1.hour,
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
    redirect_uri = client.redirect_uris_by_realm.fetch("operator").first
    params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri:,
      scope: grant.oidc_scope,
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest("org-step-up"), padding: false),
      code_challenge_method: "S256",
      prompt: "login",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    }
    validated_request = OidcAuthorizeRequestResolver.call(params:, resource: actor, resource_type: "operator")
    issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "org", actor:, token:, client:, params:, validated_request:,
    )
    context = issuance.context
    authorization = issuance.authorization_transaction
    ticket = issuance.ticket
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "org", reference: issuance.entry_ref)
    attached_ceremony, raw_sid = OperatorAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached_ceremony, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: token,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "org", entry_ref: issuance.entry_ref, nonce: authorization.login_challenge,
      ),
    )
    admitted_ceremony, = OperatorAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff",
      previous_raw_sid: raw_sid,
      step_up_ceremony_transaction_ref: ticket.transaction_id,
    )
    binding.redeem!(auth_session: attached_ceremony, admitted_auth_session: admitted_ceremony)
    verification_time = ticket.class.database_now
    ticket.record_verification!(
      method: "passkey", aal: "aal1", phishing_resistant: true, user_verified: true,
      verified_at: verification_time, verified_credential_ref: operator_passkeys(:one).external_id.to_s,
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: ticket, ceremony_session_ref: admitted_ceremony.id.to_s,
    )
    result_payload = BaseAuthAdmissionCoordinator.read_result_reference!(
      reference: result.reference, surface: "org", transaction_ref: ticket.transaction_id,
      expected_intent: "step_up",
    )
    token_before = token.attributes.slice(
      "refresh_token_digest", "refresh_token_generation", "root_login_established_at", "last_step_up_at",
    )
    device_before = token.device_session_record!.attributes.slice("current_refresh_token_id", "revoked_at")
    grant_before = grant.attributes.slice("refresh_token_digest", "refresh_generation", "oidc_auth_time")

    outcome = OidcStepUpAuthorizationCompletionCommitter.call!(
      surface: "org", actor:, token:, context:, ticket:, authorization_transaction: authorization,
      admission_binding: binding, result_payload:,
    )

    assert_equal :completed, outcome
    assert_equal AuthCeremonySession::STATUS_COMPLETED, admitted_ceremony.reload.status_id
    assert_equal "authenticated", authorization.reload.status_name
    assert_equal actor.public_id, authorization.actor_ref
    assert_equal token.public_id, authorization.session_ref
    assert_equal "passkey", authorization.auth_method
    assert_equal OidcAuthorizeRequestResolver::STEP_UP_ACR, authorization.acr
    assert_equal verification_time.to_i, authorization.authenticated_at.to_i
    assert_equal OperatorStepUpContextState::PENDING, context.reload.state_id
    assert_equal "consumed", ticket.reload.status
    assert_equal token_before, token.reload.attributes.slice(*token_before.keys)
    assert_equal device_before, token.device_session_record!.attributes.slice(*device_before.keys)
    assert_equal grant_before, grant.reload.attributes.slice(*grant_before.keys)
    assert_empty OperatorStepUpCommit.where(context_ref: context.public_id)
    assert_empty OperatorStepUpAuditOutbox.where(context_ref: context.public_id)
  end
end
