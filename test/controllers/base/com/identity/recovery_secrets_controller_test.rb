# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Com::Identity::RecoverySecretsControllerTest < ActionDispatch::IntegrationTest
  fixtures :visitors

  setup do
    @host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! @host
    @visitor = visitors(:reserved_visitor)
    @headers =
      begin
        rp_headers = as_visitor_headers(@visitor, host: @host)
        rp_host = rp_headers["Host"]
        rp_route =
          begin
            Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
          rescue ActionController::RoutingError
            nil
          end
        rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
        if %w(base warp core edit).include?(rp_family) && rp_surface == "com"
          rp_client_id =
            case rp_family
            when "base" then "base-#{rp_surface}-ww"
            when "edit" then "edit-org"
            else "#{rp_family}-#{rp_surface}"
            end
          rp_token = VisitorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && VisitorRpSession.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
            rp_now = Time.current
            rp_session = VisitorRpSession.create!(
              visitor_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.actor_record, host: rp_host, resource_type: "visitor",
                                     session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                                     oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                     expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                     issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                     subject: OidcSubject.for(
                                       rp_token.actor_record,
                                       resource_type: "visitor",
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

  test "dedicated route reveals a valid passcode once with private response headers" do
    reveal = IdentityOneTimeReveal.issue!(
      actor: @visitor,
      session_nonce: @visitor.public_id,
      value: %w(first-passcode second-passcode),
      purpose: "visitor.recovery_secret_credential",
    )
    token = VisitorToken.find_by!(public_id: @headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
    token.update!(last_used_at: 10.minutes.ago)
    last_used_at = token.reload.last_used_at

    get base_com_identity_recovery_secret_url(token: reveal.token, ri: "jp", host: @host), headers: @headers

    assert_response :success
    page = response.parsed_body.at_css("script[data-page='app']")
    props = JSON.parse(page.text).fetch("props")

    assert_equal %w(first-passcode second-passcode), props.fetch("passcodes")
    cache_control = response.headers.fetch("Cache-Control")

    %w(no-store no-cache must-revalidate private).each do |directive|
      assert_includes cache_control, directive
    end
    assert_equal "no-cache", response.headers.fetch("Pragma")
    assert_equal "0", response.headers.fetch("Expires")
    assert_equal "no-referrer", response.headers.fetch("Referrer-Policy")
    assert_equal last_used_at, token.reload.last_used_at

    get base_com_identity_recovery_secret_url(token: reveal.token, ri: "jp", host: @host), headers: @headers

    assert_response :success
    page = response.parsed_body.at_css("script[data-page='app']")
    props = JSON.parse(page.text).fetch("props")

    assert_empty props.fetch("passcodes")
    assert_predicate props.fetch("missing_message"), :present?
    cache_control = response.headers.fetch("Cache-Control")

    %w(no-store no-cache must-revalidate private).each do |directive|
      assert_includes cache_control, directive
    end
    assert_equal "no-cache", response.headers.fetch("Pragma")
    assert_equal "0", response.headers.fetch("Expires")
    assert_equal "no-referrer", response.headers.fetch("Referrer-Policy")
    assert_equal last_used_at, token.reload.last_used_at
  end

  test "HEAD does not reveal or consume the one-time receipt" do
    reveal = IdentityOneTimeReveal.issue!(
      actor: @visitor,
      session_nonce: @visitor.public_id,
      value: ["head-protected-passcode"],
      purpose: "visitor.recovery_secret_credential",
    )
    path = base_com_identity_recovery_secret_path(token: reveal.token, ri: "jp")

    head path, headers: @headers

    assert_response :method_not_allowed
    assert_empty response.body

    get path, headers: @headers

    assert_response :success
    page = response.parsed_body.at_css("script[data-page='app']")

    assert_equal ["head-protected-passcode"], JSON.parse(page.text).fetch("props").fetch("passcodes")
  end

  test "OPTIONS does not reveal or consume the one-time receipt" do
    reveal = IdentityOneTimeReveal.issue!(
      actor: @visitor,
      session_nonce: @visitor.public_id,
      value: ["options-protected-passcode"],
      purpose: "visitor.recovery_secret_credential",
    )
    path = base_com_identity_recovery_secret_path(token: reveal.token, ri: "jp")

    options path, headers: @headers

    assert_response :not_found
    assert_not_includes response.body, "options-protected-passcode"

    get path, headers: @headers

    assert_response :success
    page = response.parsed_body.at_css("script[data-page='app']")

    assert_equal ["options-protected-passcode"], JSON.parse(page.text).fetch("props").fetch("passcodes")
  end

  test "a lost response does not make the consumed receipt available to a retry" do
    reveal = IdentityOneTimeReveal.issue!(
      actor: @visitor,
      session_nonce: @visitor.public_id,
      value: ["response-lost-passcode"],
      purpose: "visitor.recovery_secret_credential",
    )
    path = base_com_identity_recovery_secret_path(token: reveal.token, ri: "jp")
    request_headers = {
      "HTTP_AUTHORIZATION" => @headers.fetch("Authorization"),
      "HTTP_COOKIE" => @headers.fetch("Cookie"),
      "HTTP_X_TEST_CURRENT_RESOURCE" => @headers.fetch("X-TEST-CURRENT-RESOURCE"),
      "HTTP_X_TEST_SESSION_PUBLIC_ID" => @headers.fetch("X-TEST-SESSION-PUBLIC-ID"),
    }
    lost_response_app =
      lambda do |env|
        _status, _headers, body = Rails.application.call(env)
        body.close if body.respond_to?(:close)
        raise IOError, "simulated response loss after application completion"
      end

    assert_raises(IOError) do
      Rack::MockRequest.new(lost_response_app).get("https://#{@host}#{path}", request_headers)
    end

    get path, headers: @headers

    assert_response :success
    page = response.parsed_body.at_css("script[data-page='app']")
    props = JSON.parse(page.text).fetch("props")

    assert_empty props.fetch("passcodes")
    assert_predicate props.fetch("missing_message"), :present?
  end

  test "dedicated route renders missing state for a malformed token" do
    get base_com_identity_recovery_secret_url(token: "malformed", ri: "jp", host: @host), headers: @headers

    assert_response :success
    page = response.parsed_body.at_css("script[data-page='app']")
    props = JSON.parse(page.text).fetch("props")

    assert_empty props.fetch("passcodes")
    assert_predicate props.fetch("missing_message"), :present?
    cache_control = response.headers.fetch("Cache-Control")

    %w(no-store no-cache must-revalidate private).each do |directive|
      assert_includes cache_control, directive
    end
    assert_equal "no-cache", response.headers.fetch("Pragma")
    assert_equal "0", response.headers.fetch("Expires")
    assert_equal "no-referrer", response.headers.fetch("Referrer-Policy")
  end

  test "dedicated route renders missing state for an expired token" do
    reveal = IdentityOneTimeReveal.issue!(
      actor: @visitor,
      session_nonce: @visitor.public_id,
      value: "expired-passcode",
      purpose: "visitor.recovery_secret_credential",
      expires_in: 1.second,
    )

    travel 2.seconds do
      get base_com_identity_recovery_secret_url(token: reveal.token, ri: "jp", host: @host), headers: @headers
    end

    assert_response :success
    page = response.parsed_body.at_css("script[data-page='app']")
    props = JSON.parse(page.text).fetch("props")

    assert_empty props.fetch("passcodes")
    assert_predicate props.fetch("missing_message"), :present?
    cache_control = response.headers.fetch("Cache-Control")

    %w(no-store no-cache must-revalidate private).each do |directive|
      assert_includes cache_control, directive
    end
    assert_equal "no-cache", response.headers.fetch("Pragma")
    assert_equal "0", response.headers.fetch("Expires")
    assert_equal "no-referrer", response.headers.fetch("Referrer-Policy")
  end
end
