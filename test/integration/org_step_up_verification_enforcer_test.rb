# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "base64"
require "webauthn/fake_client"

class OrgStepUpVerificationEnforcerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_chronicle_events, :operator_chronicle_levels,
           :operator_token_statuses, :operator_token_kinds

  setup do
    @base_host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    @auth_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    @staff = Operator.create!(
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    @token = OperatorToken.create!(
      staff: @staff,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      discard_at: 1.day.from_now,
      public_id: "stepup_org_#{SecureRandom.hex(4)}",
    )
    @base_headers =
      begin
        rp_headers = as_staff_headers(@staff, host: @base_host, session_public_id: @token.public_id)
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
      end
    @auth_headers =
      begin
        rp_headers = as_staff_headers(@staff, host: @auth_host, session_public_id: @token.public_id)
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
      end
  end

  test "GET protected endpoint redirects to setup when configured methods are zero" do
    get base_org_identity_withdrawal_url(ri: "jp", host: @base_host), headers: @base_headers

    assert_response :redirect
    target = URI.parse(response.location)

    assert_equal @base_host, target.host
    assert_equal "/verification/setup", target.path
    assert_predicate Rack::Utils.parse_query(target.query)["pt"], :present?
  end

  test "a configured Org passkey remains configured while the ticket attempt boundary makes it unusable" do
    @staff.staff_passkeys.create!(
      webauthn_id: SecureRandom.urlsafe_base64(32), external_id: SecureRandom.uuid,
      public_key: "stored fixture key", status_id: OperatorPasskeyStatus::ACTIVE,
    )
    ticket = OperatorStepUpSession.create!(
      staff_token: @token, scope: "settings_passkey", return_to: "/identity/passkeys",
      status: "PENDING", discard_at: 10.minutes.from_now, attempt_count: 5,
    )

    assert_equal [:passkey], StepUpConfiguredMethodsQuery.call(@staff)
    assert_empty StepUpAvailableMethods.call(@staff, ticket: ticket)
    assert_predicate @token.reload, :currently_usable?
  end

  test "GET protected endpoint redirects to verification when usable methods exist" do
    OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: "stepup_staff_passkey_#{SecureRandom.hex(4)}",
      external_id: SecureRandom.uuid,
      public_key: "public_key",
      sign_count: 0,
      description: "stepup passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )

    get base_org_identity_withdrawal_url(ri: "jp", host: @base_host), headers: @base_headers

    assert_response :redirect
    uri = URI.parse(response.location)

    assert_equal "/verification", uri.path
  end

  test "Auth refuses a protected POST without admission even when a usable credential exists" do
    OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: "stepup_staff_passkey_post_#{SecureRandom.hex(4)}",
      external_id: SecureRandom.uuid,
      public_key: "public_key",
      sign_count: 0,
      description: "stepup passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )

    post auth_org_verification_passkey_options_url(ri: "jp", host: @auth_host), headers: @auth_headers

    assert_response :bad_request
    assert_nil @token.reload.last_step_up_at
  end

  test "real passkey verification leaves Auth without freshness until Base consumes the result" do
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
    continuity_cookie = [@auth_headers.fetch("Cookie"), "#{cookie_name}=#{Rack::Utils.escape(admitted_sid)}"].join("; ")
    @auth_headers = @auth_headers.merge("Cookie" => continuity_cookie, "HTTP_COOKIE" => continuity_cookie)
    host!(@auth_host)
    https!
    fake = WebAuthn::FakeClient.new("https://#{@auth_host}", encoding: :base64url)
    registration = WebAuthn::Credential.from_create(fake.create(user_verified: true))
    passkey = @staff.staff_passkeys.create!(
      webauthn_id: registration.id, public_key: registration.public_key, sign_count: 0,
      external_id: SecureRandom.uuid, status_id: OperatorPasskeyStatus::ACTIVE,
    )
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    post(
      auth_org_verification_passkey_options_path(ri: "jp"),
      params: { "cf-turnstile-response" => "test" }, headers: @auth_headers,
    )

    assert_response :success
    options = response.parsed_body
    assertion = fake.get(challenge: options.fetch("options").fetch("challenge"), user_verified: true, sign_count: 1)
    post(
      auth_org_verification_passkey_path(ri: "jp"),
      params: { challenge_id: options.fetch("challenge_id"), credential: assertion }, headers: @auth_headers,
    )

    assert_response :success
    assert_equal 1, passkey.reload.sign_count
    assert_nil @token.reload.last_step_up_at
    assert_not OperatorVerification.active.exists?(staff_token_id: @token.id)
    assert_not OperatorChronicle.exists?(actor_id: @staff.id, event_id: OperatorChronicleEvent::STEP_UP_VERIFIED)
    get(auth_org_verification_handoff_path(ri: "jp"), headers: @auth_headers)

    assert_response :success
    form = response.parsed_body.at_css("form")
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    post(form["action"], params: fields, headers: @auth_headers)

    assert_response :see_other
    reference = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("result_ref")
    BaseAuthAdmissionCoordinator.validate_result_browser_binding!(
      transaction: issuance.transaction, surface: "org", base_browser_nonce: nonce, base_token: @token,
    )
    IdentityStepUpCeremonyFreshnessCommitter.call!(
      actor: @staff, token: @token, transaction: issuance.transaction.reload,
      requirement: requirement, result_reference: reference,
    )

    assert_not_nil @token.reload.last_step_up_at
    assert_predicate issuance.transaction.reload, :consumed?
    assert_predicate admitted.reload, :completed?
    assert_predicate StepUpResolver.call(token: @token, requirement: requirement), :satisfied?
    get(new_base_org_identity_passkey_url(ri: "jp", host: @base_host), headers: @base_headers)

    assert_response :success
    post(auth_org_verification_passkey_options_path(ri: "jp"), headers: @auth_headers)

    assert_response :bad_request
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
    service =
      if normalized.include?("acme")
        "ACME"
      elsif normalized.include?("core")
        "CORE"
      elsif normalized.include?("auth") || normalized.include?("sign") || normalized.include?("log.umaxica")
        "AUTH"
      else
        "BASE"
      end
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
class OrgStepUpVerificationEnforcerTest
  private
end
