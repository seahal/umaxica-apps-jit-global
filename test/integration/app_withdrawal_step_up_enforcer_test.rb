# typed: false
# frozen_string_literal: true

require "test_helper"

class AppWithdrawalStepUpEnforcerTest < ActionDispatch::IntegrationTest
  fixtures :client_totp_credential_statuses

  setup do
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::ACTIVE)
    ClientTokenBindingMethod.find_or_create_by!(id: ClientTokenBindingMethod::LEGACY)
    ClientTokenDbscStatus.find_or_create_by!(id: ClientTokenDbscStatus::NOTHING)

    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    @client = Client.create!(
      status_id: ClientStatus::NOTHING,
      visibility_id: ClientVisibility::USER,
      mfa_level_id: ClientMfaLevel::NOTHING,
      mfa_status_id: ClientMfaStatus::UNCONFIGURED,
    )
    @token = ClientToken.create!(
      user: @client,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
      user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
      discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @client)
    BaseSelectorAuthority.prepare(surface: :app, principal: @client, session: @token)
  end

  test "app withdrawal destructive action requires fresh step-up" do
    create_totp_credential!

    patch base_app_identity_withdrawal_url(ri: "jp", host: @host),
          params: { ack_schedule_purge: "1" },
          headers: authenticated_headers

    assert_response :unauthorized
    assert_equal VerificationBase::STEP_UP_REQUIRED_MESSAGE, response.body
  end

  test "app withdrawal destructive action rejects stale step-up" do
    create_totp_credential!
    mark_token_step_up_satisfied!(at: 1.day.ago)

    patch base_app_identity_withdrawal_url(ri: "jp", host: @host),
          params: { ack_schedule_purge: "1" },
          headers: authenticated_headers

    assert_response :unauthorized
    assert_equal VerificationBase::STEP_UP_REQUIRED_MESSAGE, response.body
  end

  test "app withdrawal destructive action accepts valid token-bound step-up" do
    mark_token_step_up_satisfied!

    patch base_app_identity_withdrawal_url(ri: "jp", host: @host),
          params: { ack_schedule_purge: "1" },
          headers: authenticated_headers

    assert_response :see_other
    assert_redirected_to new_base_app_identity_withdrawal_path(ri: "jp", ack_schedule_purge: "1")
  end

  private

  def create_totp_credential!
    ClientTotpCredential.create!(
      user: @client,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )
  end

  def mark_token_step_up_satisfied!(at: nil)
    token = @token
    actor = token.user
    token.rotate_refresh_token! unless token.device_session.current_refresh_token_id
    credential = actor.client_totp_credentials.find_by(
      user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    ) || ClientTotpCredential.create_for_user!(
      user: actor, user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    requirement = StepUpRequirement.new(
      step_up_required: true, scope: "withdrawal", allowed_methods: [:totp],
      phishing_resistant_required: false, user_verification_required: false, full_reauthentication_required: false,
      ttl: 15.minutes, purpose: "step_up", audience: "step_up:app", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement,
      return_to: "/identity/withdrawal",
      base_browser_nonce: nonce, base_token: token,
    )
    transaction = issuance.transaction
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    digest = AuthAdmissionBinding.browser_digest(surface: "app", entry_ref: issuance.reference, nonce: nonce)
    binding.confirm_base!(base_token: token, browser_digest: digest)
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "step_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", previous_raw_sid: raw_sid,
      step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    # This fixture exercises withdrawal authorization through an admitted, credential-bound proof.
    transaction.record_verification!(
      method: "totp", aal: "aal1", phishing_resistant: false, user_verified: false,
      verified_at: transaction.class.database_now, verified_credential_ref: credential.public_id,
    )
    proof = BaseAuthAdmissionCoordinator.issue_result!(transaction: transaction, ceremony_session_ref: admitted.id.to_s)
    IdentityStepUpCeremonyFreshnessCommitter.call!(
      actor: actor, token: token, transaction: transaction, requirement: requirement, result_reference: proof.reference,
    )
    travel(16.minutes) if at
  end

  def authenticated_headers
    rp_cookie =
      begin
        fixture_root = @token
        fixture_actor = @client
        fixture_host = @host
        fixture_root.rotate_refresh_token! unless fixture_root.device_session.current_refresh_token_id
        fixture_client = OidcClientRegistry.find!("base-app-ww")
        @base_rp_fixture_credentials ||= {}
        fixture_key = [fixture_client.client_id, fixture_root.public_id]
        unless @base_rp_fixture_credentials[fixture_key]
          fixture_now = ClientRpSession.database_now
          fixture_rp = ClientRpSession.create!(
            client_token: fixture_root, oidc_client_id: fixture_client.client_id,
            oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
            oidc_nonce: SecureRandom.hex(16), oidc_auth_time: fixture_now,
            refresh_token_expires_at: fixture_now + 1.hour,
          )
          fixture_access = AuthenticationTokenService.encode(
            fixture_actor, host: fixture_host, resource_type: "client",
                           session_public_id: fixture_root.public_id, base_session_public_id: fixture_root.public_id,
                           oidc_sid: fixture_rp.public_id, oidc_jti: fixture_rp.oidc_jti,
                           expires_at: fixture_now + 1.hour, scopes: %w(openid profile),
                           issuer: OidcIssuer.for_client(fixture_client), audiences: [fixture_client.aud],
                           jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(fixture_client),
                           subject: OidcSubject.for(
                             fixture_actor,
                             resource_type: "client",
                           ), client_id: fixture_client.client_id,
          )
          fixture_refresh = fixture_rp.issue_refresh_token!
          @base_rp_fixture_credentials[fixture_key] = [
            "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(fixture_access)}",
            "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(fixture_refresh)}",
          ].join("; ")
        end
        @base_rp_fixture_credentials.fetch(fixture_key)
      end
    { "Host" => @host, "Cookie" => rp_cookie, "Accept" => "text/html" }
  end

  def access_token
    AuthenticationToken.encode(
      @client,
      host: @host,
      session_public_id: @token.public_id,
      resource_type: "client",
      jwt_issuer_id: "surface:BASE_APP",
    )
  end
end
