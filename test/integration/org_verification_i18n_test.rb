# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OrgVerificationI18nTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PRIVATE_AUTH_STAFF_URL")
    host! @host
    OrgZenithRecord.connected_to(role: :writing) do
      OperatorStatus.insert_missing_fixed_ids!(
        [OperatorStatus::ACTIVE,
         OperatorStatus::NOTHING, OperatorStatus::RESERVED,],
      )
    end

    @staff = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::NOTHING,
      public_id: Operator.generate_public_id,
    )
    @token = OperatorToken.create!(
      authentication_epoch: 0,
      staff: @staff,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      public_id: PublicId.generate,
      discard_at: 1.day.from_now,
    )
    @headers = begin
      rp_headers = as_staff_headers(
        @staff, host: @host, headers: browser_headers,
                session_public_id: @token.public_id,
      )
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
          when "edit" then "edit-org-ww"
          when "tech" then "tech-org-ww"
          else "#{rp_family}-#{rp_surface}-jp"
          end
        rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
        rp_client = OidcClientRegistry.find!(rp_client_id)
        rp_key = [rp_client.client_id, rp_token.public_id]
        @base_browser_rp_credentials ||= {}
        if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
            !(rp_token.device_session_id && OpOrgGrant.exists?(
              device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
            ))
          rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
          rp_now = Time.current
          rp_session = OpOrgGrant.create!(
            authentication_epoch: 0,
            operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
            oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
            refresh_token_expires_at: rp_now + 10.minutes,
          )
          rp_access = AuthenticationTokenService.encode(
            rp_token.actor_record, host: rp_host, resource_type: "operator",
                                   session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                                   oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                   expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                   issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                   jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                   subject: OidcSubject.for(
                                     rp_token.actor_record,
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
    end.freeze

    OperatorPasskey.create!(
      staff: @staff,
      description: "verify i18n passkey",
      webauthn_id: "org-verify-i18n-#{SecureRandom.hex(4)}",
      external_id: SecureRandom.uuid,
      public_key: "public_key",
      sign_count: 0,
      status_id: OperatorPasskeyStatus::ACTIVE,
    )
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

  test "verification view displays translated strings in Japanese" do
    get auth_org_verification_url(ri: "jp"), headers: @headers

    assert_response :success
    # The headings arrive as props and the React page renders them, so the translated strings the
    # server chose for this locale are what the page object carries.
    assert_equal I18n.t("sign.org.verification.index.title", locale: :ja), inertia_props.fetch("title")
    assert_equal I18n.t("sign.org.verification.new.title", locale: :ja), inertia_props.fetch("section_title")
  end

  test "verification view displays translated strings in English" do
    get auth_org_verification_url(ri: "us", lx: "en"), headers: @headers

    assert_response :success
    # The headings arrive as props and the React page renders them, so the translated strings the
    # server chose for this locale are what the page object carries.
    assert_equal I18n.t("sign.org.verification.index.title", locale: :en), inertia_props.fetch("title")
    assert_equal I18n.t("sign.org.verification.new.title", locale: :en), inertia_props.fetch("section_title")
  end
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
class OrgVerificationI18nTest
  private
end
