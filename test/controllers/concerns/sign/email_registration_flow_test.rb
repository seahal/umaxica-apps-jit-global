# frozen_string_literal: true

require "test_helper"

class SignEmailRegistrationFlowTest < ActionDispatch::IntegrationTest
  setup do
    https!
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    @user = clients(:one)
    @token = ClientToken.create!(
      user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)
    begin
      rp_cookie_pairs =
        begin
          rp_host = @host
          rp_token = @token
          rp_client = OidcClientRegistry.find!("base-app-ww")
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if @base_browser_rp_credentials[rp_key] ||
              (rp_token.currently_usable? &&
                !(rp_token.device_session_id && OpAppGrant.exists?(
                  device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                )))
            unless @base_browser_rp_credentials[rp_key]
              rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
              rp_now = Time.current
              rp_session = OpAppGrant.create!(
                client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                @user, host: rp_host, resource_type: "client",
                       session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                       oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                       expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                       issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                       subject: OidcSubject.for(@user, resource_type: "client"), client_id: rp_client.client_id,
              )
              @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
            end
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            [
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ]
          else
            []
          end
        end
      cookies.merge(rp_cookie_pairs, URI.parse("https://#{rp_host}/"))
    end
    # Synthetic evidence isolates contact mutation; the public Base operation owns freshness.
    passkey = @user.client_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "app-contact-verification-public-key", sign_count: 0,
    )
    requirement = StepUpRequirement.new(
      scope: "settings_email", allowed_methods: [:passkey], purpose: "step_up", audience: "step_up:app",
      step_up_required: true, phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, actor_ref: @user.public_id,
      resource_ref: nil, tenant_ref: nil,
      session_binding: @token.public_id, token_binding: @token.public_id, require_session_binding: true,
    )
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: @user,
      token: @token,
      requirement: requirement,
      return_to: "/identity/emails/registration/new",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: @token,
    )
    transaction = issuance.transaction
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(base_token: @token, browser_digest: binding.base_browser_digest)
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "step_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    transaction.record_verification!(
      method: "passkey", aal: "aal1", phishing_resistant: true,
      user_verified: true,
      verified_at: ClientStepUpCeremonyTransaction.database_now, verified_credential_ref: passkey.public_id,
    )
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
      previous_raw_sid: raw_sid,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: ceremony)
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: transaction, ceremony_session_ref: ceremony.id.to_s,
    )
    IdentityStepUpCeremonyFreshnessCommitter.call!(
      actor: @user, token: @token, transaction: transaction, requirement: requirement, raw_result: result.code,
    )
    access_token = AuthenticationToken.encode(
      @user, host: @host, session_public_id: @token.public_id,
             resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    # Base pages authenticate by the Browser RP credential; the root cookie alone does not.
    begin
      rp_cookie_pairs =
        begin
          rp_host = @host
          rp_token = @token
          rp_client = OidcClientRegistry.find!("base-app-ww")
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if @base_browser_rp_credentials[rp_key] ||
              (rp_token.currently_usable? &&
                !(rp_token.device_session_id && OpAppGrant.exists?(
                  device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                )))
            unless @base_browser_rp_credentials[rp_key]
              rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
              rp_now = Time.current
              rp_session = OpAppGrant.create!(
                client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                @user, host: rp_host, resource_type: "client",
                       session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                       oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                       expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                       issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                       subject: OidcSubject.for(@user, resource_type: "client"), client_id: rp_client.client_id,
              )
              @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
            end
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            [
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ]
          else
            []
          end
        end
      cookies.merge(rp_cookie_pairs, URI.parse("https://#{rp_host}/"))
    end
    @headers = {
      "Authorization" => "Bearer #{access_token}",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => @host,
    }.freeze

    ActionMailer::Base.deliveries.clear
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end
  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "invalid address renders the public entry without creating a candidate" do
    assert_no_difference(["ClientEmail.count", "ClientEmailCeremonyTransaction.count"]) do
      post base_app_identity_emails_registration_path(ri: "jp"),
           params: { user_email: { raw_address: "invalid-address" } }, headers: @headers
    end
    assert_response :unprocessable_content
    assert_predicate inertia_props.fetch("errors"), :present?
    assert_nil flash[:notice]
    assert_nil flash[:alert]
  end

  test "update without this browser's registration returns to the entry without consuming an OTP" do
    before = @token.reload.attributes.slice("root_login_established_at", "last_step_up_at", "discard_at")
    assert_no_difference(["ClientEmail.count", "ClientEmailCeremonyTransaction.count"]) do
      patch base_app_identity_emails_registration_path(ri: "jp"),
            params: { user_email: { pass_code: "123456" } }, headers: @headers
    end
    assert_response :redirect
    assert_equal new_base_app_identity_emails_registration_path, URI.parse(response.location).path
    assert_equal before, @token.reload.attributes.slice(*before.keys)
    assert_nil flash[:notice]
  end

  test "a failed stealth validation retains the pending original candidate and verifier" do
    post base_app_identity_emails_registration_path(ri: "jp"),
         params: { user_email: { raw_address: "stealth-#{SecureRandom.hex(8)}@example.test" } }, headers: @headers

    assert_response :redirect
    email = @user.client_emails.find_by!(public_id: session[:email_registration_public_id])
    transaction = ClientEmailCeremonyTransaction.find_by!(transaction_id: session[:email_registration_transaction_ref])
    original = transaction.attributes.slice("otp_generation", "otp_verifier", "otp_expires_at")
    TurnstileVerifierStub.challenge_response = { "success" => false }
    patch base_app_identity_emails_registration_path(ri: "jp"),
          params: { user_email: { pass_code: "123456" } }, headers: @headers

    assert_response :unprocessable_content
    assert_equal original, transaction.reload.attributes.slice(*original.keys)
    assert_nil transaction.otp_consumed_at
    assert_nil email.reload.binding_finalized_at
    assert_nil flash[:alert]
  end

  test "redelivery without a pending browser registration returns to the entry" do
    assert_no_difference("ClientEmailCeremonyTransaction.count") do
      post base_app_identity_emails_registration_redelivery_path(ri: "jp"), headers: @headers
    end
    assert_response :redirect
    assert_equal new_base_app_identity_emails_registration_path, URI.parse(response.location).path
    assert_nil flash[:notice]
  end

  test "redelivery during cooldown retains generation and the original expiry without a flash" do
    post base_app_identity_emails_registration_path(ri: "jp"),
         params: { user_email: { raw_address: "cooldown-#{SecureRandom.hex(8)}@example.test" } }, headers: @headers

    assert_response :redirect
    transaction = ClientEmailCeremonyTransaction.find_by!(transaction_id: session[:email_registration_transaction_ref])
    original = transaction.attributes.slice("otp_generation", "otp_verifier", "otp_expires_at")
    assert_no_enqueued_jobs do
      post base_app_identity_emails_registration_redelivery_path(ri: "jp"), headers: @headers
    end
    assert_response :redirect
    assert_equal original, transaction.reload.attributes.slice(*original.keys)
    assert_nil flash[:notice]
    assert_nil flash[:alert]
  end

  test "redelivery after cooldown issues one new generation under the original candidate and deadline" do
    post base_app_identity_emails_registration_path(ri: "jp"),
         params: { user_email: { raw_address: "resend-#{SecureRandom.hex(8)}@example.test" } }, headers: @headers

    assert_response :redirect
    email = @user.client_emails.find_by!(public_id: session[:email_registration_public_id])
    transaction = ClientEmailCeremonyTransaction.find_by!(transaction_id: session[:email_registration_transaction_ref])
    generation = transaction.otp_generation
    deadline = transaction.otp_expires_at
    email.update!(otp_last_sent_at: email.class.database_now - 2.minutes)
    assert_enqueued_jobs 1 do
      post base_app_identity_emails_registration_redelivery_path(ri: "jp"), headers: @headers
    end
    assert_response :redirect
    assert_not_equal generation, transaction.reload.otp_generation
    assert_equal deadline, transaction.otp_expires_at
    assert_equal email.public_id, session[:email_registration_public_id]
    assert_nil email.reload.binding_finalized_at
    assert_nil flash[:notice]
  end
end
