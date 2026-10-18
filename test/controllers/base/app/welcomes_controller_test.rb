# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Base::App::WelcomesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
  end

  test "welcome sequence redirects to the configured after welcome path" do
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)

    http_headers_0 =
      begin
        rp_headers = as_user_headers(@user, host: @host, session_public_id: @token.public_id)
        rp_host = rp_headers["Host"]
        rp_route =
          begin
            Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
          rescue ActionController::RoutingError
            nil
          end
        rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
        if %w(base warp core edit).include?(rp_family) && rp_surface == "app"
          rp_client_id =
            case rp_family
            when "base" then "base-#{rp_surface}-ww"
            when "edit" then "edit-org-ww"
            when "tech" then "tech-org-ww"
            else "#{rp_family}-#{rp_surface}-jp"
            end
          rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && OpAppGrant.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
            rp_now = Time.current
            rp_session = OpAppGrant.create!(
              client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.actor_record, host: rp_host, resource_type: "client",
                                     session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                                     oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                     expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                     issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                     subject: OidcSubject.for(
                                       rp_token.actor_record,
                                       resource_type: "client",
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
    get base_app_welcome_url(ri: "jp", host: @host),
        headers: http_headers_0

    assert_redirected_to base_app_dashboard_path(ri: "jp")
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
end

# The self-RP Welcome page is reachable only after the root sign-in completed. Its one-shot gate
# decides whether the page renders, and "Next" returns to the page the browser was heading to only
# when a path-target token issued by this browser session's own sign-in for this surface says so.
class Base::App::WelcomeReturnTargetControllerTest < ActionController::TestCase
  tests Base::App::WelcomesController

  DASHBOARD = "/dashboard?ri=jp"
  SESSION_NONCE = "welcome-return-target-nonce"

  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)
    @request.host = @host
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
    end.each do |pair|
      name, value = pair.split("=", 2)
      @request.cookies[name] = Rack::Utils.unescape(value)
    end
    @request.session[:app_sign_in_welcome] = {
      "remaining" => 5,
      "issued_at" => Time.current.to_i,
      "expires_at" => 10.minutes.from_now.to_i,
      "sequence_id" => nil,
    }
    @request.session[:authentication_pt_nonce] = SESSION_NONCE
    @request.headers["X-Inertia"] = "true"
    @request.headers["X-Inertia-Version"] = InertiaRails.configuration.version
  end

  test "Next returns to the verified pre-sign-in page" do
    get :show, params: { ri: "jp",
                         pt: begin
                           fv5046 = "/identity?ri=jp"
                           fv5048 = "app"
                           fv5049 = "authentication"
                           fv5047 = SESSION_NONCE
                           fv5045 = 5.minutes
                           ActiveSupport::MessageVerifier.new(
                             Rails.application.key_generator.generate_key(
                               AuthenticationRedirects::PATH_TARGET_TOKEN_SALT,
                               32,
                             ),
                             digest: "SHA256", serializer: JSON, url_safe: true,
                           ).generate(
                             {
                               "flow" => fv5049,
                               "surface" => fv5048,
                               "session_nonce" => fv5047,
                               "pt" => fv5046,
                             },
                             purpose: AuthenticationRedirects::PATH_TARGET_TOKEN_PURPOSE,
                             expires_in: fv5045,
                           )
                         end, }

    assert_response :success
    assert_equal "/identity?ri=jp", begin
      response.parsed_body.dig("props", "next_link", "href")
    end
  end

  test "Next goes to the Dashboard when no return target was carried" do
    get :show, params: { ri: "jp" }

    assert_response :success
    assert_equal DASHBOARD, begin
      response.parsed_body.dig("props", "next_link", "href")
    end
  end

  test "a tampered return target is ignored" do
    token =
      begin
        fv5041 = "/identity?ri=jp"
        fv5043 = "app"
        fv5044 = "authentication"
        fv5042 = SESSION_NONCE
        fv5040 = 5.minutes
        ActiveSupport::MessageVerifier.new(
          Rails.application.key_generator.generate_key(AuthenticationRedirects::PATH_TARGET_TOKEN_SALT, 32),
          digest: "SHA256", serializer: JSON, url_safe: true,
        ).generate(
          {
            "flow" => fv5044,
            "surface" => fv5043,
            "session_nonce" => fv5042,
            "pt" => fv5041,
          },
          purpose: AuthenticationRedirects::PATH_TARGET_TOKEN_PURPOSE, expires_in: fv5040,
        )
      end

    get :show, params: { ri: "jp", pt: "#{token[0...-2]}xx" }

    assert_equal DASHBOARD, begin
      response.parsed_body.dig("props", "next_link", "href")
    end
  end

  test "a return target issued for another surface is ignored" do
    get :show, params: { ri: "jp",
                         pt: begin
                           fv5036 = "/identity?ri=jp"
                           fv5038 = "com"
                           fv5039 = "authentication"
                           fv5037 = SESSION_NONCE
                           fv5035 = 5.minutes
                           ActiveSupport::MessageVerifier.new(
                             Rails.application.key_generator.generate_key(
                               AuthenticationRedirects::PATH_TARGET_TOKEN_SALT,
                               32,
                             ),
                             digest: "SHA256", serializer: JSON, url_safe: true,
                           ).generate(
                             {
                               "flow" => fv5039,
                               "surface" => fv5038,
                               "session_nonce" => fv5037,
                               "pt" => fv5036,
                             },
                             purpose: AuthenticationRedirects::PATH_TARGET_TOKEN_PURPOSE,
                             expires_in: fv5035,
                           )
                         end, }

    assert_equal DASHBOARD, begin
      response.parsed_body.dig("props", "next_link", "href")
    end
  end

  test "a return target issued for another flow is ignored" do
    get :show, params: { ri: "jp",
                         pt: begin
                           fv5031 = "/identity?ri=jp"
                           fv5033 = "app"
                           fv5034 = "step_up"
                           fv5032 = SESSION_NONCE
                           fv5030 = 5.minutes
                           ActiveSupport::MessageVerifier.new(
                             Rails.application.key_generator.generate_key(
                               AuthenticationRedirects::PATH_TARGET_TOKEN_SALT,
                               32,
                             ),
                             digest: "SHA256", serializer: JSON, url_safe: true,
                           ).generate(
                             {
                               "flow" => fv5034,
                               "surface" => fv5033,
                               "session_nonce" => fv5032,
                               "pt" => fv5031,
                             },
                             purpose: AuthenticationRedirects::PATH_TARGET_TOKEN_PURPOSE,
                             expires_in: fv5030,
                           )
                         end, }

    assert_equal DASHBOARD, begin
      response.parsed_body.dig("props", "next_link", "href")
    end
  end

  test "a return target bound to another browser session is ignored" do
    get :show, params: { ri: "jp",
                         pt: begin
                           fv5026 = "/identity?ri=jp"
                           fv5028 = "app"
                           fv5029 = "authentication"
                           fv5027 = "another-browser"
                           fv5025 = 5.minutes
                           ActiveSupport::MessageVerifier.new(
                             Rails.application.key_generator.generate_key(
                               AuthenticationRedirects::PATH_TARGET_TOKEN_SALT,
                               32,
                             ),
                             digest: "SHA256", serializer: JSON, url_safe: true,
                           ).generate(
                             {
                               "flow" => fv5029,
                               "surface" => fv5028,
                               "session_nonce" => fv5027,
                               "pt" => fv5026,
                             },
                             purpose: AuthenticationRedirects::PATH_TARGET_TOKEN_PURPOSE,
                             expires_in: fv5025,
                           )
                         end, }

    assert_equal DASHBOARD, begin
      response.parsed_body.dig("props", "next_link", "href")
    end
  end

  test "a return target is ignored when this browser session carries no nonce" do
    token =
      begin
        fv5021 = "/identity?ri=jp"
        fv5023 = "app"
        fv5024 = "authentication"
        fv5022 = SESSION_NONCE
        fv5020 = 5.minutes
        ActiveSupport::MessageVerifier.new(
          Rails.application.key_generator.generate_key(AuthenticationRedirects::PATH_TARGET_TOKEN_SALT, 32),
          digest: "SHA256", serializer: JSON, url_safe: true,
        ).generate(
          {
            "flow" => fv5024,
            "surface" => fv5023,
            "session_nonce" => fv5022,
            "pt" => fv5021,
          },
          purpose: AuthenticationRedirects::PATH_TARGET_TOKEN_PURPOSE, expires_in: fv5020,
        )
      end
    @request.session.delete(:authentication_pt_nonce)

    get :show, params: { ri: "jp", pt: token }

    assert_equal DASHBOARD, begin
      response.parsed_body.dig("props", "next_link", "href")
    end
  end

  # MessageVerifier accepts a token strictly before its expiry instant.
  [[-1, "/identity?ri=jp"], [0, DASHBOARD], [1, DASHBOARD]].each do |offset, expected|
    test "a return target #{offset} second(s) from its expiry resolves to #{expected}" do
      freeze_time
      token =
        begin
          fv5016 = "/identity?ri=jp"
          fv5018 = "app"
          fv5019 = "authentication"
          fv5017 = SESSION_NONCE
          fv5015 = 60.seconds
          ActiveSupport::MessageVerifier.new(
            Rails.application.key_generator.generate_key(AuthenticationRedirects::PATH_TARGET_TOKEN_SALT, 32),
            digest: "SHA256", serializer: JSON, url_safe: true,
          ).generate(
            {
              "flow" => fv5019,
              "surface" => fv5018,
              "session_nonce" => fv5017,
              "pt" => fv5016,
            },
            purpose: AuthenticationRedirects::PATH_TARGET_TOKEN_PURPOSE, expires_in: fv5015,
          )
        end
      travel 60.seconds + offset.seconds

      get :show, params: { ri: "jp", pt: token }

      assert_equal expected, begin
        response.parsed_body.dig("props", "next_link", "href")
      end
    end
  end

  ["/welcome?ri=jp", "/sign?ri=jp", "/sign/out?ri=jp"].each do |destination|
    test "a return target of #{destination} cannot make Next loop" do
      get :show, params: { ri: "jp",
                           pt: begin
                             fv5011 = destination
                             fv5013 = "app"
                             fv5014 = "authentication"
                             fv5012 = SESSION_NONCE
                             fv5010 = 5.minutes
                             ActiveSupport::MessageVerifier.new(
                               Rails.application.key_generator.generate_key(
                                 AuthenticationRedirects::PATH_TARGET_TOKEN_SALT,
                                 32,
                               ),
                               digest: "SHA256", serializer: JSON, url_safe: true,
                             ).generate(
                               {
                                 "flow" => fv5014,
                                 "surface" => fv5013,
                                 "session_nonce" => fv5012,
                                 "pt" => fv5011,
                               },
                               purpose: AuthenticationRedirects::PATH_TARGET_TOKEN_PURPOSE,
                               expires_in: fv5010,
                             )
                           end, }

      assert_equal DASHBOARD, begin
        response.parsed_body.dig("props", "next_link", "href")
      end
    end
  end

  ["https://evil.example/", "//evil.example/x", "/\\evil.example", "", " ", "/a\u0000b"].each do |destination|
    test "a signed return target of #{destination.inspect} is not an internal path" do
      get :show, params: { ri: "jp",
                           pt: begin
                             fv5006 = destination
                             fv5008 = "app"
                             fv5009 = "authentication"
                             fv5007 = SESSION_NONCE
                             fv5005 = 5.minutes
                             ActiveSupport::MessageVerifier.new(
                               Rails.application.key_generator.generate_key(
                                 AuthenticationRedirects::PATH_TARGET_TOKEN_SALT,
                                 32,
                               ),
                               digest: "SHA256", serializer: JSON, url_safe: true,
                             ).generate(
                               {
                                 "flow" => fv5009,
                                 "surface" => fv5008,
                                 "session_nonce" => fv5007,
                                 "pt" => fv5006,
                               },
                               purpose: AuthenticationRedirects::PATH_TARGET_TOKEN_PURPOSE,
                               expires_in: fv5005,
                             )
                           end, }

      assert_equal DASHBOARD, begin
        response.parsed_body.dig("props", "next_link", "href")
      end
    end
  end

  [nil, "", " ", "0", %w(a b), { "k" => "v" }].each do |value|
    test "a return target parameter of #{value.inspect} falls back to the Dashboard" do
      get :show, params: { ri: "jp", pt: value }

      assert_response :success
      assert_equal DASHBOARD, begin
        response.parsed_body.dig("props", "next_link", "href")
      end
    end
  end

  test "without the gate the page is skipped and no return target is followed" do
    @request.session.delete(:app_sign_in_welcome)

    get :show, params: { ri: "jp",
                         pt: begin
                           fv5001 = "/identity?ri=jp"
                           fv5003 = "app"
                           fv5004 = "authentication"
                           fv5002 = SESSION_NONCE
                           fv5000 = 5.minutes
                           ActiveSupport::MessageVerifier.new(
                             Rails.application.key_generator.generate_key(
                               AuthenticationRedirects::PATH_TARGET_TOKEN_SALT,
                               32,
                             ),
                             digest: "SHA256", serializer: JSON, url_safe: true,
                           ).generate(
                             {
                               "flow" => fv5004,
                               "surface" => fv5003,
                               "session_nonce" => fv5002,
                               "pt" => fv5001,
                             },
                             purpose: AuthenticationRedirects::PATH_TARGET_TOKEN_PURPOSE,
                             expires_in: fv5000,
                           )
                         end, }

    assert_redirected_to "/dashboard?ri=jp"
  end

  test "the gate is spent one use at a time and never extended" do
    get :show, params: { ri: "jp" }

    assert_equal 4, session[:app_sign_in_welcome]["remaining"]
  end

  private
end

# DAMP auth header helpers for this test class.
class Base::App::WelcomesControllerTest
  private
end

# DAMP: authenticated header helpers that attach a real JWT access cookie so the
# Base RP authentication pipeline recognizes the logged-in session instead of
# redirecting to /oauth/authorize. This final reopening overrides any earlier
# helper definitions in this file so every "logged in" request carries a valid
# access token cookie for the correct actor and surface.
class Base::App::WelcomesControllerTest
  private

  def set_access_cookie(token)
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = token
  end

  # Derive the issuer id from the test host. Base RP hosts (www.umaxica.app/.org/.com)
  # must resolve to surface:BASE_* so the access token issuer matches the surface the
  # controller validates against.
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

  def ensure_user_token_reference_records!
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::ACTIVE)
    ClientTokenBindingMethod.find_or_create_by!(id: ClientTokenBindingMethod::LEGACY)
    ClientTokenDbscStatus.find_or_create_by!(id: ClientTokenDbscStatus::NOTHING)
  end

  def ensure_staff_token_reference_records!
    OperatorTokenKind.find_or_create_by!(id: OperatorTokenKind::BROWSER_WEB)
    OperatorTokenStatus.find_or_create_by!(id: OperatorTokenStatus::ACTIVE)
    OperatorTokenBindingMethod.find_or_create_by!(id: OperatorTokenBindingMethod::LEGACY)
    OperatorTokenDbscStatus.find_or_create_by!(id: OperatorTokenDbscStatus::NOTHING)
  end

  def ensure_visitor_token_reference_records!
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::LEGACY)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
  end
end
