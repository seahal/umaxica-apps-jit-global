# typed: false
# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"
# require "helpers/global_test_support"
require "base64"

# Integration tests for Org verification flow
#
# These tests verify:
# - Org staff verification flow works similarly to App
# - Email OTP is NOT available for Org (passkey only)
# - High-risk operations require verification
class OrgVerificationFlowTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses, :operator_passkeys, :operator_passkey_statuses

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    @staff = operators(:one)
    @token = OperatorToken.create!(
      staff: @staff,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      public_id: "ovf#{SecureRandom.hex(4)}",
      discard_at: 1.day.from_now,
    )
    @headers =
      begin
        rp_headers = as_staff_headers(@staff, host: @host)
        rp_host = rp_headers["Host"]
        rp_route =
          begin
            Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
          rescue ActionController::RoutingError
            nil
          end
        rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
        if %w(base warp core edit).include?(rp_family) && rp_surface == "org"
          rp_client_id =
            case rp_family
            when "base" then "base-#{rp_surface}-ww"
            when "edit" then "edit-org"
            else "#{rp_family}-#{rp_surface}"
            end
          rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && OperatorRpSession.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
            rp_now = Time.current
            rp_session = OperatorRpSession.create!(
              operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.staff, host: rp_host, resource_type: "operator",
                              session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                              oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                              expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                              issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                              jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                              subject: OidcSubject.for(
                                rp_token.staff,
                                resource_type: "operator",
                              ), client_id: rp_client.client_id,
            )
            @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end
    @headers["X-TEST-SESSION-PUBLIC-ID"] = @token.public_id
    @token.rotate_refresh_token! unless @token.device_session.current_refresh_token_id
    requirement = StepUpRequirement.new(
      step_up_required: true, scope: "settings_passkey", allowed_methods: [:passkey],
      phishing_resistant_required: false, user_verification_required: false, full_reauthentication_required: false,
      ttl: 15.minutes, purpose: "step_up", audience: "step_up:org", session_binding: @token.public_id,
      token_binding: @token.public_id, require_session_binding: true, actor_ref: @staff.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: @staff, token: @token, requirement: requirement, return_to: "/identity/passkeys",
      base_browser_nonce: nonce, base_token: @token,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "org", reference: issuance.reference)
    attached, raw_sid = OperatorAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: @token, browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "org", entry_ref: issuance.reference, nonce: nonce,
      ),
    )
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "org", expected_intent: "step_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    admitted, admitted_sid = OperatorAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", previous_raw_sid: raw_sid,
      step_up_ceremony_transaction_ref: issuance.transaction.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    continuity_cookie = [@headers.fetch("Cookie"), "#{cookie_name}=#{Rack::Utils.escape(admitted_sid)}"].join("; ")
    @headers = @headers.merge("Cookie" => continuity_cookie, "HTTP_COOKIE" => continuity_cookie)
  end

  test "org verification show page does not display email option" do
    # Create passkey for staff to ensure link is rendered
    OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: "test_webauthn_id",
      public_key: "test_public_key",
      sign_count: 0,
    )

    get auth_org_verification_url(ri: "jp"), headers: @headers

    assert_response :success

    assert response.body.include?("/verification/passkey/new") || response.body.include?("passkey")

    # Should NOT have email link (no emails route for org)
    assert_select "a[href*='email']", count: 0
    assert_select "a[href*='verification/totp']", count: 0
  end

  test "org verifies a real passkey assertion without applying Root freshness on Auth" do
    fake = WebAuthn::FakeClient.new("https://#{@host}", encoding: :base64url)
    registration = WebAuthn::Credential.from_create(fake.create(user_verified: true))
    passkey = @staff.staff_passkeys.create!(
      webauthn_id: registration.id, public_key: registration.public_key, sign_count: 0,
      external_id: SecureRandom.uuid, status_id: OperatorPasskeyStatus::ACTIVE,
    )
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    get(new_auth_org_verification_passkey_url(ri: "jp"), headers: @headers)

    assert_response :success
    assert_nil @token.reload.last_step_up_at
    post(
      auth_org_verification_passkey_options_path(ri: "jp"),
      params: { "cf-turnstile-response" => "test" }, headers: @headers,
    )

    assert_response :success
    options = response.parsed_body
    credential = fake.get(challenge: options.fetch("options").fetch("challenge"), user_verified: true, sign_count: 1)
    post(
      auth_org_verification_passkey_url(ri: "jp"),
      params: { challenge_id: options.fetch("challenge_id"), credential: credential }, headers: @headers,
    )

    assert_response :success
    assert_equal "ok", response.parsed_body.fetch("status")
    assert_equal auth_org_verification_handoff_path(ri: "jp"), response.parsed_body.fetch("redirect_url")
    assert_equal 1, passkey.reload.sign_count
    assert_nil @token.reload.last_step_up_at
  ensure
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
  end

  private

  private

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = "test_csrf_token"
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "X-CSRF-Token" => csrf_token,
    }

    if respond_to?(:cookies, true)
      cookies["csrf_token"] = csrf_token
    else
      headers["Cookie"] = "csrf_token=#{csrf_token}"
    end

    headers
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "AUTH")
    surface =
      if service == "AUTH"
        case resource_type
        when "operator" then "ORG"
        when "visitor" then "COM"
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      elsif normalized.include?(".com") || normalized.include?("com.")
        "COM"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
  end
end

# DAMP auth header helpers for this test class.
class OrgVerificationFlowTest
  private
end

# DAMP local route helper aliases for former shared test support.
class OrgVerificationFlowTest
  SURFACE_ROUTE_PREFIX_MAP = {
    "sign_app_" => "auth_app_",
    "sign_org_" => "auth_org_",
    "sign_com_" => "auth_com_",
    "acme_app_" => "base_app_",
    "acme_org_" => "base_org_",
    "acme_com_" => "base_com_",
  }.freeze unless const_defined?(:SURFACE_ROUTE_PREFIX_MAP, false)

  private

  def method_missing(name, ...)
    aliased_name = aliased_surface_route_helper_name(name)
    return public_send(aliased_name, ...) if aliased_name && respond_to?(aliased_name, true)

    super
  end

  def respond_to_missing?(name, include_private = false)
    aliased_name = aliased_surface_route_helper_name(name)
    (aliased_name && respond_to?(aliased_name, include_private)) || super
  end

  def aliased_surface_route_helper_name(name)
    helper_name = name.to_s
    self.class::SURFACE_ROUTE_PREFIX_MAP.each do |source_prefix, target_prefix|
      return helper_name.sub(source_prefix, target_prefix).to_sym if helper_name.start_with?(source_prefix)
    end
    nil
  end
end
