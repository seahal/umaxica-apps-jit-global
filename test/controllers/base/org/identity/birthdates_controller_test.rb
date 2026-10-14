# typed: false
# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class Base::Org::Identity::BirthdatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = Rails.configuration.x.boot_config.fetch(:hosts).base_staff.host
    OperatorStatus.find_or_create_by!(id: OperatorStatus::ACTIVE)
    @operator = Operator.create!(status_id: OperatorStatus::ACTIVE)
  end

  test "show reports that a birthdate is not set" do
    host! @host
    headers = as_staff_headers(@operator, host: @host)
    token = OperatorToken.find_by!(public_id: headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
    actor = @operator
    token.rotate_refresh_token! unless token.device_session_record.current_refresh_token_id
    registration = WebAuthn::Credential.from_create(
      WebAuthn::FakeClient.new("https://#{ENV.fetch("PUBLIC_AUTH_STAFF_URL")}").create(user_verified: true),
    )
    credential = actor.staff_passkeys.create!(
      webauthn_id: registration.id, public_key: registration.public_key, sign_count: 0, external_id: SecureRandom.uuid,
    )
    requirement = StepUpRequirement.new(
      step_up_required: true, scope: "settings_birthdate", allowed_methods: [:passkey],
      phishing_resistant_required: false, user_verification_required: true, full_reauthentication_required: false,
      ttl: 15.minutes, purpose: "step_up", audience: "step_up:org", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement,
      return_to: "/identity/birthdate",
      base_browser_nonce: nonce, base_token: token,
    )
    transaction = issuance.transaction
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "org", reference: issuance.reference)
    attached, raw_sid = OperatorAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    digest = AuthAdmissionBinding.browser_digest(surface: "org", entry_ref: issuance.reference, nonce: nonce)
    binding.confirm_base!(base_token: token, browser_digest: digest)
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "org", expected_intent: "step_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    admitted, = OperatorAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", previous_raw_sid: raw_sid,
      step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    # Presentation is reached through a admitted proof bound to this actor and credential.
    transaction.record_verification!(
      method: "passkey", aal: "aal1", phishing_resistant: true, user_verified: true,
      verified_at: transaction.class.database_now, verified_credential_ref: credential.external_id,
    )
    proof = BaseAuthAdmissionCoordinator.issue_result!(transaction: transaction, ceremony_session_ref: admitted.id.to_s)
    IdentityStepUpCeremonyFreshnessCommitter.call!(
      actor: actor, token: token, transaction: transaction, requirement: requirement, result_reference: proof.reference,
    )
    client = OidcClientRegistry.find!("base-org-ww")
    now = OperatorRpSession.database_now
    rp_session = OperatorRpSession.create!(
      operator_token: token, oidc_client_id: client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: now,
      refresh_token_expires_at: now + 1.hour,
    )
    access = AuthenticationTokenService.encode(
      @operator, host: @host, resource_type: "operator", session_public_id: token.public_id,
                 base_session_public_id: token.public_id, oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                 expires_at: now + 1.hour, scopes: %w(openid profile), issuer: OidcIssuer.for_client(client),
                 audiences: [client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
                 subject: OidcSubject.for(@operator, resource_type: "operator"), client_id: client.client_id,
    )
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = rp_session.issue_refresh_token!
    get base_org_identity_birthdate_url(ri: "jp", host: @host)

    assert_response :success
    assert_equal "base/org/identity/birthdates/show", inertia_component
    assert_nil inertia_props.fetch("birthdate")
  end

  test "show includes the stored birthdate when one is present" do
    host! @host
    @operator.update!(birthdate: "1990-01-02")
    headers = as_staff_headers(@operator, host: @host)
    token = OperatorToken.find_by!(public_id: headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
    actor = @operator
    token.rotate_refresh_token! unless token.device_session_record.current_refresh_token_id
    registration = WebAuthn::Credential.from_create(
      WebAuthn::FakeClient.new("https://#{ENV.fetch("PUBLIC_AUTH_STAFF_URL")}").create(user_verified: true),
    )
    credential = actor.staff_passkeys.create!(
      webauthn_id: registration.id, public_key: registration.public_key, sign_count: 0, external_id: SecureRandom.uuid,
    )
    requirement = StepUpRequirement.new(
      step_up_required: true, scope: "settings_birthdate", allowed_methods: [:passkey],
      phishing_resistant_required: false, user_verification_required: true, full_reauthentication_required: false,
      ttl: 15.minutes, purpose: "step_up", audience: "step_up:org", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement,
      return_to: "/identity/birthdate",
      base_browser_nonce: nonce, base_token: token,
    )
    transaction = issuance.transaction
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "org", reference: issuance.reference)
    attached, raw_sid = OperatorAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    digest = AuthAdmissionBinding.browser_digest(surface: "org", entry_ref: issuance.reference, nonce: nonce)
    binding.confirm_base!(base_token: token, browser_digest: digest)
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "org", expected_intent: "step_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    admitted, = OperatorAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", previous_raw_sid: raw_sid,
      step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    # Presentation is reached through a admitted proof bound to this actor and credential.
    transaction.record_verification!(
      method: "passkey", aal: "aal1", phishing_resistant: true, user_verified: true,
      verified_at: transaction.class.database_now, verified_credential_ref: credential.external_id,
    )
    proof = BaseAuthAdmissionCoordinator.issue_result!(transaction: transaction, ceremony_session_ref: admitted.id.to_s)
    IdentityStepUpCeremonyFreshnessCommitter.call!(
      actor: actor, token: token, transaction: transaction, requirement: requirement, result_reference: proof.reference,
    )
    client = OidcClientRegistry.find!("base-org-ww")
    now = OperatorRpSession.database_now
    rp_session = OperatorRpSession.create!(
      operator_token: token, oidc_client_id: client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: now,
      refresh_token_expires_at: now + 1.hour,
    )
    access = AuthenticationTokenService.encode(
      @operator, host: @host, resource_type: "operator", session_public_id: token.public_id,
                 base_session_public_id: token.public_id, oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                 expires_at: now + 1.hour, scopes: %w(openid profile), issuer: OidcIssuer.for_client(client),
                 audiences: [client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
                 subject: OidcSubject.for(@operator, resource_type: "operator"), client_id: client.client_id,
    )
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = rp_session.issue_refresh_token!
    get base_org_identity_birthdate_url(ri: "jp", host: @host)

    assert_response :success
    assert_equal "base/org/identity/birthdates/show", inertia_component
    assert_equal "1990-01-02", inertia_props.fetch("birthdate")
  end

  private
end
