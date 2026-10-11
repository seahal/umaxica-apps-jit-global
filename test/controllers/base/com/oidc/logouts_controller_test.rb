# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
# require "helpers/auth_helpers"

class Base::Com::Oidc::LogoutsControllerTest < ActionDispatch::IntegrationTest
  # include AuthHelpers

  setup do
    @host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    @client = OidcClientRegistry.find!("core-com")
    @visitor = visitors(:reserved_visitor)
    @token = VisitorToken.create!(
      visitor: @visitor,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
    )
    @session_public_id = @token.public_id
    # Cookies only reach the request when the integration session's host matches it.
    host! @host
    https!
    # The staged logout confirmation redirects through the jump gateway, which needs signing keys.
    load_jump_rt_env!
  end

  test "routes get and post to oidc logout without changing helper" do
    get_route = Rails.application.routes.recognize_path("https://#{@host}/oidc/logout", method: :get)
    post_route = Rails.application.routes.recognize_path("https://#{@host}/oidc/logout", method: :post)

    assert_equal "base/com/oidc/logouts", get_route[:controller]
    assert_equal "show", get_route[:action]
    assert_equal "base/com/oidc/logouts", post_route[:controller]
    assert_equal "create", post_route[:action]
    assert_equal "/oidc/logout", base_com_oidc_logout_path
  end

  test "get without params renders confirmation without mutation" do
    auth_refresh_token = @token.rotate_refresh_token!
    auth_refresh_digest = @token.reload.refresh_token_digest
    auth_refresh_generation = @token.refresh_token_generation
    cookies.delete(AuthenticationBase::ACCESS_COOKIE_KEY)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = auth_refresh_token

    http_headers_7 =
      begin
        fx0_harness =
          begin
            f0_headers = as_visitor_headers(@visitor, host: @host, session_public_id: @session_public_id)
            f0_host = f0_headers["Host"]
            f0_route =
              begin
                Rails.application.routes.recognize_path("https://#{f0_host}/") if f0_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f0_family, f0_surface = f0_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f0_family) && f0_surface == "com"
              f0_client_id =
                case f0_family
                when "base" then "base-#{f0_surface}-ww"
                when "edit" then "edit-org"
                else "#{f0_family}-#{f0_surface}"
                end
              f0_token = VisitorToken.find_by!(public_id: f0_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f0_client = OidcClientRegistry.find!(f0_client_id)
              f0_key = [f0_client.client_id, f0_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f0_key] && f0_token.currently_usable? &&
                  !(f0_token.device_session_id && VisitorRpSession.exists?(
                    device_session_id: f0_token.device_session_id,
                    oidc_client_id: f0_client.client_id,
                    revoked_at: nil,
                  ))
                f0_token.rotate_refresh_token! unless f0_token.device_session.current_refresh_token_id
                f0_now = Time.current
                f0_session = VisitorRpSession.create!(
                  visitor_token: f0_token, oidc_client_id: f0_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f0_now,
                  refresh_token_expires_at: f0_now + 10.minutes,
                )
                f0_access = AuthenticationTokenService.encode(
                  f0_token.visitor, host: f0_host, resource_type: "visitor",
                                    session_public_id: f0_token.public_id, base_session_public_id: f0_token.public_id,
                                    oidc_sid: f0_session.public_id, oidc_jti: f0_session.oidc_jti,
                                    expires_at: f0_now + 10.minutes, scopes: %w(openid profile),
                                    issuer: OidcIssuer.for_client(f0_client), audiences: [f0_client.aud],
                                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f0_client),
                                    subject: OidcSubject.for(
                                      f0_token.visitor,
                                      resource_type: "visitor",
                                    ), client_id: f0_client.client_id,
                )
                @base_browser_rp_credentials[f0_key] = [f0_access, f0_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f0_key]
                f0_access, f0_refresh = @base_browser_rp_credentials.fetch(f0_key)
                f0_cookie = [
                  f0_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f0_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f0_refresh)}",
                ].join("; ")
                f0_headers = f0_headers.merge(
                  "Cookie" => f0_cookie,
                  "HTTP_COOKIE" => f0_cookie,
                )
              end
            end
            f0_headers
          end
        fx0_harness.fetch("Cookie").split("; ").each do |pair|
          name, value = pair.split("=", 2)
          cookies[name] = Rack::Utils.unescape(value)
        end
        browser_headers.merge(fx0_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
      end
    get base_com_oidc_logout_url(host: @host), params: { ri: "jp" }, headers: http_headers_7

    assert_response :ok
    assert_not_predicate @token.reload, :revoked?
    assert_equal auth_refresh_digest, @token.refresh_token_digest
    assert_equal auth_refresh_generation, @token.refresh_token_generation
    assert_nil response.location
  end

  test "post without params does not rotate the authentication refresh token" do
    auth_refresh_token = @token.rotate_refresh_token!
    auth_refresh_digest = @token.reload.refresh_token_digest
    auth_refresh_generation = @token.refresh_token_generation
    cookies.delete(AuthenticationBase::ACCESS_COOKIE_KEY)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = auth_refresh_token

    http_headers_6 =
      begin
        fx1_harness =
          begin
            f1_headers = as_visitor_headers(@visitor, host: @host, session_public_id: @session_public_id)
            f1_host = f1_headers["Host"]
            f1_route =
              begin
                Rails.application.routes.recognize_path("https://#{f1_host}/") if f1_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f1_family, f1_surface = f1_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f1_family) && f1_surface == "com"
              f1_client_id =
                case f1_family
                when "base" then "base-#{f1_surface}-ww"
                when "edit" then "edit-org"
                else "#{f1_family}-#{f1_surface}"
                end
              f1_token = VisitorToken.find_by!(public_id: f1_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f1_client = OidcClientRegistry.find!(f1_client_id)
              f1_key = [f1_client.client_id, f1_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f1_key] && f1_token.currently_usable? &&
                  !(f1_token.device_session_id && VisitorRpSession.exists?(
                    device_session_id: f1_token.device_session_id,
                    oidc_client_id: f1_client.client_id,
                    revoked_at: nil,
                  ))
                f1_token.rotate_refresh_token! unless f1_token.device_session.current_refresh_token_id
                f1_now = Time.current
                f1_session = VisitorRpSession.create!(
                  visitor_token: f1_token, oidc_client_id: f1_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f1_now,
                  refresh_token_expires_at: f1_now + 10.minutes,
                )
                f1_access = AuthenticationTokenService.encode(
                  f1_token.visitor, host: f1_host, resource_type: "visitor",
                                    session_public_id: f1_token.public_id, base_session_public_id: f1_token.public_id,
                                    oidc_sid: f1_session.public_id, oidc_jti: f1_session.oidc_jti,
                                    expires_at: f1_now + 10.minutes, scopes: %w(openid profile),
                                    issuer: OidcIssuer.for_client(f1_client), audiences: [f1_client.aud],
                                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f1_client),
                                    subject: OidcSubject.for(
                                      f1_token.visitor,
                                      resource_type: "visitor",
                                    ), client_id: f1_client.client_id,
                )
                @base_browser_rp_credentials[f1_key] = [f1_access, f1_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f1_key]
                f1_access, f1_refresh = @base_browser_rp_credentials.fetch(f1_key)
                f1_cookie = [
                  f1_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f1_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f1_refresh)}",
                ].join("; ")
                f1_headers = f1_headers.merge(
                  "Cookie" => f1_cookie,
                  "HTTP_COOKIE" => f1_cookie,
                )
              end
            end
            f1_headers
          end
        fx1_harness.fetch("Cookie").split("; ").each do |pair|
          name, value = pair.split("=", 2)
          cookies[name] = Rack::Utils.unescape(value)
        end
        browser_headers.merge(fx1_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
      end
    post base_com_oidc_logout_url(host: @host), headers: http_headers_6

    assert_response :ok
    assert_equal auth_refresh_digest, @token.reload.refresh_token_digest
    assert_equal auth_refresh_generation, @token.refresh_token_generation
  end

  test "validated logout request is staged through shared confirmation" do
    redirect_uri = @client.post_logout_redirect_uris.first

    http_headers_5 =
      begin
        fx2_harness =
          begin
            f2_headers = as_visitor_headers(@visitor, host: @host, session_public_id: @session_public_id)
            f2_host = f2_headers["Host"]
            f2_route =
              begin
                Rails.application.routes.recognize_path("https://#{f2_host}/") if f2_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f2_family, f2_surface = f2_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f2_family) && f2_surface == "com"
              f2_client_id =
                case f2_family
                when "base" then "base-#{f2_surface}-ww"
                when "edit" then "edit-org"
                else "#{f2_family}-#{f2_surface}"
                end
              f2_token = VisitorToken.find_by!(public_id: f2_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f2_client = OidcClientRegistry.find!(f2_client_id)
              f2_key = [f2_client.client_id, f2_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f2_key] && f2_token.currently_usable? &&
                  !(f2_token.device_session_id && VisitorRpSession.exists?(
                    device_session_id: f2_token.device_session_id,
                    oidc_client_id: f2_client.client_id,
                    revoked_at: nil,
                  ))
                f2_token.rotate_refresh_token! unless f2_token.device_session.current_refresh_token_id
                f2_now = Time.current
                f2_session = VisitorRpSession.create!(
                  visitor_token: f2_token, oidc_client_id: f2_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f2_now,
                  refresh_token_expires_at: f2_now + 10.minutes,
                )
                f2_access = AuthenticationTokenService.encode(
                  f2_token.visitor, host: f2_host, resource_type: "visitor",
                                    session_public_id: f2_token.public_id, base_session_public_id: f2_token.public_id,
                                    oidc_sid: f2_session.public_id, oidc_jti: f2_session.oidc_jti,
                                    expires_at: f2_now + 10.minutes, scopes: %w(openid profile),
                                    issuer: OidcIssuer.for_client(f2_client), audiences: [f2_client.aud],
                                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f2_client),
                                    subject: OidcSubject.for(
                                      f2_token.visitor,
                                      resource_type: "visitor",
                                    ), client_id: f2_client.client_id,
                )
                @base_browser_rp_credentials[f2_key] =
                  [f2_access, f2_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f2_key]
                f2_access, f2_refresh = @base_browser_rp_credentials.fetch(f2_key)
                f2_cookie = [
                  f2_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f2_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f2_refresh)}",
                ].join("; ")
                f2_headers = f2_headers.merge(
                  "Cookie" => f2_cookie,
                  "HTTP_COOKIE" => f2_cookie,
                )
              end
            end
            f2_headers
          end
        fx2_harness.fetch("Cookie").split("; ").each do |pair|
          name, value = pair.split("=", 2)
          cookies[name] = Rack::Utils.unescape(value)
        end
        browser_headers.merge(fx2_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
      end
    get base_com_oidc_logout_url(host: @host),
        params: { id_token_hint: id_token, post_logout_redirect_uri: redirect_uri, state: "xyz", ri: "jp" },
        headers: http_headers_5

    assert_response :see_other
    location = URI.parse(jump_rt_url_from_location(response.location))

    assert_equal "/sign/out/edit", location.path

    follow_redirect!

    assert_response :ok

    http_headers_4 =
      begin
        fx3_harness =
          begin
            f3_headers = as_visitor_headers(@visitor, host: @host, session_public_id: @session_public_id)
            f3_host = f3_headers["Host"]
            f3_route =
              begin
                Rails.application.routes.recognize_path("https://#{f3_host}/") if f3_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f3_family, f3_surface = f3_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f3_family) && f3_surface == "com"
              f3_client_id =
                case f3_family
                when "base" then "base-#{f3_surface}-ww"
                when "edit" then "edit-org"
                else "#{f3_family}-#{f3_surface}"
                end
              f3_token = VisitorToken.find_by!(public_id: f3_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f3_client = OidcClientRegistry.find!(f3_client_id)
              f3_key = [f3_client.client_id, f3_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f3_key] && f3_token.currently_usable? &&
                  !(f3_token.device_session_id && VisitorRpSession.exists?(
                    device_session_id: f3_token.device_session_id,
                    oidc_client_id: f3_client.client_id,
                    revoked_at: nil,
                  ))
                f3_token.rotate_refresh_token! unless f3_token.device_session.current_refresh_token_id
                f3_now = Time.current
                f3_session = VisitorRpSession.create!(
                  visitor_token: f3_token, oidc_client_id: f3_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f3_now,
                  refresh_token_expires_at: f3_now + 10.minutes,
                )
                f3_access = AuthenticationTokenService.encode(
                  f3_token.visitor, host: f3_host, resource_type: "visitor",
                                    session_public_id: f3_token.public_id, base_session_public_id: f3_token.public_id,
                                    oidc_sid: f3_session.public_id, oidc_jti: f3_session.oidc_jti,
                                    expires_at: f3_now + 10.minutes, scopes: %w(openid profile),
                                    issuer: OidcIssuer.for_client(f3_client), audiences: [f3_client.aud],
                                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f3_client),
                                    subject: OidcSubject.for(
                                      f3_token.visitor,
                                      resource_type: "visitor",
                                    ), client_id: f3_client.client_id,
                )
                @base_browser_rp_credentials[f3_key] = [f3_access, f3_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f3_key]
                f3_access, f3_refresh = @base_browser_rp_credentials.fetch(f3_key)
                f3_cookie = [
                  f3_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f3_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f3_refresh)}",
                ].join("; ")
                f3_headers = f3_headers.merge(
                  "Cookie" => f3_cookie,
                  "HTTP_COOKIE" => f3_cookie,
                )
              end
            end
            f3_headers
          end
        fx3_harness.fetch("Cookie").split("; ").each do |pair|
          name, value = pair.split("=", 2)
          cookies[name] = Rack::Utils.unescape(value)
        end
        browser_headers.merge(fx3_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
      end
    post base_com_oidc_logout_url(host: @host), headers: http_headers_4

    assert_response :see_other
    assert_predicate @token.reload, :revoked?

    location = URI.parse(jump_rt_url_from_location(response.location))
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal URI.parse(redirect_uri).host, location.host
    assert_equal URI.parse(redirect_uri).path, location.path
    assert_equal "xyz", query["state"]
  end

  test "invalid post_logout_redirect_uri never redirects externally" do
    http_headers_3 =
      begin
        fx4_harness =
          begin
            f4_headers = as_visitor_headers(@visitor, host: @host, session_public_id: @session_public_id)
            f4_host = f4_headers["Host"]
            f4_route =
              begin
                Rails.application.routes.recognize_path("https://#{f4_host}/") if f4_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f4_family, f4_surface = f4_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f4_family) && f4_surface == "com"
              f4_client_id =
                case f4_family
                when "base" then "base-#{f4_surface}-ww"
                when "edit" then "edit-org"
                else "#{f4_family}-#{f4_surface}"
                end
              f4_token = VisitorToken.find_by!(public_id: f4_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f4_client = OidcClientRegistry.find!(f4_client_id)
              f4_key = [f4_client.client_id, f4_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f4_key] && f4_token.currently_usable? &&
                  !(f4_token.device_session_id && VisitorRpSession.exists?(
                    device_session_id: f4_token.device_session_id,
                    oidc_client_id: f4_client.client_id,
                    revoked_at: nil,
                  ))
                f4_token.rotate_refresh_token! unless f4_token.device_session.current_refresh_token_id
                f4_now = Time.current
                f4_session = VisitorRpSession.create!(
                  visitor_token: f4_token, oidc_client_id: f4_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f4_now,
                  refresh_token_expires_at: f4_now + 10.minutes,
                )
                f4_access = AuthenticationTokenService.encode(
                  f4_token.visitor,
                  host: f4_host,
                  resource_type: "visitor",
                  session_public_id: f4_token.public_id,
                  base_session_public_id: f4_token.public_id,
                  oidc_sid: f4_session.public_id,
                  oidc_jti: f4_session.oidc_jti,
                  expires_at: f4_now + 10.minutes,
                  scopes: %w(openid profile),
                  issuer: OidcIssuer.for_client(f4_client),
                  audiences: [f4_client.aud],
                  jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f4_client),
                  subject: OidcSubject.for(
                    f4_token.visitor,
                    resource_type: "visitor",
                  ),
                  client_id: f4_client.client_id,
                )
                @base_browser_rp_credentials[f4_key] =
                  [f4_access, f4_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f4_key]
                f4_access, f4_refresh = @base_browser_rp_credentials.fetch(f4_key)
                f4_cookie = [
                  f4_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f4_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f4_refresh)}",
                ].join("; ")
                f4_headers = f4_headers.merge(
                  "Cookie" => f4_cookie,
                  "HTTP_COOKIE" => f4_cookie,
                )
              end
            end
            f4_headers
          end
        fx4_harness.fetch("Cookie").split("; ").each do |pair|
          name, value = pair.split("=", 2)
          cookies[name] = Rack::Utils.unescape(value)
        end
        browser_headers.merge(fx4_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
      end
    post base_com_oidc_logout_url(host: @host),
         params: {
           id_token_hint: id_token,
           post_logout_redirect_uri: "https://attacker.example/signed-out",
           state: "xyz",
           ri: "jp",
         },
         headers: http_headers_3

    assert_response :success
    assert_not_predicate @token.reload, :revoked?
    assert_nil response.location
    assert_not_includes inertia_props.to_json, "xyz"
  end

  test "post_logout_redirect_uri registered for another realm never redirects externally" do
    cross_realm_uri = OidcClientRegistry.find!("core-app").post_logout_redirect_uris.first

    assert_not_nil cross_realm_uri, "core-app should register an app-realm post_logout uri"

    http_headers_2 =
      begin
        fx5_harness =
          begin
            f5_headers = as_visitor_headers(@visitor, host: @host, session_public_id: @session_public_id)
            f5_host = f5_headers["Host"]
            f5_route =
              begin
                Rails.application.routes.recognize_path("https://#{f5_host}/") if f5_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f5_family, f5_surface = f5_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f5_family) && f5_surface == "com"
              f5_client_id =
                case f5_family
                when "base" then "base-#{f5_surface}-ww"
                when "edit" then "edit-org"
                else "#{f5_family}-#{f5_surface}"
                end
              f5_token = VisitorToken.find_by!(public_id: f5_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f5_client = OidcClientRegistry.find!(f5_client_id)
              f5_key = [f5_client.client_id, f5_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f5_key] && f5_token.currently_usable? &&
                  !(f5_token.device_session_id && VisitorRpSession.exists?(
                    device_session_id: f5_token.device_session_id,
                    oidc_client_id: f5_client.client_id,
                    revoked_at: nil,
                  ))
                f5_token.rotate_refresh_token! unless f5_token.device_session.current_refresh_token_id
                f5_now = Time.current
                f5_session = VisitorRpSession.create!(
                  visitor_token: f5_token, oidc_client_id: f5_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f5_now,
                  refresh_token_expires_at: f5_now + 10.minutes,
                )
                f5_access = AuthenticationTokenService.encode(
                  f5_token.visitor,
                  host: f5_host,
                  resource_type: "visitor",
                  session_public_id: f5_token.public_id,
                  base_session_public_id: f5_token.public_id,
                  oidc_sid: f5_session.public_id,
                  oidc_jti: f5_session.oidc_jti,
                  expires_at: f5_now + 10.minutes,
                  scopes: %w(openid profile),
                  issuer: OidcIssuer.for_client(f5_client),
                  audiences: [f5_client.aud],
                  jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f5_client),
                  subject: OidcSubject.for(
                    f5_token.visitor,
                    resource_type: "visitor",
                  ),
                  client_id: f5_client.client_id,
                )
                @base_browser_rp_credentials[f5_key] =
                  [f5_access, f5_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f5_key]
                f5_access, f5_refresh = @base_browser_rp_credentials.fetch(f5_key)
                f5_cookie = [
                  f5_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f5_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f5_refresh)}",
                ].join("; ")
                f5_headers = f5_headers.merge(
                  "Cookie" => f5_cookie,
                  "HTTP_COOKIE" => f5_cookie,
                )
              end
            end
            f5_headers
          end
        fx5_harness.fetch("Cookie").split("; ").each do |pair|
          name, value = pair.split("=", 2)
          cookies[name] = Rack::Utils.unescape(value)
        end
        browser_headers.merge(fx5_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
      end
    post base_com_oidc_logout_url(host: @host),
         params: { id_token_hint: id_token, post_logout_redirect_uri: cross_realm_uri, state: "xyz", ri: "jp" },
         headers: http_headers_2

    assert_response :success
    assert_not_predicate @token.reload, :revoked?
    assert_nil response.location
    assert_not_includes response.body, "xyz"
  end

  test "logout_challenge for an unknown transaction is rejected as not found" do
    http_headers_1 =
      begin
        fx6_harness =
          begin
            f6_headers = as_visitor_headers(@visitor, host: @host, session_public_id: @session_public_id)
            f6_host = f6_headers["Host"]
            f6_route =
              begin
                Rails.application.routes.recognize_path("https://#{f6_host}/") if f6_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f6_family, f6_surface = f6_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f6_family) && f6_surface == "com"
              f6_client_id =
                case f6_family
                when "base" then "base-#{f6_surface}-ww"
                when "edit" then "edit-org"
                else "#{f6_family}-#{f6_surface}"
                end
              f6_token = VisitorToken.find_by!(public_id: f6_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f6_client = OidcClientRegistry.find!(f6_client_id)
              f6_key = [f6_client.client_id, f6_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f6_key] && f6_token.currently_usable? &&
                  !(f6_token.device_session_id && VisitorRpSession.exists?(
                    device_session_id: f6_token.device_session_id,
                    oidc_client_id: f6_client.client_id,
                    revoked_at: nil,
                  ))
                f6_token.rotate_refresh_token! unless f6_token.device_session.current_refresh_token_id
                f6_now = Time.current
                f6_session = VisitorRpSession.create!(
                  visitor_token: f6_token, oidc_client_id: f6_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f6_now,
                  refresh_token_expires_at: f6_now + 10.minutes,
                )
                f6_access = AuthenticationTokenService.encode(
                  f6_token.visitor, host: f6_host, resource_type: "visitor",
                                    session_public_id: f6_token.public_id, base_session_public_id: f6_token.public_id,
                                    oidc_sid: f6_session.public_id, oidc_jti: f6_session.oidc_jti,
                                    expires_at: f6_now + 10.minutes, scopes: %w(openid profile),
                                    issuer: OidcIssuer.for_client(f6_client), audiences: [f6_client.aud],
                                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f6_client),
                                    subject: OidcSubject.for(
                                      f6_token.visitor,
                                      resource_type: "visitor",
                                    ), client_id: f6_client.client_id,
                )
                @base_browser_rp_credentials[f6_key] =
                  [f6_access, f6_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f6_key]
                f6_access, f6_refresh = @base_browser_rp_credentials.fetch(f6_key)
                f6_cookie = [
                  f6_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f6_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f6_refresh)}",
                ].join("; ")
                f6_headers = f6_headers.merge(
                  "Cookie" => f6_cookie,
                  "HTTP_COOKIE" => f6_cookie,
                )
              end
            end
            f6_headers
          end
        fx6_harness.fetch("Cookie").split("; ").each do |pair|
          name, value = pair.split("=", 2)
          cookies[name] = Rack::Utils.unescape(value)
        end
        browser_headers.merge(fx6_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
      end
    get base_com_oidc_logout_url(host: @host),
        params: { logout_challenge: "does-not-exist", ri: "jp" },
        headers: http_headers_1

    assert_response :unprocessable_content
  end

  test "POST with a cross-origin challenge hands off to the sign surface for this realm" do
    protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    transaction =
      AcmeLogoutTransactionCoordinator.issue!(
        origin_surface: "core",
        initiating_client_id: "core-com",
        completion_url: AcmeLogoutTransactionCoordinator.completion_url_for(
          origin_surface: "core", ri: "jp",
          surface: "com",
        ),
        surface: "com",
        ri: "jp",
      ).transaction
    AcmeLogoutTransactionCoordinator.advance!(logout_challenge: transaction.logout_challenge, step: "origin_cleared")

    http_headers_0 =
      begin
        fx7_harness =
          begin
            f7_headers = as_visitor_headers(@visitor, host: @host, session_public_id: @session_public_id)
            f7_host = f7_headers["Host"]
            f7_route =
              begin
                Rails.application.routes.recognize_path("https://#{f7_host}/") if f7_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f7_family, f7_surface = f7_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f7_family) && f7_surface == "com"
              f7_client_id =
                case f7_family
                when "base" then "base-#{f7_surface}-ww"
                when "edit" then "edit-org"
                else "#{f7_family}-#{f7_surface}"
                end
              f7_token = VisitorToken.find_by!(public_id: f7_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f7_client = OidcClientRegistry.find!(f7_client_id)
              f7_key = [f7_client.client_id, f7_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f7_key] && f7_token.currently_usable? &&
                  !(f7_token.device_session_id && VisitorRpSession.exists?(
                    device_session_id: f7_token.device_session_id,
                    oidc_client_id: f7_client.client_id,
                    revoked_at: nil,
                  ))
                f7_token.rotate_refresh_token! unless f7_token.device_session.current_refresh_token_id
                f7_now = Time.current
                f7_session = VisitorRpSession.create!(
                  visitor_token: f7_token, oidc_client_id: f7_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f7_now,
                  refresh_token_expires_at: f7_now + 10.minutes,
                )
                f7_access = AuthenticationTokenService.encode(
                  f7_token.visitor, host: f7_host, resource_type: "visitor",
                                    session_public_id: f7_token.public_id, base_session_public_id: f7_token.public_id,
                                    oidc_sid: f7_session.public_id, oidc_jti: f7_session.oidc_jti,
                                    expires_at: f7_now + 10.minutes, scopes: %w(openid profile),
                                    issuer: OidcIssuer.for_client(f7_client), audiences: [f7_client.aud],
                                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f7_client),
                                    subject: OidcSubject.for(
                                      f7_token.visitor,
                                      resource_type: "visitor",
                                    ), client_id: f7_client.client_id,
                )
                @base_browser_rp_credentials[f7_key] =
                  [f7_access, f7_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f7_key]
                f7_access, f7_refresh = @base_browser_rp_credentials.fetch(f7_key)
                f7_cookie = [
                  f7_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f7_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f7_refresh)}",
                ].join("; ")
                f7_headers = f7_headers.merge(
                  "Cookie" => f7_cookie,
                  "HTTP_COOKIE" => f7_cookie,
                )
              end
            end
            f7_headers
          end
        fx7_harness.fetch("Cookie").split("; ").each do |pair|
          name, value = pair.split("=", 2)
          cookies[name] = Rack::Utils.unescape(value)
        end
        browser_headers.merge(fx7_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
      end
    get(
      base_com_oidc_logout_url(host: @host, logout_challenge: transaction.logout_challenge, ri: "jp"),
      headers: http_headers_0,
    )

    assert_response :success
    assert_not_predicate @token.reload, :revoked?
    assert_equal "acme_cleared", transaction.reload.expected_step
    csrf = response.parsed_body.at_css("meta[name='csrf-token']")["content"]
    post(
      base_com_oidc_logout_url(host: @host, logout_challenge: transaction.logout_challenge, ri: "jp"),
      params: { authenticity_token: csrf },
      headers: begin
        fx8_harness =
          begin
            f8_headers = as_visitor_headers(@visitor, host: @host, session_public_id: @session_public_id)
            f8_host = f8_headers["Host"]
            f8_route =
              begin
                Rails.application.routes.recognize_path("https://#{f8_host}/") if f8_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f8_family, f8_surface = f8_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f8_family) && f8_surface == "com"
              f8_client_id =
                case f8_family
                when "base" then "base-#{f8_surface}-ww"
                when "edit" then "edit-org"
                else "#{f8_family}-#{f8_surface}"
                end
              f8_token = VisitorToken.find_by!(public_id: f8_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f8_client = OidcClientRegistry.find!(f8_client_id)
              f8_key = [f8_client.client_id, f8_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f8_key] && f8_token.currently_usable? &&
                  !(f8_token.device_session_id && VisitorRpSession.exists?(
                    device_session_id: f8_token.device_session_id,
                    oidc_client_id: f8_client.client_id,
                    revoked_at: nil,
                  ))
                f8_token.rotate_refresh_token! unless f8_token.device_session.current_refresh_token_id
                f8_now = Time.current
                f8_session = VisitorRpSession.create!(
                  visitor_token: f8_token, oidc_client_id: f8_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f8_now,
                  refresh_token_expires_at: f8_now + 10.minutes,
                )
                f8_access = AuthenticationTokenService.encode(
                  f8_token.visitor, host: f8_host, resource_type: "visitor",
                                    session_public_id: f8_token.public_id, base_session_public_id: f8_token.public_id,
                                    oidc_sid: f8_session.public_id, oidc_jti: f8_session.oidc_jti,
                                    expires_at: f8_now + 10.minutes, scopes: %w(openid profile),
                                    issuer: OidcIssuer.for_client(f8_client), audiences: [f8_client.aud],
                                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f8_client),
                                    subject: OidcSubject.for(
                                      f8_token.visitor,
                                      resource_type: "visitor",
                                    ), client_id: f8_client.client_id,
                )
                @base_browser_rp_credentials[f8_key] =
                  [f8_access, f8_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f8_key]
                f8_access, f8_refresh = @base_browser_rp_credentials.fetch(f8_key)
                f8_cookie = [
                  f8_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f8_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f8_refresh)}",
                ].join("; ")
                f8_headers = f8_headers.merge(
                  "Cookie" => f8_cookie,
                  "HTTP_COOKIE" => f8_cookie,
                )
              end
            end
            f8_headers
          end
        fx8_harness.fetch("Cookie").split("; ").each do |pair|
          name, value = pair.split("=", 2)
          cookies[name] = Rack::Utils.unescape(value)
        end
        browser_headers.merge(fx8_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
      end.except("X-CSRF-Token").merge(
        "Sec-Fetch-Site" => "same-origin",
        "Origin" => "https://#{@host}",
      ),
    )

    assert_response :see_other
    assert_equal "sign_cleared", transaction.reload.expected_step
    assert_predicate @token.reload, :revoked?
    sign_host = ENV.fetch("PRIVATE_AUTH_CORPORATE_URL")
    handoff_uri = URI.parse(response.location)

    assert_equal sign_host, handoff_uri.host
    assert_equal "/sign/out", handoff_uri.path
    assert_equal transaction.logout_challenge, Rack::Utils.parse_nested_query(handoff_uri.query.to_s)["logout_challenge"]
  ensure
    ActionController::Base.allow_forgery_protection = protection
  end

  test "cross-site coordinated logout is rejected without cleanup or transaction advancement" do
    transaction = AcmeLogoutTransactionCoordinator.issue!(
      origin_surface: "core",
      initiating_client_id: "core-com",
      completion_url: AcmeLogoutTransactionCoordinator.completion_url_for(
        origin_surface: "core", ri: "jp", surface: "com",
      ),
      surface: "com",
      ri: "jp",
    ).transaction
    AcmeLogoutTransactionCoordinator.advance!(logout_challenge: transaction.logout_challenge, step: "origin_cleared")
    expected_step_before = transaction.reload.expected_step
    blocked = []
    subscriber = ->(_name, _start, _finish, _id, payload) { blocked << payload.fetch(:sec_fetch_site) }

    protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    ActiveSupport::Notifications.subscribed(subscriber, "csrf_request_blocked.action_controller") do
      post(
        base_com_oidc_logout_url(host: @host, logout_challenge: transaction.logout_challenge, ri: "jp"),
        headers: begin
          fx9_harness =
            begin
              f9_headers = as_visitor_headers(@visitor, host: @host, session_public_id: @session_public_id)
              f9_host = f9_headers["Host"]
              f9_route =
                begin
                  Rails.application.routes.recognize_path("https://#{f9_host}/") if f9_host.present?
                rescue ActionController::RoutingError
                  nil
                end
              f9_family, f9_surface = f9_route&.fetch(:controller)&.split("/")
              if %w(base warp core edit).include?(f9_family) && f9_surface == "com"
                f9_client_id =
                  case f9_family
                  when "base" then "base-#{f9_surface}-ww"
                  when "edit" then "edit-org"
                  else "#{f9_family}-#{f9_surface}"
                  end
                f9_token = VisitorToken.find_by!(public_id: f9_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                f9_client = OidcClientRegistry.find!(f9_client_id)
                f9_key = [f9_client.client_id, f9_token.public_id]
                @base_browser_rp_credentials ||= {}
                if !@base_browser_rp_credentials[f9_key] && f9_token.currently_usable? &&
                    !(f9_token.device_session_id && VisitorRpSession.exists?(
                      device_session_id: f9_token.device_session_id,
                      oidc_client_id: f9_client.client_id,
                      revoked_at: nil,
                    ))
                  f9_token.rotate_refresh_token! unless f9_token.device_session.current_refresh_token_id
                  f9_now = Time.current
                  f9_session = VisitorRpSession.create!(
                    visitor_token: f9_token, oidc_client_id: f9_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f9_now,
                    refresh_token_expires_at: f9_now + 10.minutes,
                  )
                  f9_access = AuthenticationTokenService.encode(
                    f9_token.visitor, host: f9_host, resource_type: "visitor",
                                      session_public_id: f9_token.public_id, base_session_public_id: f9_token.public_id,
                                      oidc_sid: f9_session.public_id, oidc_jti: f9_session.oidc_jti,
                                      expires_at: f9_now + 10.minutes, scopes: %w(openid profile),
                                      issuer: OidcIssuer.for_client(f9_client), audiences: [f9_client.aud],
                                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f9_client),
                                      subject: OidcSubject.for(
                                        f9_token.visitor,
                                        resource_type: "visitor",
                                      ), client_id: f9_client.client_id,
                  )
                  @base_browser_rp_credentials[f9_key] =
                    [f9_access, f9_session.issue_refresh_token!]
                end
                if @base_browser_rp_credentials[f9_key]
                  f9_access, f9_refresh = @base_browser_rp_credentials.fetch(f9_key)
                  f9_cookie = [
                    f9_headers.fetch("Cookie"),
                    "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f9_access)}",
                    "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f9_refresh)}",
                  ].join("; ")
                  f9_headers = f9_headers.merge(
                    "Cookie" => f9_cookie,
                    "HTTP_COOKIE" => f9_cookie,
                  )
                end
              end
              f9_headers
            end
          fx9_harness.fetch("Cookie").split("; ").each do |pair|
            name, value = pair.split("=", 2)
            cookies[name] = Rack::Utils.unescape(value)
          end
          browser_headers.merge(fx9_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
        end.merge(
          "Sec-Fetch-Site" => "cross-site",
          "Origin" => "https://attacker.example",
        ),
      )
    end

    assert_response :unprocessable_content
    assert_nil response.location
    assert_not_predicate @token.reload, :revoked?
    assert_equal expected_step_before, transaction.reload.expected_step
    assert_equal ["cross-site"], blocked
  ensure
    ActionController::Base.allow_forgery_protection = protection
  end

  test "missing fetch metadata and CSRF token are rejected without cleanup or transaction advancement" do
    protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    transaction = AcmeLogoutTransactionCoordinator.issue!(
      origin_surface: "core",
      initiating_client_id: "core-com",
      completion_url: AcmeLogoutTransactionCoordinator.completion_url_for(
        origin_surface: "core", ri: "jp", surface: "com",
      ),
      surface: "com",
      ri: "jp",
    ).transaction
    AcmeLogoutTransactionCoordinator.advance!(logout_challenge: transaction.logout_challenge, step: "origin_cleared")
    expected_step_before = transaction.reload.expected_step

    post(
      base_com_oidc_logout_url(host: @host, logout_challenge: transaction.logout_challenge, ri: "jp"),
      headers: begin
        fx10_harness =
          begin
            f10_headers = as_visitor_headers(@visitor, host: @host, session_public_id: @session_public_id)
            f10_host = f10_headers["Host"]
            f10_route =
              begin
                Rails.application.routes.recognize_path("https://#{f10_host}/") if f10_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f10_family, f10_surface = f10_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f10_family) && f10_surface == "com"
              f10_client_id =
                case f10_family
                when "base" then "base-#{f10_surface}-ww"
                when "edit" then "edit-org"
                else "#{f10_family}-#{f10_surface}"
                end
              f10_token = VisitorToken.find_by!(public_id: f10_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f10_client = OidcClientRegistry.find!(f10_client_id)
              f10_key = [f10_client.client_id, f10_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f10_key] && f10_token.currently_usable? &&
                  !(f10_token.device_session_id && VisitorRpSession.exists?(
                    device_session_id: f10_token.device_session_id,
                    oidc_client_id: f10_client.client_id,
                    revoked_at: nil,
                  ))
                f10_token.rotate_refresh_token! unless f10_token.device_session.current_refresh_token_id
                f10_now = Time.current
                f10_session = VisitorRpSession.create!(
                  visitor_token: f10_token, oidc_client_id: f10_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f10_now,
                  refresh_token_expires_at: f10_now + 10.minutes,
                )
                f10_access = AuthenticationTokenService.encode(
                  f10_token.visitor,
                  host: f10_host,
                  resource_type: "visitor",
                  session_public_id: f10_token.public_id,
                  base_session_public_id: f10_token.public_id,
                  oidc_sid: f10_session.public_id,
                  oidc_jti: f10_session.oidc_jti,
                  expires_at: f10_now + 10.minutes,
                  scopes: %w(openid profile),
                  issuer: OidcIssuer.for_client(f10_client),
                  audiences: [f10_client.aud],
                  jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f10_client),
                  subject: OidcSubject.for(
                    f10_token.visitor,
                    resource_type: "visitor",
                  ),
                  client_id: f10_client.client_id,
                )
                @base_browser_rp_credentials[f10_key] =
                  [f10_access, f10_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f10_key]
                f10_access, f10_refresh = @base_browser_rp_credentials.fetch(f10_key)
                f10_cookie = [
                  f10_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f10_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f10_refresh)}",
                ].join("; ")
                f10_headers = f10_headers.merge(
                  "Cookie" => f10_cookie,
                  "HTTP_COOKIE" => f10_cookie,
                )
              end
            end
            f10_headers
          end
        fx10_harness.fetch("Cookie").split("; ").each do |pair|
          name, value = pair.split("=", 2)
          cookies[name] = Rack::Utils.unescape(value)
        end
        browser_headers.merge(fx10_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
      end.except("X-CSRF-Token").merge("Sec-Fetch-Site" => nil, "Origin" => "https://#{@host}"),
    )

    assert_response :unprocessable_content
    assert_nil response.location
    assert_not_predicate @token.reload, :revoked?
    assert_equal expected_step_before, transaction.reload.expected_step
  ensure
    ActionController::Base.allow_forgery_protection = protection
  end

  test "untrusted origin is rejected without cleanup or transaction advancement" do
    protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    transaction = AcmeLogoutTransactionCoordinator.issue!(
      origin_surface: "core",
      initiating_client_id: "core-com",
      completion_url: AcmeLogoutTransactionCoordinator.completion_url_for(
        origin_surface: "core", ri: "jp", surface: "com",
      ),
      surface: "com",
      ri: "jp",
    ).transaction
    AcmeLogoutTransactionCoordinator.advance!(logout_challenge: transaction.logout_challenge, step: "origin_cleared")
    expected_step_before = transaction.reload.expected_step

    post(
      base_com_oidc_logout_url(host: @host, logout_challenge: transaction.logout_challenge, ri: "jp"),
      headers: begin
        fx11_harness =
          begin
            f11_headers = as_visitor_headers(@visitor, host: @host, session_public_id: @session_public_id)
            f11_host = f11_headers["Host"]
            f11_route =
              begin
                Rails.application.routes.recognize_path("https://#{f11_host}/") if f11_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f11_family, f11_surface = f11_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f11_family) && f11_surface == "com"
              f11_client_id =
                case f11_family
                when "base" then "base-#{f11_surface}-ww"
                when "edit" then "edit-org"
                else "#{f11_family}-#{f11_surface}"
                end
              f11_token = VisitorToken.find_by!(public_id: f11_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f11_client = OidcClientRegistry.find!(f11_client_id)
              f11_key = [f11_client.client_id, f11_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f11_key] && f11_token.currently_usable? &&
                  !(f11_token.device_session_id && VisitorRpSession.exists?(
                    device_session_id: f11_token.device_session_id,
                    oidc_client_id: f11_client.client_id,
                    revoked_at: nil,
                  ))
                f11_token.rotate_refresh_token! unless f11_token.device_session.current_refresh_token_id
                f11_now = Time.current
                f11_session = VisitorRpSession.create!(
                  visitor_token: f11_token, oidc_client_id: f11_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f11_now,
                  refresh_token_expires_at: f11_now + 10.minutes,
                )
                f11_access = AuthenticationTokenService.encode(
                  f11_token.visitor,
                  host: f11_host,
                  resource_type: "visitor",
                  session_public_id: f11_token.public_id,
                  base_session_public_id: f11_token.public_id,
                  oidc_sid: f11_session.public_id,
                  oidc_jti: f11_session.oidc_jti,
                  expires_at: f11_now + 10.minutes,
                  scopes: %w(openid profile),
                  issuer: OidcIssuer.for_client(f11_client),
                  audiences: [f11_client.aud],
                  jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f11_client),
                  subject: OidcSubject.for(
                    f11_token.visitor,
                    resource_type: "visitor",
                  ),
                  client_id: f11_client.client_id,
                )
                @base_browser_rp_credentials[f11_key] =
                  [f11_access, f11_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f11_key]
                f11_access, f11_refresh = @base_browser_rp_credentials.fetch(f11_key)
                f11_cookie = [
                  f11_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f11_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f11_refresh)}",
                ].join("; ")
                f11_headers = f11_headers.merge(
                  "Cookie" => f11_cookie,
                  "HTTP_COOKIE" => f11_cookie,
                )
              end
            end
            f11_headers
          end
        fx11_harness.fetch("Cookie").split("; ").each do |pair|
          name, value = pair.split("=", 2)
          cookies[name] = Rack::Utils.unescape(value)
        end
        browser_headers.merge(fx11_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
      end.merge(
        "Sec-Fetch-Site" => "same-origin",
        "Origin" => "https://attacker.example",
      ),
    )

    assert_response :unprocessable_content
    assert_nil response.location
    assert_not_predicate @token.reload, :revoked?
    assert_equal expected_step_before, transaction.reload.expected_step
  ensure
    ActionController::Base.allow_forgery_protection = protection
  end

  # D2: the coordinated-logout CSRF declaration used to replace the inherited check, so an ordinary
  # POST without logout_challenge ran no CSRF verification at all.
  test "D2 cross-site POST without logout_challenge or token does not end the staged session" do
    redirect_uri = @client.post_logout_redirect_uris.first

    with_forgery_protection do
      get base_com_oidc_logout_url(host: @host),
          params: { id_token_hint: id_token, post_logout_redirect_uri: redirect_uri, ri: "jp" },
          headers: begin
            fx12_harness =
              begin
                f12_headers = as_visitor_headers(@visitor, host: @host, session_public_id: @session_public_id)
                f12_host = f12_headers["Host"]
                f12_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{f12_host}/") if f12_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                f12_family, f12_surface = f12_route&.fetch(:controller)&.split("/")
                if %w(base warp core edit).include?(f12_family) && f12_surface == "com"
                  f12_client_id =
                    case f12_family
                    when "base" then "base-#{f12_surface}-ww"
                    when "edit" then "edit-org"
                    else "#{f12_family}-#{f12_surface}"
                    end
                  f12_token = VisitorToken.find_by!(public_id: f12_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  f12_client = OidcClientRegistry.find!(f12_client_id)
                  f12_key = [f12_client.client_id, f12_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[f12_key] && f12_token.currently_usable? &&
                      !(f12_token.device_session_id && VisitorRpSession.exists?(
                        device_session_id: f12_token.device_session_id,
                        oidc_client_id: f12_client.client_id,
                        revoked_at: nil,
                      ))
                    f12_token.rotate_refresh_token! unless f12_token.device_session.current_refresh_token_id
                    f12_now = Time.current
                    f12_session = VisitorRpSession.create!(
                      visitor_token: f12_token, oidc_client_id: f12_client.client_id, oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f12_now,
                      refresh_token_expires_at: f12_now + 10.minutes,
                    )
                    f12_access = AuthenticationTokenService.encode(
                      f12_token.visitor,
                      host: f12_host,
                      resource_type: "visitor",
                      session_public_id: f12_token.public_id,
                      base_session_public_id: f12_token.public_id,
                      oidc_sid: f12_session.public_id,
                      oidc_jti: f12_session.oidc_jti,
                      expires_at: f12_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(f12_client),
                      audiences: [f12_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f12_client),
                      subject: OidcSubject.for(
                        f12_token.visitor,
                        resource_type: "visitor",
                      ),
                      client_id: f12_client.client_id,
                    )
                    @base_browser_rp_credentials[f12_key] =
                      [f12_access, f12_session.issue_refresh_token!]
                  end
                  if @base_browser_rp_credentials[f12_key]
                    f12_access, f12_refresh = @base_browser_rp_credentials.fetch(f12_key)
                    f12_cookie = [
                      f12_headers.fetch("Cookie"),
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f12_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f12_refresh)}",
                    ].join("; ")
                    f12_headers = f12_headers.merge(
                      "Cookie" => f12_cookie,
                      "HTTP_COOKIE" => f12_cookie,
                    )
                  end
                end
                f12_headers
              end
            fx12_harness.fetch("Cookie").split("; ").each do |pair|
              name, value = pair.split("=", 2)
              cookies[name] = Rack::Utils.unescape(value)
            end
            browser_headers.merge(fx12_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
          end.merge("Sec-Fetch-Site" => "same-origin")
      post base_com_oidc_logout_url(host: @host),
           headers: begin
             fx13_harness =
               begin
                 f13_headers = as_visitor_headers(
                   @visitor,
                   host: @host,
                   session_public_id: @session_public_id,
                 )
                 f13_host = f13_headers["Host"]
                 f13_route =
                   begin
                     Rails.application.routes.recognize_path("https://#{f13_host}/") if f13_host.present?
                   rescue ActionController::RoutingError
                     nil
                   end
                 f13_family, f13_surface = f13_route&.fetch(:controller)&.split("/")
                 if %w(base warp core edit).include?(f13_family) && f13_surface == "com"
                   f13_client_id =
                     case f13_family
                     when "base" then "base-#{f13_surface}-ww"
                     when "edit" then "edit-org"
                     else "#{f13_family}-#{f13_surface}"
                     end
                   f13_token = VisitorToken.find_by!(public_id: f13_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                   f13_client = OidcClientRegistry.find!(f13_client_id)
                   f13_key = [f13_client.client_id, f13_token.public_id]
                   @base_browser_rp_credentials ||= {}
                   if !@base_browser_rp_credentials[f13_key] && f13_token.currently_usable? &&
                       !(f13_token.device_session_id && VisitorRpSession.exists?(
                         device_session_id: f13_token.device_session_id,
                         oidc_client_id: f13_client.client_id,
                         revoked_at: nil,
                       ))
                     f13_token.rotate_refresh_token! unless f13_token.device_session.current_refresh_token_id
                     f13_now = Time.current
                     f13_session = VisitorRpSession.create!(
                       visitor_token: f13_token, oidc_client_id: f13_client.client_id, oidc_scope: "openid profile",
                       oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f13_now,
                       refresh_token_expires_at: f13_now + 10.minutes,
                     )
                     f13_access = AuthenticationTokenService.encode(
                       f13_token.visitor,
                       host: f13_host,
                       resource_type: "visitor",
                       session_public_id: f13_token.public_id,
                       base_session_public_id: f13_token.public_id,
                       oidc_sid: f13_session.public_id,
                       oidc_jti: f13_session.oidc_jti,
                       expires_at: f13_now + 10.minutes,
                       scopes: %w(openid profile),
                       issuer: OidcIssuer.for_client(f13_client),
                       audiences: [f13_client.aud],
                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f13_client),
                       subject: OidcSubject.for(
                         f13_token.visitor,
                         resource_type: "visitor",
                       ),
                       client_id: f13_client.client_id,
                     )
                     @base_browser_rp_credentials[f13_key] =
                       [f13_access, f13_session.issue_refresh_token!]
                   end
                   if @base_browser_rp_credentials[f13_key]
                     f13_access, f13_refresh = @base_browser_rp_credentials.fetch(f13_key)
                     f13_cookie = [
                       f13_headers.fetch("Cookie"),
                       "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f13_access)}",
                       "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f13_refresh)}",
                     ].join("; ")
                     f13_headers = f13_headers.merge(
                       "Cookie" => f13_cookie,
                       "HTTP_COOKIE" => f13_cookie,
                     )
                   end
                 end
                 f13_headers
               end
             fx13_harness.fetch("Cookie").split("; ").each do |pair|
               name, value = pair.split("=", 2)
               cookies[name] = Rack::Utils.unescape(value)
             end
             browser_headers.merge(fx13_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
           end.except("X-CSRF-Token").merge("Sec-Fetch-Site" => "cross-site")
    end

    assert_not_predicate @token.reload, :revoked?
    assert_empty enqueued_jobs.select { |job| job["job_class"] == "OidcBackchannelLogoutDeliveryJob" }
  end

  test "D2 same-origin POST without logout_challenge still ends the staged session" do
    redirect_uri = @client.post_logout_redirect_uris.first

    with_forgery_protection do
      get base_com_oidc_logout_url(host: @host),
          params: { id_token_hint: id_token, post_logout_redirect_uri: redirect_uri, ri: "jp" },
          headers: begin
            fx14_harness =
              begin
                f14_headers = as_visitor_headers(@visitor, host: @host, session_public_id: @session_public_id)
                f14_host = f14_headers["Host"]
                f14_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{f14_host}/") if f14_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                f14_family, f14_surface = f14_route&.fetch(:controller)&.split("/")
                if %w(base warp core edit).include?(f14_family) && f14_surface == "com"
                  f14_client_id =
                    case f14_family
                    when "base" then "base-#{f14_surface}-ww"
                    when "edit" then "edit-org"
                    else "#{f14_family}-#{f14_surface}"
                    end
                  f14_token = VisitorToken.find_by!(public_id: f14_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  f14_client = OidcClientRegistry.find!(f14_client_id)
                  f14_key = [f14_client.client_id, f14_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[f14_key] && f14_token.currently_usable? &&
                      !(f14_token.device_session_id && VisitorRpSession.exists?(
                        device_session_id: f14_token.device_session_id,
                        oidc_client_id: f14_client.client_id,
                        revoked_at: nil,
                      ))
                    f14_token.rotate_refresh_token! unless f14_token.device_session.current_refresh_token_id
                    f14_now = Time.current
                    f14_session = VisitorRpSession.create!(
                      visitor_token: f14_token, oidc_client_id: f14_client.client_id, oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f14_now,
                      refresh_token_expires_at: f14_now + 10.minutes,
                    )
                    f14_access = AuthenticationTokenService.encode(
                      f14_token.visitor,
                      host: f14_host,
                      resource_type: "visitor",
                      session_public_id: f14_token.public_id,
                      base_session_public_id: f14_token.public_id,
                      oidc_sid: f14_session.public_id,
                      oidc_jti: f14_session.oidc_jti,
                      expires_at: f14_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(f14_client),
                      audiences: [f14_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f14_client),
                      subject: OidcSubject.for(
                        f14_token.visitor,
                        resource_type: "visitor",
                      ),
                      client_id: f14_client.client_id,
                    )
                    @base_browser_rp_credentials[f14_key] =
                      [f14_access, f14_session.issue_refresh_token!]
                  end
                  if @base_browser_rp_credentials[f14_key]
                    f14_access, f14_refresh = @base_browser_rp_credentials.fetch(f14_key)
                    f14_cookie = [
                      f14_headers.fetch("Cookie"),
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f14_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f14_refresh)}",
                    ].join("; ")
                    f14_headers = f14_headers.merge(
                      "Cookie" => f14_cookie,
                      "HTTP_COOKIE" => f14_cookie,
                    )
                  end
                end
                f14_headers
              end
            fx14_harness.fetch("Cookie").split("; ").each do |pair|
              name, value = pair.split("=", 2)
              cookies[name] = Rack::Utils.unescape(value)
            end
            browser_headers.merge(fx14_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
          end.merge("Sec-Fetch-Site" => "same-origin")
      post base_com_oidc_logout_url(host: @host), headers: begin
        fx15_harness =
          begin
            f15_headers = as_visitor_headers(@visitor, host: @host, session_public_id: @session_public_id)
            f15_host = f15_headers["Host"]
            f15_route =
              begin
                Rails.application.routes.recognize_path("https://#{f15_host}/") if f15_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f15_family, f15_surface = f15_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f15_family) && f15_surface == "com"
              f15_client_id =
                case f15_family
                when "base" then "base-#{f15_surface}-ww"
                when "edit" then "edit-org"
                else "#{f15_family}-#{f15_surface}"
                end
              f15_token = VisitorToken.find_by!(public_id: f15_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f15_client = OidcClientRegistry.find!(f15_client_id)
              f15_key = [f15_client.client_id, f15_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f15_key] && f15_token.currently_usable? &&
                  !(f15_token.device_session_id && VisitorRpSession.exists?(
                    device_session_id: f15_token.device_session_id,
                    oidc_client_id: f15_client.client_id,
                    revoked_at: nil,
                  ))
                f15_token.rotate_refresh_token! unless f15_token.device_session.current_refresh_token_id
                f15_now = Time.current
                f15_session = VisitorRpSession.create!(
                  visitor_token: f15_token, oidc_client_id: f15_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f15_now,
                  refresh_token_expires_at: f15_now + 10.minutes,
                )
                f15_access = AuthenticationTokenService.encode(
                  f15_token.visitor,
                  host: f15_host,
                  resource_type: "visitor",
                  session_public_id: f15_token.public_id,
                  base_session_public_id: f15_token.public_id,
                  oidc_sid: f15_session.public_id,
                  oidc_jti: f15_session.oidc_jti,
                  expires_at: f15_now + 10.minutes,
                  scopes: %w(openid profile),
                  issuer: OidcIssuer.for_client(f15_client),
                  audiences: [f15_client.aud],
                  jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f15_client),
                  subject: OidcSubject.for(
                    f15_token.visitor,
                    resource_type: "visitor",
                  ),
                  client_id: f15_client.client_id,
                )
                @base_browser_rp_credentials[f15_key] = [f15_access, f15_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f15_key]
                f15_access, f15_refresh = @base_browser_rp_credentials.fetch(f15_key)
                f15_cookie = [
                  f15_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f15_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f15_refresh)}",
                ].join("; ")
                f15_headers = f15_headers.merge(
                  "Cookie" => f15_cookie,
                  "HTTP_COOKIE" => f15_cookie,
                )
              end
            end
            f15_headers
          end
        fx15_harness.fetch("Cookie").split("; ").each do |pair|
          name, value = pair.split("=", 2)
          cookies[name] = Rack::Utils.unescape(value)
        end
        browser_headers.merge(fx15_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
      end.merge("Sec-Fetch-Site" => "same-origin")
    end

    assert_response :see_other
    assert_predicate @token.reload, :revoked?
  end

  private

  # A real browser presents the access token as a cookie alongside the Rails session cookie. The
  # harness headers carry it as a raw Cookie header, which would replace the jar (and the staged
  # logout request in the session), so the harness-issued token is placed in the jar instead.

  def id_token(resource: @visitor, subject: OidcSubject.for(@visitor, resource_type: "visitor"),
               sid: @session_public_id)
    OidcIdTokenIssuer.call(
      resource: resource,
      client: @client,
      nonce: "nonce",
      issuer: OidcIssuer.for_resource_type("visitor"),
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("visitor"),
      subject: subject,
      sid: sid,
    )
  end
  private

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class Base::Com::Oidc::LogoutsControllerTest
  private
end

# DAMP local helper copy on the test class.
class Base::Com::Oidc::LogoutsControllerTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )
  PREFERENCE_JWT_KEY = OpenSSL::PKey::EC.generate("secp384r1") unless const_defined?(:PREFERENCE_JWT_KEY, false)

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def set_access_cookie(token)
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = token
  end

  def set_refresh_cookie(token)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token
  end

  def jump_rt_url_from_location(location)
    uri = URI.parse(location.to_s)
    return location unless uri.host == "jump.umaxica.net"

    token = Rack::Utils.parse_nested_query(uri.query.to_s)["rt"]
    return location if token.blank?

    payload, = JWT.decode(token, nil, false)
    payload["url"].presence || location
  rescue JWT::DecodeError, URI::InvalidURIError
    location
  end

  def with_preference_jwt_keys(host: nil)
    audiences = host ? [host] : PreferenceJwtConfiguration.audiences
    pub_key_for_stub = ->(_kid, **_options) { self.class::PREFERENCE_JWT_KEY }
    PreferenceJwtConfiguration.stub(:private_key, self.class::PREFERENCE_JWT_KEY) do
      PreferenceJwtConfiguration.stub(:public_key, self.class::PREFERENCE_JWT_KEY) do
        PreferenceJwtConfiguration.stub(:private_key_for_active, self.class::PREFERENCE_JWT_KEY) do
          PreferenceJwtConfiguration.stub(:public_key_for, pub_key_for_stub) do
            PreferenceJwtConfiguration.stub(:active_kid, "default") do
              PreferenceJwtConfiguration.stub(:issuer, "jit-preference") do
                PreferenceJwtConfiguration.stub(:audiences, audiences) { yield }
              end
            end
          end
        end
      end
    end
  end

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = { "Client-Agent" => self.class::TEST_BROWSER_USER_AGENT }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = csrf_token_value
    cookies["csrf_token"] = csrf_token if respond_to?(:cookies, true)
    host_headers.merge("X-CSRF-Token" => csrf_token)
  end

  def ensure_user_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::ACTIVE)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientTelephoneStatus.find_or_create_by!(id: ClientTelephoneStatus::VERIFIED)
    ClientPasskeyStatus.find_or_create_by!(id: ClientPasskeyStatus::ACTIVE)
  end

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
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

  def create_verified_visitor_with_email(email_address: "visitor-#{SecureRandom.hex(4)}@example.com")
    ensure_visitor_reference_records!
    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    VisitorEmail.create!(
      visitor_id: visitor.id, address: email_address,
      address_digest: IdentifierBlindIndex.bidx_for_email(email_address, realm: :com),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
    visitor.reload
  end

  def satisfy_user_verification(token, scope: nil)
    _verification, raw_token = ClientVerification.issue_for_token!(token: token)
    cookies[ClientVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_staff_verification(token, scope: nil)
    _verification, raw_token = OperatorVerification.issue_for_token!(token: token)
    cookies[OperatorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_visitor_verification(token, scope: nil)
    _verification, raw_token = VisitorVerification.issue_for_token!(token: token)
    cookies[VisitorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    token.update_columns(
      { last_step_up_at: at,
        last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
        updated_at: Time.current, }.compact,
    )
  end

  def load_jump_rt_env!
    @jump_rt_env_originals ||= {}
    jump_rt_key = Base64.strict_encode64(OpenSSL::PKey::EC.generate("secp384r1").to_der)
    %w(AUTH_APP AUTH_ORG AUTH_COM ACME_APP ACME_ORG ACME_COM CORE_APP CORE_ORG CORE_COM BASE_APP BASE_ORG
       BASE_COM).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["PUBLIC_JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
    JitSecurityJwtRegistry.reload! if defined?(JitSecurityJwtRegistry)
  end

  def with_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process and every later test expecting protection off would fail.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  def csrf_token_value
    "test-csrf-token"
  end

  def response_set_cookie_lines
    raw = response.headers["Set-Cookie"] || response.headers["set-cookie"]
    lines = raw.is_a?(Array) ? raw : raw.to_s.split("\n")
    lines.flat_map { |line| line.to_s.split("\n") }.compact_blank
  end

  def extract_cookies_from_response
    response_set_cookie_lines.each_with_object({}) do |line, parsed|
      pair = line.to_s.split(";", 2).first
      name, value = pair.to_s.split("=", 2)
      parsed[name] = CGI.unescape(value.to_s) if name.present?
    end
  end

  def state_changing_application_route_targets
    Rails.application.routes.routes.filter_map do |route|
      verbs = route.verb.to_s.delete("^A-Z|").split("|")
      next if verbs.empty? || (verbs - %w(GET HEAD)).empty?

      controller = route.required_defaults[:controller].to_s
      action = route.required_defaults[:action].to_s
      next if controller.blank? || action.blank?

      controller_class_name = "#{controller.camelize}Controller"
      next unless Rails.root.join("app/controllers/#{controller}_controller.rb").exist?

      { verb: verbs.join("|"),
        path: route.path.spec.to_s,
        controller: controller,
        action: action,
        controller_class: Object.const_get(controller_class_name), }
    rescue NameError
      nil
    end
  end

  def setup_google_mock_auth(uid: "google_uid_123", email: "google@example.com")
    OmniAuth.config.mock_auth[:google_app] =
      OmniAuth::AuthHash.new(
        provider: "google_app", uid: uid, info: { email: email, name: "Google Client" },
        credentials: { token: "google_token", expires_at: 1.hour.from_now.to_i },
      )
  end
end

# DAMP: authenticated header helpers that attach a real JWT access cookie so the
# Base RP authentication pipeline recognizes the logged-in session instead of
# redirecting to /oauth/authorize. This final reopening overrides any earlier
# helper definitions in this file so every "logged in" request carries a valid
# access token cookie for the correct actor and surface.
class Base::Com::Oidc::LogoutsControllerTest
  private

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
end
