# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
# require "helpers/auth_helpers"

class Visa::App::Oidc::LogoutsControllerTest < ActionDispatch::IntegrationTest
  # include AuthHelpers

  setup do
    @host = visa_host_for_test_surface(:app)
    @client = OidcClientRegistry.find!("core-app-jp")
    @user = clients(:one)
    @token = ClientToken.create!(
      authentication_epoch: 0,
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
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

    assert_equal "visa/app/oidc/logouts", get_route[:controller]
    assert_equal "show", get_route[:action]
    assert_equal "visa/app/oidc/logouts", post_route[:controller]
    assert_equal "create", post_route[:action]
    assert_equal "/oidc/logout", visa_app_oidc_logout_path
  end

  test "the user's logout confirmation is a separate POST resource" do
    route = Rails.application.routes.recognize_path(
      "https://#{@host}/oidc/logout/confirmation",
      method: :post,
    )

    assert_equal "visa/app/oidc/logouts/confirmations", route[:controller]
    assert_equal "create", route[:action]
    assert_equal "/oidc/logout/confirmation", visa_app_oidc_logout_confirmation_path
  end

  test "get without params renders confirmation without mutation" do
    http_headers_30 =
      begin
        fx0_harness =
          begin
            f0_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
            f0_host = f0_headers["Host"]
            f0_route =
              begin
                Rails.application.routes.recognize_path("https://#{f0_host}/") if f0_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f0_family, f0_surface = f0_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f0_family) && f0_surface == "app"
              f0_client_id =
                case f0_family
                when "base" then "base-#{f0_surface}-ww"
                when "edit" then "edit-org-ww"
                else "#{f0_family}-#{f0_surface}"
                end
              f0_token = ClientToken.includes(
                :user,
                :device_session,
              ).find_by!(public_id: f0_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f0_client = OidcClientRegistry.find!(f0_client_id)
              f0_key = [f0_client.client_id, f0_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f0_key] && f0_token.currently_usable? &&
                  !(f0_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f0_token.device_session_id,
                    oidc_client_id: f0_client.client_id,
                    revoked_at: nil,
                  ))
                f0_token.rotate_refresh_token! unless f0_token.device_session_record.current_refresh_token_id
                f0_now = Time.current
                f0_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f0_token, oidc_client_id: f0_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f0_now,
                  refresh_token_expires_at: f0_now + 10.minutes,
                )
                f0_access = AuthenticationTokenService.encode(
                  f0_token.actor_record, host: f0_host, resource_type: "client",
                                         session_public_id: f0_token.public_id,
                                         base_session_public_id: f0_token.public_id,
                                         oidc_sid: f0_session.public_id, oidc_jti: f0_session.oidc_jti,
                                         expires_at: f0_now + 10.minutes, scopes: %w(openid profile),
                                         issuer: OidcIssuer.for_client(f0_client), audiences: [f0_client.aud],
                                         jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f0_client),
                                         subject: OidcSubject.for(
                                           f0_token.actor_record,
                                           resource_type: "client",
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
    get visa_app_oidc_logout_url(host: @host), params: { ri: "jp" }, headers: http_headers_30

    assert_response :ok
    assert_not_predicate @token.reload, :revoked?
    assert_nil response.location
  end

  test "validated logout request is staged through shared confirmation" do
    redirect_uri = @client.post_logout_redirect_uris.first

    http_headers_29 =
      begin
        fx1_harness =
          begin
            f1_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
            f1_host = f1_headers["Host"]
            f1_route =
              begin
                Rails.application.routes.recognize_path("https://#{f1_host}/") if f1_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f1_family, f1_surface = f1_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f1_family) && f1_surface == "app"
              f1_client_id =
                case f1_family
                when "base" then "base-#{f1_surface}-ww"
                when "edit" then "edit-org-ww"
                else "#{f1_family}-#{f1_surface}"
                end
              f1_token = ClientToken.includes(
                :user,
                :device_session,
              ).find_by!(public_id: f1_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f1_client = OidcClientRegistry.find!(f1_client_id)
              f1_key = [f1_client.client_id, f1_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f1_key] && f1_token.currently_usable? &&
                  !(f1_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f1_token.device_session_id,
                    oidc_client_id: f1_client.client_id,
                    revoked_at: nil,
                  ))
                f1_token.rotate_refresh_token! unless f1_token.device_session_record.current_refresh_token_id
                f1_now = Time.current
                f1_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f1_token, oidc_client_id: f1_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f1_now,
                  refresh_token_expires_at: f1_now + 10.minutes,
                )
                f1_access = AuthenticationTokenService.encode(
                  f1_token.actor_record, host: f1_host, resource_type: "client",
                                         session_public_id: f1_token.public_id,
                                         base_session_public_id: f1_token.public_id,
                                         oidc_sid: f1_session.public_id, oidc_jti: f1_session.oidc_jti,
                                         expires_at: f1_now + 10.minutes, scopes: %w(openid profile),
                                         issuer: OidcIssuer.for_client(f1_client), audiences: [f1_client.aud],
                                         jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f1_client),
                                         subject: OidcSubject.for(
                                           f1_token.actor_record,
                                           resource_type: "client",
                                         ), client_id: f1_client.client_id,
                )
                @base_browser_rp_credentials[f1_key] =
                  [f1_access, f1_session.issue_refresh_token!]
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
    post visa_app_oidc_logout_url(host: @host),
         params: { id_token_hint: id_token, post_logout_redirect_uri: redirect_uri, state: "xyz", ri: "jp" },
         headers: http_headers_29

    assert_response :see_other
    assert_equal "/oidc/logout", URI.parse(jump_rt_url_from_location(response.location)).path

    follow_redirect!

    assert_response :ok
    assert_equal visa_app_oidc_logout_confirmation_path(ri: "jp"), inertia_props.dig("form", "action")

    http_headers_28 =
      begin
        fx2_harness =
          begin
            f2_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
            f2_host = f2_headers["Host"]
            f2_route =
              begin
                Rails.application.routes.recognize_path("https://#{f2_host}/") if f2_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f2_family, f2_surface = f2_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f2_family) && f2_surface == "app"
              f2_client_id =
                case f2_family
                when "base" then "base-#{f2_surface}-ww"
                when "edit" then "edit-org-ww"
                else "#{f2_family}-#{f2_surface}"
                end
              f2_token = ClientToken.includes(
                :user,
                :device_session,
              ).find_by!(public_id: f2_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f2_client = OidcClientRegistry.find!(f2_client_id)
              f2_key = [f2_client.client_id, f2_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f2_key] && f2_token.currently_usable? &&
                  !(f2_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f2_token.device_session_id,
                    oidc_client_id: f2_client.client_id,
                    revoked_at: nil,
                  ))
                f2_token.rotate_refresh_token! unless f2_token.device_session_record.current_refresh_token_id
                f2_now = Time.current
                f2_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f2_token, oidc_client_id: f2_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f2_now,
                  refresh_token_expires_at: f2_now + 10.minutes,
                )
                f2_access = AuthenticationTokenService.encode(
                  f2_token.actor_record, host: f2_host, resource_type: "client",
                                         session_public_id: f2_token.public_id,
                                         base_session_public_id: f2_token.public_id,
                                         oidc_sid: f2_session.public_id, oidc_jti: f2_session.oidc_jti,
                                         expires_at: f2_now + 10.minutes, scopes: %w(openid profile),
                                         issuer: OidcIssuer.for_client(f2_client), audiences: [f2_client.aud],
                                         jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f2_client),
                                         subject: OidcSubject.for(
                                           f2_token.actor_record,
                                           resource_type: "client",
                                         ), client_id: f2_client.client_id,
                )
                @base_browser_rp_credentials[f2_key] = [f2_access, f2_session.issue_refresh_token!]
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
    post visa_app_oidc_logout_confirmation_path(host: @host, ri: "jp"), headers: http_headers_28

    assert_response :see_other
    assert_predicate @token.reload, :revoked?

    stop_target = OpAppAuthorityStopRootTarget.find_by!(root: @token)
    stop = OpAppAuthorityStop.find(stop_target.stop_id)
    browser_receipt = OpAppAuthorityStopBrowserLogout.find_by!(stop:)
    stored_receipt = session.fetch(OpLogoutReceiptSession::KEY)

    assert_equal "app", stored_receipt.fetch("realm")
    assert_equal stop.public_id, stored_receipt.fetch("stop")
    assert_equal Digest::SHA256.digest(stored_receipt.fetch("nonce")), browser_receipt.receipt_nonce_digest
    assert_equal Digest::SHA256.digest(stored_receipt.fetch("browser_binding")), browser_receipt.browser_binding_digest

    location = URI.parse(jump_rt_url_from_location(response.location))
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal URI.parse(redirect_uri).host, location.host
    assert_equal URI.parse(redirect_uri).path, location.path
    assert_equal "xyz", query["state"]
  end

  test "D-33 refuses an unknown RP-facing logout_challenge on POST" do
    stops_before = OpAppAuthorityStop.count
    post visa_app_oidc_logout_path(logout_challenge: "retired-rp-challenge", ri: "jp"),
         headers: as_user_headers(@user, host: @host, session_public_id: @session_public_id)

    assert_response :bad_request
    assert_equal stops_before, OpAppAuthorityStop.count
    assert_nil session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]
    assert_not_predicate @token.reload, :revoked?
  end

  test "D-33 refuses logout_challenge on GET" do
    stops_before = OpAppAuthorityStop.count
    get visa_app_oidc_logout_path(logout_challenge: "retired-rp-challenge", ri: "jp"),
        headers: as_user_headers(@user, host: @host, session_public_id: @session_public_id)

    assert_response :bad_request
    assert_equal stops_before, OpAppAuthorityStop.count
    assert_nil session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]
    assert_not_predicate @token.reload, :revoked?
  end

  test "a POST with neither a redirect target nor a staged request answers the failure page" do
    http_headers_25 =
      begin
        fx5_harness =
          begin
            f5_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
            f5_host = f5_headers["Host"]
            f5_route =
              begin
                Rails.application.routes.recognize_path("https://#{f5_host}/") if f5_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f5_family, f5_surface = f5_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f5_family) && f5_surface == "app"
              f5_client_id =
                case f5_family
                when "base" then "base-#{f5_surface}-ww"
                when "edit" then "edit-org-ww"
                else "#{f5_family}-#{f5_surface}"
                end
              f5_token = ClientToken.includes(
                :user,
                :device_session,
              ).find_by!(public_id: f5_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f5_client = OidcClientRegistry.find!(f5_client_id)
              f5_key = [f5_client.client_id, f5_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f5_key] && f5_token.currently_usable? &&
                  !(f5_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f5_token.device_session_id,
                    oidc_client_id: f5_client.client_id,
                    revoked_at: nil,
                  ))
                f5_token.rotate_refresh_token! unless f5_token.device_session_record.current_refresh_token_id
                f5_now = Time.current
                f5_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f5_token, oidc_client_id: f5_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f5_now,
                  refresh_token_expires_at: f5_now + 10.minutes,
                )
                f5_access = AuthenticationTokenService.encode(
                  f5_token.actor_record, host: f5_host, resource_type: "client",
                                         session_public_id: f5_token.public_id,
                                         base_session_public_id: f5_token.public_id,
                                         oidc_sid: f5_session.public_id, oidc_jti: f5_session.oidc_jti,
                                         expires_at: f5_now + 10.minutes, scopes: %w(openid profile),
                                         issuer: OidcIssuer.for_client(f5_client), audiences: [f5_client.aud],
                                         jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f5_client),
                                         subject: OidcSubject.for(
                                           f5_token.actor_record,
                                           resource_type: "client",
                                         ), client_id: f5_client.client_id,
                )
                @base_browser_rp_credentials[f5_key] = [f5_access, f5_session.issue_refresh_token!]
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
    post visa_app_oidc_logout_url(host: @host), params: { ri: "jp" }, headers: http_headers_25

    assert_response :success
    assert_not_predicate @token.reload, :revoked?
  end

  test "invalid post_logout_redirect_uri never redirects externally" do
    http_headers_24 =
      begin
        fx6_harness =
          begin
            f6_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
            f6_host = f6_headers["Host"]
            f6_route =
              begin
                Rails.application.routes.recognize_path("https://#{f6_host}/") if f6_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f6_family, f6_surface = f6_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f6_family) && f6_surface == "app"
              f6_client_id =
                case f6_family
                when "base" then "base-#{f6_surface}-ww"
                when "edit" then "edit-org-ww"
                else "#{f6_family}-#{f6_surface}"
                end
              f6_token = ClientToken.includes(
                :user,
                :device_session,
              ).find_by!(public_id: f6_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f6_client = OidcClientRegistry.find!(f6_client_id)
              f6_key = [f6_client.client_id, f6_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f6_key] && f6_token.currently_usable? &&
                  !(f6_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f6_token.device_session_id,
                    oidc_client_id: f6_client.client_id,
                    revoked_at: nil,
                  ))
                f6_token.rotate_refresh_token! unless f6_token.device_session_record.current_refresh_token_id
                f6_now = Time.current
                f6_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f6_token, oidc_client_id: f6_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f6_now,
                  refresh_token_expires_at: f6_now + 10.minutes,
                )
                f6_access = AuthenticationTokenService.encode(
                  f6_token.actor_record, host: f6_host, resource_type: "client",
                                         session_public_id: f6_token.public_id,
                                         base_session_public_id: f6_token.public_id,
                                         oidc_sid: f6_session.public_id, oidc_jti: f6_session.oidc_jti,
                                         expires_at: f6_now + 10.minutes, scopes: %w(openid profile),
                                         issuer: OidcIssuer.for_client(f6_client), audiences: [f6_client.aud],
                                         jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f6_client),
                                         subject: OidcSubject.for(
                                           f6_token.actor_record,
                                           resource_type: "client",
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
    post visa_app_oidc_logout_url(host: @host),
         params: {
           id_token_hint: id_token,
           post_logout_redirect_uri: "https://attacker.example/signed-out",
           state: "xyz",
           ri: "jp",
         },
         headers: http_headers_24

    assert_response :success
    assert_not_predicate @token.reload, :revoked?
    assert_nil response.location
    assert_not_includes response.body, "xyz"
  end

  test "post_logout_redirect_uri registered for another realm never redirects externally" do
    cross_realm_uri = OidcClientRegistry.find!("core-org-jp").post_logout_redirect_uris.first

    assert_not_nil cross_realm_uri, "core-org-jp should register an org-realm post_logout uri"

    http_headers_23 =
      begin
        fx7_harness =
          begin
            f7_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
            f7_host = f7_headers["Host"]
            f7_route =
              begin
                Rails.application.routes.recognize_path("https://#{f7_host}/") if f7_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f7_family, f7_surface = f7_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f7_family) && f7_surface == "app"
              f7_client_id =
                case f7_family
                when "base" then "base-#{f7_surface}-ww"
                when "edit" then "edit-org-ww"
                else "#{f7_family}-#{f7_surface}"
                end
              f7_token = ClientToken.includes(
                :user,
                :device_session,
              ).find_by!(public_id: f7_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f7_client = OidcClientRegistry.find!(f7_client_id)
              f7_key = [f7_client.client_id, f7_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f7_key] && f7_token.currently_usable? &&
                  !(f7_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f7_token.device_session_id,
                    oidc_client_id: f7_client.client_id,
                    revoked_at: nil,
                  ))
                f7_token.rotate_refresh_token! unless f7_token.device_session_record.current_refresh_token_id
                f7_now = Time.current
                f7_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f7_token, oidc_client_id: f7_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f7_now,
                  refresh_token_expires_at: f7_now + 10.minutes,
                )
                f7_access = AuthenticationTokenService.encode(
                  f7_token.actor_record, host: f7_host, resource_type: "client",
                                         session_public_id: f7_token.public_id,
                                         base_session_public_id: f7_token.public_id,
                                         oidc_sid: f7_session.public_id, oidc_jti: f7_session.oidc_jti,
                                         expires_at: f7_now + 10.minutes, scopes: %w(openid profile),
                                         issuer: OidcIssuer.for_client(f7_client), audiences: [f7_client.aud],
                                         jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f7_client),
                                         subject: OidcSubject.for(
                                           f7_token.actor_record,
                                           resource_type: "client",
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
    post visa_app_oidc_logout_url(host: @host),
         params: { id_token_hint: id_token, post_logout_redirect_uri: cross_realm_uri, state: "xyz", ri: "jp" },
         headers: http_headers_23

    assert_response :success
    assert_not_predicate @token.reload, :revoked?
    assert_nil response.location
    assert_not_includes response.body, "xyz"
  end

  test "D-33 refuses an unknown logout_challenge without OP state changes" do
    stops_before = OpAppAuthorityStop.count
    get visa_app_oidc_logout_path(logout_challenge: "retired-rp-challenge", ri: "jp"),
        headers: as_user_headers(@user, host: @host, session_public_id: @session_public_id)

    assert_response :bad_request
    assert_equal stops_before, OpAppAuthorityStop.count
    assert_nil session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]
    assert_not_predicate @token.reload, :revoked?
  end

  test "D-33 refuses an expired RP logout_challenge without OP state changes" do
    stops_before = OpAppAuthorityStop.count
    get visa_app_oidc_logout_path(logout_challenge: "retired-rp-challenge", ri: "jp"),
        headers: as_user_headers(@user, host: @host, session_public_id: @session_public_id)

    assert_response :bad_request
    assert_equal stops_before, OpAppAuthorityStop.count
    assert_nil session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]
    assert_not_predicate @token.reload, :revoked?
  end

  test "D-33 refuses a previously issued RP logout_challenge" do
    stops_before = OpAppAuthorityStop.count
    get visa_app_oidc_logout_path(logout_challenge: "retired-rp-challenge", ri: "jp"),
        headers: as_user_headers(@user, host: @host, session_public_id: @session_public_id)

    assert_response :bad_request
    assert_equal stops_before, OpAppAuthorityStop.count
    assert_nil session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]
    assert_not_predicate @token.reload, :revoked?
  end

  test "D-33 refuses the retired sign-origin logout challenge on POST" do
    stops_before = OpAppAuthorityStop.count
    post visa_app_oidc_logout_path(logout_challenge: "retired-rp-challenge", ri: "jp"),
         headers: as_user_headers(@user, host: @host, session_public_id: @session_public_id)

    assert_response :bad_request
    assert_equal stops_before, OpAppAuthorityStop.count
    assert_nil session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]
    assert_not_predicate @token.reload, :revoked?
  end

  test "D-33 refuses the retired ready logout challenge on POST" do
    stops_before = OpAppAuthorityStop.count
    post visa_app_oidc_logout_path(logout_challenge: "retired-rp-challenge", ri: "jp"),
         headers: as_user_headers(@user, host: @host, session_public_id: @session_public_id)

    assert_response :bad_request
    assert_equal stops_before, OpAppAuthorityStop.count
    assert_nil session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]
    assert_not_predicate @token.reload, :revoked?
  end

  test "D-33 refuses the retired Palm logout challenge on POST" do
    stops_before = OpAppAuthorityStop.count
    post visa_app_oidc_logout_path(logout_challenge: "retired-rp-challenge", ri: "jp"),
         headers: as_user_headers(@user, host: @host, session_public_id: @session_public_id)

    assert_response :bad_request
    assert_equal stops_before, OpAppAuthorityStop.count
    assert_nil session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]
    assert_not_predicate @token.reload, :revoked?
  end

  test "invalid end-session request returns a json error for json format" do
    http_headers_19 =
      begin
        fx14_harness =
          begin
            f14_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
            f14_host = f14_headers["Host"]
            f14_route =
              begin
                Rails.application.routes.recognize_path("https://#{f14_host}/") if f14_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f14_family, f14_surface = f14_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f14_family) && f14_surface == "app"
              f14_client_id =
                case f14_family
                when "base" then "base-#{f14_surface}-ww"
                when "edit" then "edit-org-ww"
                else "#{f14_family}-#{f14_surface}"
                end
              f14_token = ClientToken.includes(
                :user,
                :device_session,
              ).find_by!(public_id: f14_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f14_client = OidcClientRegistry.find!(f14_client_id)
              f14_key = [f14_client.client_id, f14_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f14_key] && f14_token.currently_usable? &&
                  !(f14_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f14_token.device_session_id,
                    oidc_client_id: f14_client.client_id,
                    revoked_at: nil,
                  ))
                f14_token.rotate_refresh_token! unless f14_token.device_session_record.current_refresh_token_id
                f14_now = Time.current
                f14_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f14_token, oidc_client_id: f14_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f14_now,
                  refresh_token_expires_at: f14_now + 10.minutes,
                )
                f14_access = AuthenticationTokenService.encode(
                  f14_token.actor_record,
                  host: f14_host,
                  resource_type: "client",
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
                    f14_token.actor_record,
                    resource_type: "client",
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
      end
    post visa_app_oidc_logout_url(host: @host, format: :json),
         params: {
           id_token_hint: id_token,
           post_logout_redirect_uri: "https://attacker.example/signed-out",
           ri: "jp",
         },
         headers: http_headers_19

    assert_response :bad_request
    body = response.parsed_body

    assert_equal "invalid_request", body["error"]
  end

  test "a missing staged confirmation returns a json failure for json format" do
    http_headers_18 =
      begin
        fx15_harness =
          begin
            f15_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
            f15_host = f15_headers["Host"]
            f15_route =
              begin
                Rails.application.routes.recognize_path("https://#{f15_host}/") if f15_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f15_family, f15_surface = f15_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f15_family) && f15_surface == "app"
              f15_client_id =
                case f15_family
                when "base" then "base-#{f15_surface}-ww"
                when "edit" then "edit-org-ww"
                else "#{f15_family}-#{f15_surface}"
                end
              f15_token = ClientToken.includes(
                :user,
                :device_session,
              ).find_by!(public_id: f15_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f15_client = OidcClientRegistry.find!(f15_client_id)
              f15_key = [f15_client.client_id, f15_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f15_key] && f15_token.currently_usable? &&
                  !(f15_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f15_token.device_session_id,
                    oidc_client_id: f15_client.client_id,
                    revoked_at: nil,
                  ))
                f15_token.rotate_refresh_token! unless f15_token.device_session_record.current_refresh_token_id
                f15_now = Time.current
                f15_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f15_token, oidc_client_id: f15_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f15_now,
                  refresh_token_expires_at: f15_now + 10.minutes,
                )
                f15_access = AuthenticationTokenService.encode(
                  f15_token.actor_record,
                  host: f15_host,
                  resource_type: "client",
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
                    f15_token.actor_record,
                    resource_type: "client",
                  ),
                  client_id: f15_client.client_id,
                )
                @base_browser_rp_credentials[f15_key] =
                  [f15_access, f15_session.issue_refresh_token!]
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
      end
    post visa_app_oidc_logout_confirmation_path(host: @host, format: :json, ri: "jp"),
         headers: http_headers_18

    assert_response :unprocessable_content
    body = response.parsed_body

    assert_equal "unprocessable_content", body["error"]
  end

  test "second GET after a request is staged renders confirmation without mutation" do
    redirect_uri = @client.post_logout_redirect_uris.first

    http_headers_17 =
      begin
        fx16_harness =
          begin
            f16_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
            f16_host = f16_headers["Host"]
            f16_route =
              begin
                Rails.application.routes.recognize_path("https://#{f16_host}/") if f16_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f16_family, f16_surface = f16_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f16_family) && f16_surface == "app"
              f16_client_id =
                case f16_family
                when "base" then "base-#{f16_surface}-ww"
                when "edit" then "edit-org-ww"
                else "#{f16_family}-#{f16_surface}"
                end
              f16_token = ClientToken.includes(
                :user,
                :device_session,
              ).find_by!(public_id: f16_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f16_client = OidcClientRegistry.find!(f16_client_id)
              f16_key = [f16_client.client_id, f16_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f16_key] && f16_token.currently_usable? &&
                  !(f16_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f16_token.device_session_id,
                    oidc_client_id: f16_client.client_id,
                    revoked_at: nil,
                  ))
                f16_token.rotate_refresh_token! unless f16_token.device_session_record.current_refresh_token_id
                f16_now = Time.current
                f16_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f16_token, oidc_client_id: f16_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f16_now,
                  refresh_token_expires_at: f16_now + 10.minutes,
                )
                f16_access = AuthenticationTokenService.encode(
                  f16_token.actor_record, host: f16_host, resource_type: "client",
                                          session_public_id: f16_token.public_id,
                                          base_session_public_id: f16_token.public_id,
                                          oidc_sid: f16_session.public_id, oidc_jti: f16_session.oidc_jti,
                                          expires_at: f16_now + 10.minutes, scopes: %w(openid profile),
                                          issuer: OidcIssuer.for_client(f16_client), audiences: [f16_client.aud],
                                          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f16_client),
                                          subject: OidcSubject.for(
                                            f16_token.actor_record,
                                            resource_type: "client",
                                          ), client_id: f16_client.client_id,
                )
                @base_browser_rp_credentials[f16_key] =
                  [f16_access, f16_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f16_key]
                f16_access, f16_refresh = @base_browser_rp_credentials.fetch(f16_key)
                f16_cookie = [
                  f16_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f16_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f16_refresh)}",
                ].join("; ")
                f16_headers = f16_headers.merge(
                  "Cookie" => f16_cookie,
                  "HTTP_COOKIE" => f16_cookie,
                )
              end
            end
            f16_headers
          end
        fx16_harness.fetch("Cookie").split("; ").each do |pair|
          name, value = pair.split("=", 2)
          cookies[name] = Rack::Utils.unescape(value)
        end
        browser_headers.merge(fx16_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
      end
    get visa_app_oidc_logout_url(host: @host),
        params: { id_token_hint: id_token, post_logout_redirect_uri: redirect_uri, state: "xyz", ri: "jp" },
        headers: http_headers_17

    assert_response :see_other

    http_headers_16 =
      begin
        fx17_harness =
          begin
            f17_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
            f17_host = f17_headers["Host"]
            f17_route =
              begin
                Rails.application.routes.recognize_path("https://#{f17_host}/") if f17_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f17_family, f17_surface = f17_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f17_family) && f17_surface == "app"
              f17_client_id =
                case f17_family
                when "base" then "base-#{f17_surface}-ww"
                when "edit" then "edit-org-ww"
                else "#{f17_family}-#{f17_surface}"
                end
              f17_token = ClientToken.includes(
                :user,
                :device_session,
              ).find_by!(public_id: f17_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f17_client = OidcClientRegistry.find!(f17_client_id)
              f17_key = [f17_client.client_id, f17_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f17_key] && f17_token.currently_usable? &&
                  !(f17_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f17_token.device_session_id,
                    oidc_client_id: f17_client.client_id,
                    revoked_at: nil,
                  ))
                f17_token.rotate_refresh_token! unless f17_token.device_session_record.current_refresh_token_id
                f17_now = Time.current
                f17_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f17_token, oidc_client_id: f17_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f17_now,
                  refresh_token_expires_at: f17_now + 10.minutes,
                )
                f17_access = AuthenticationTokenService.encode(
                  f17_token.actor_record, host: f17_host, resource_type: "client",
                                          session_public_id: f17_token.public_id,
                                          base_session_public_id: f17_token.public_id,
                                          oidc_sid: f17_session.public_id, oidc_jti: f17_session.oidc_jti,
                                          expires_at: f17_now + 10.minutes, scopes: %w(openid profile),
                                          issuer: OidcIssuer.for_client(f17_client), audiences: [f17_client.aud],
                                          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f17_client),
                                          subject: OidcSubject.for(
                                            f17_token.actor_record,
                                            resource_type: "client",
                                          ), client_id: f17_client.client_id,
                )
                @base_browser_rp_credentials[f17_key] = [f17_access, f17_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f17_key]
                f17_access, f17_refresh = @base_browser_rp_credentials.fetch(f17_key)
                f17_cookie = [
                  f17_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f17_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f17_refresh)}",
                ].join("; ")
                f17_headers = f17_headers.merge(
                  "Cookie" => f17_cookie,
                  "HTTP_COOKIE" => f17_cookie,
                )
              end
            end
            f17_headers
          end
        fx17_harness.fetch("Cookie").split("; ").each do |pair|
          name, value = pair.split("=", 2)
          cookies[name] = Rack::Utils.unescape(value)
        end
        browser_headers.merge(fx17_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
      end
    get visa_app_oidc_logout_url(host: @host), params: { ri: "jp" }, headers: http_headers_16

    assert_response :ok
    assert_not_predicate @token.reload, :revoked?
    assert_nil response.location
  end

  test "POST after the staged request expires fails gracefully instead of crashing" do
    redirect_uri = @client.post_logout_redirect_uris.first

    http_headers_15 =
      begin
        fx18_harness =
          begin
            f18_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
            f18_host = f18_headers["Host"]
            f18_route =
              begin
                Rails.application.routes.recognize_path("https://#{f18_host}/") if f18_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f18_family, f18_surface = f18_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f18_family) && f18_surface == "app"
              f18_client_id =
                case f18_family
                when "base" then "base-#{f18_surface}-ww"
                when "edit" then "edit-org-ww"
                else "#{f18_family}-#{f18_surface}"
                end
              f18_token = ClientToken.includes(
                :user,
                :device_session,
              ).find_by!(public_id: f18_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f18_client = OidcClientRegistry.find!(f18_client_id)
              f18_key = [f18_client.client_id, f18_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f18_key] && f18_token.currently_usable? &&
                  !(f18_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f18_token.device_session_id,
                    oidc_client_id: f18_client.client_id,
                    revoked_at: nil,
                  ))
                f18_token.rotate_refresh_token! unless f18_token.device_session_record.current_refresh_token_id
                f18_now = Time.current
                f18_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f18_token, oidc_client_id: f18_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f18_now,
                  refresh_token_expires_at: f18_now + 10.minutes,
                )
                f18_access = AuthenticationTokenService.encode(
                  f18_token.actor_record, host: f18_host, resource_type: "client",
                                          session_public_id: f18_token.public_id,
                                          base_session_public_id: f18_token.public_id,
                                          oidc_sid: f18_session.public_id, oidc_jti: f18_session.oidc_jti,
                                          expires_at: f18_now + 10.minutes, scopes: %w(openid profile),
                                          issuer: OidcIssuer.for_client(f18_client), audiences: [f18_client.aud],
                                          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f18_client),
                                          subject: OidcSubject.for(
                                            f18_token.actor_record,
                                            resource_type: "client",
                                          ), client_id: f18_client.client_id,
                )
                @base_browser_rp_credentials[f18_key] =
                  [f18_access, f18_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f18_key]
                f18_access, f18_refresh = @base_browser_rp_credentials.fetch(f18_key)
                f18_cookie = [
                  f18_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f18_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f18_refresh)}",
                ].join("; ")
                f18_headers = f18_headers.merge(
                  "Cookie" => f18_cookie,
                  "HTTP_COOKIE" => f18_cookie,
                )
              end
            end
            f18_headers
          end
        fx18_harness.fetch("Cookie").split("; ").each do |pair|
          name, value = pair.split("=", 2)
          cookies[name] = Rack::Utils.unescape(value)
        end
        browser_headers.merge(fx18_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
      end
    get visa_app_oidc_logout_url(host: @host),
        params: { id_token_hint: id_token, post_logout_redirect_uri: redirect_uri, state: "xyz", ri: "jp" },
        headers: http_headers_15

    assert_response :see_other

    travel 6.minutes do
      http_headers_14 =
        begin
          fx19_harness =
            begin
              f19_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
              f19_host = f19_headers["Host"]
              f19_route =
                begin
                  Rails.application.routes.recognize_path("https://#{f19_host}/") if f19_host.present?
                rescue ActionController::RoutingError
                  nil
                end
              f19_family, f19_surface = f19_route&.fetch(:controller)&.split("/")
              if %w(base warp core edit).include?(f19_family) && f19_surface == "app"
                f19_client_id =
                  case f19_family
                  when "base" then "base-#{f19_surface}-ww"
                  when "edit" then "edit-org-ww"
                  else "#{f19_family}-#{f19_surface}"
                  end
                f19_token = ClientToken.includes(
                  :user,
                  :device_session,
                ).find_by!(public_id: f19_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                f19_client = OidcClientRegistry.find!(f19_client_id)
                f19_key = [f19_client.client_id, f19_token.public_id]
                @base_browser_rp_credentials ||= {}
                if !@base_browser_rp_credentials[f19_key] && f19_token.currently_usable? &&
                    !(f19_token.device_session_id && OpAppGrant.exists?(
                      device_session_id: f19_token.device_session_id,
                      oidc_client_id: f19_client.client_id,
                      revoked_at: nil,
                    ))
                  f19_token.rotate_refresh_token! unless f19_token.device_session_record.current_refresh_token_id
                  f19_now = Time.current
                  f19_session = OpAppGrant.create!(
                    authentication_epoch: 0,
                    client_token: f19_token, oidc_client_id: f19_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f19_now,
                    refresh_token_expires_at: f19_now + 10.minutes,
                  )
                  f19_access = AuthenticationTokenService.encode(
                    f19_token.actor_record, host: f19_host, resource_type: "client",
                                            session_public_id: f19_token.public_id,
                                            base_session_public_id: f19_token.public_id,
                                            oidc_sid: f19_session.public_id, oidc_jti: f19_session.oidc_jti,
                                            expires_at: f19_now + 10.minutes, scopes: %w(openid profile),
                                            issuer: OidcIssuer.for_client(f19_client), audiences: [f19_client.aud],
                                            jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f19_client),
                                            subject: OidcSubject.for(
                                              f19_token.actor_record,
                                              resource_type: "client",
                                            ), client_id: f19_client.client_id,
                  )
                  @base_browser_rp_credentials[f19_key] = [f19_access, f19_session.issue_refresh_token!]
                end
                if @base_browser_rp_credentials[f19_key]
                  f19_access, f19_refresh = @base_browser_rp_credentials.fetch(f19_key)
                  f19_cookie = [
                    f19_headers.fetch("Cookie"),
                    "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f19_access)}",
                    "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f19_refresh)}",
                  ].join("; ")
                  f19_headers = f19_headers.merge(
                    "Cookie" => f19_cookie,
                    "HTTP_COOKIE" => f19_cookie,
                  )
                end
              end
              f19_headers
            end
          fx19_harness.fetch("Cookie").split("; ").each do |pair|
            name, value = pair.split("=", 2)
            cookies[name] = Rack::Utils.unescape(value)
          end
          browser_headers.merge(fx19_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
        end
      post visa_app_oidc_logout_confirmation_path(host: @host, ri: "jp"), headers: http_headers_14

      assert_response :ok
      assert_not_predicate @token.reload, :revoked?
    end
  end

  test "D1 a valid hint without an IdP session stops without staging or redirecting" do
    redirect_uri = @client.post_logout_redirect_uris.first
    cookies.delete(AuthenticationBase::ACCESS_COOKIE_KEY)
    before_count = AcmeLogoutTransaction.count

    with_forgery_protection do
      get visa_app_oidc_logout_url(host: @host),
          params: {
            id_token_hint: id_token,
            post_logout_redirect_uri: redirect_uri,
            state: "should-not-echo",
            ri: "jp",
          },
          headers: browser_headers.merge("Host" => @host, "Sec-Fetch-Site" => "same-origin")
    end

    assert_response :bad_request
    assert_equal I18n.t("sign.shared.sign_out.idp_session_error"), response.body
    assert_nil response.location
    assert_includes response.headers["Cache-Control"].to_s, "no-store"
    assert_equal before_count, AcmeLogoutTransaction.count
    assert_nil session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]
    assert_not_predicate @token.reload, :revoked?
  end

  test "D1 JSON valid hint without an IdP session returns login_required without staging" do
    redirect_uri = @client.post_logout_redirect_uris.first
    cookies.delete(AuthenticationBase::ACCESS_COOKIE_KEY)
    before_count = AcmeLogoutTransaction.count

    with_forgery_protection do
      get visa_app_oidc_logout_url(host: @host, format: :json),
          params: { id_token_hint: id_token, post_logout_redirect_uri: redirect_uri, ri: "jp" },
          headers: browser_headers.merge("Host" => @host, "Sec-Fetch-Site" => "same-origin")
    end

    assert_response :bad_request
    assert_equal(
      {
        "error" => "login_required",
        "error_description" => I18n.t("sign.shared.sign_out.idp_session_error"),
      },
      response.parsed_body,
    )
    assert_nil response.location
    assert_includes response.headers["Cache-Control"].to_s, "no-store"
    assert_equal before_count, AcmeLogoutTransaction.count
    assert_nil session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]
    assert_not_predicate @token.reload, :revoked?
  end

  # D1: an id_token_hint is evidence of which RP session the RP wants ended, not authority for the
  # presenting browser to end it. These run with forgery protection on and a same-origin fetch so
  # that CSRF is satisfied and the target-authorization decision is what is exercised.
  test "D1 unauthenticated browser presenting another subject's hint does not end that subject's session" do
    other_user = clients(:two)
    other_token = ClientToken.create!(
      authentication_epoch: 0,
      user: other_user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    other_hint = id_token(
      resource: other_user, subject: OidcSubject.for(other_user, resource_type: "client"), sid: other_token.public_id,
    )
    cookies.delete(AuthenticationBase::ACCESS_COOKIE_KEY)
    unauthenticated_headers = browser_headers.merge("Host" => @host, "Sec-Fetch-Site" => "same-origin")
    redirect_uri = @client.post_logout_redirect_uris.first

    with_forgery_protection do
      get visa_app_oidc_logout_url(host: @host),
          params: { id_token_hint: other_hint, post_logout_redirect_uri: redirect_uri, ri: "jp" },
          headers: unauthenticated_headers
      follow_redirect!(headers: unauthenticated_headers) if response.redirect?

      post visa_app_oidc_logout_confirmation_path(host: @host, ri: "jp"), headers: unauthenticated_headers
    end

    assert_not_predicate other_token.reload, :revoked?
    assert_not_predicate @token.reload, :revoked?
  end

  test "D1 authenticated browser presenting another subject's hint ends neither session" do
    other_user = clients(:two)
    other_token = ClientToken.create!(
      authentication_epoch: 0,
      user: other_user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    other_hint = id_token(
      resource: other_user, subject: OidcSubject.for(other_user, resource_type: "client"), sid: other_token.public_id,
    )
    redirect_uri = @client.post_logout_redirect_uris.first

    with_forgery_protection do
      get visa_app_oidc_logout_url(host: @host),
          params: { id_token_hint: other_hint, post_logout_redirect_uri: redirect_uri, ri: "jp" },
          headers: begin
            fx20_harness =
              begin
                f20_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
                f20_host = f20_headers["Host"]
                f20_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{f20_host}/") if f20_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                f20_family, f20_surface = f20_route&.fetch(:controller)&.split("/")
                if %w(base warp core edit).include?(f20_family) && f20_surface == "app"
                  f20_client_id =
                    case f20_family
                    when "base" then "base-#{f20_surface}-ww"
                    when "edit" then "edit-org-ww"
                    else "#{f20_family}-#{f20_surface}"
                    end
                  f20_token = ClientToken.includes(
                    :user,
                    :device_session,
                  ).find_by!(public_id: f20_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  f20_client = OidcClientRegistry.find!(f20_client_id)
                  f20_key = [f20_client.client_id, f20_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[f20_key] && f20_token.currently_usable? &&
                      !(f20_token.device_session_id && OpAppGrant.exists?(
                        device_session_id: f20_token.device_session_id,
                        oidc_client_id: f20_client.client_id,
                        revoked_at: nil,
                      ))
                    f20_token.rotate_refresh_token! unless f20_token.device_session_record.current_refresh_token_id
                    f20_now = Time.current
                    f20_session = OpAppGrant.create!(
                      authentication_epoch: 0,
                      client_token: f20_token, oidc_client_id: f20_client.client_id, oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f20_now,
                      refresh_token_expires_at: f20_now + 10.minutes,
                    )
                    f20_access = AuthenticationTokenService.encode(
                      f20_token.actor_record,
                      host: f20_host,
                      resource_type: "client",
                      session_public_id: f20_token.public_id,
                      base_session_public_id: f20_token.public_id,
                      oidc_sid: f20_session.public_id,
                      oidc_jti: f20_session.oidc_jti,
                      expires_at: f20_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(f20_client),
                      audiences: [f20_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f20_client),
                      subject: OidcSubject.for(
                        f20_token.actor_record,
                        resource_type: "client",
                      ),
                      client_id: f20_client.client_id,
                    )
                    @base_browser_rp_credentials[f20_key] =
                      [f20_access, f20_session.issue_refresh_token!]
                  end
                  if @base_browser_rp_credentials[f20_key]
                    f20_access, f20_refresh = @base_browser_rp_credentials.fetch(f20_key)
                    f20_cookie = [
                      f20_headers.fetch("Cookie"),
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f20_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f20_refresh)}",
                    ].join("; ")
                    f20_headers = f20_headers.merge(
                      "Cookie" => f20_cookie,
                      "HTTP_COOKIE" => f20_cookie,
                    )
                  end
                end
                f20_headers
              end
            fx20_harness.fetch("Cookie").split("; ").each do |pair|
              name, value = pair.split("=", 2)
              cookies[name] = Rack::Utils.unescape(value)
            end
            browser_headers.merge(fx20_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
          end.merge("Sec-Fetch-Site" => "same-origin")

      assert_response :bad_request
      assert_equal I18n.t("sign.shared.sign_out.idp_session_error"), response.body
      assert_nil response.location
      assert_includes response.headers["Cache-Control"].to_s, "no-store"

      post visa_app_oidc_logout_url(host: @host),
           params: { id_token_hint: other_hint, post_logout_redirect_uri: redirect_uri, ri: "jp" },
           headers: begin
             fx21_harness =
               begin
                 f21_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
                 f21_host = f21_headers["Host"]
                 f21_route =
                   begin
                     Rails.application.routes.recognize_path("https://#{f21_host}/") if f21_host.present?
                   rescue ActionController::RoutingError
                     nil
                   end
                 f21_family, f21_surface = f21_route&.fetch(:controller)&.split("/")
                 if %w(base warp core edit).include?(f21_family) && f21_surface == "app"
                   f21_client_id =
                     case f21_family
                     when "base" then "base-#{f21_surface}-ww"
                     when "edit" then "edit-org-ww"
                     else "#{f21_family}-#{f21_surface}"
                     end
                   f21_token = ClientToken.includes(
                     :user,
                     :device_session,
                   ).find_by!(public_id: f21_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                   f21_client = OidcClientRegistry.find!(f21_client_id)
                   f21_key = [f21_client.client_id, f21_token.public_id]
                   @base_browser_rp_credentials ||= {}
                   if !@base_browser_rp_credentials[f21_key] && f21_token.currently_usable? &&
                       !(f21_token.device_session_id && OpAppGrant.exists?(
                         device_session_id: f21_token.device_session_id,
                         oidc_client_id: f21_client.client_id,
                         revoked_at: nil,
                       ))
                     f21_token.rotate_refresh_token! unless f21_token.device_session_record.current_refresh_token_id
                     f21_now = Time.current
                     f21_session = OpAppGrant.create!(
                       authentication_epoch: 0,
                       client_token: f21_token, oidc_client_id: f21_client.client_id, oidc_scope: "openid profile",
                       oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f21_now,
                       refresh_token_expires_at: f21_now + 10.minutes,
                     )
                     f21_access = AuthenticationTokenService.encode(
                       f21_token.actor_record,
                       host: f21_host,
                       resource_type: "client",
                       session_public_id: f21_token.public_id,
                       base_session_public_id: f21_token.public_id,
                       oidc_sid: f21_session.public_id,
                       oidc_jti: f21_session.oidc_jti,
                       expires_at: f21_now + 10.minutes,
                       scopes: %w(openid profile),
                       issuer: OidcIssuer.for_client(f21_client),
                       audiences: [f21_client.aud],
                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f21_client),
                       subject: OidcSubject.for(
                         f21_token.actor_record,
                         resource_type: "client",
                       ),
                       client_id: f21_client.client_id,
                     )
                     @base_browser_rp_credentials[f21_key] =
                       [f21_access, f21_session.issue_refresh_token!]
                   end
                   if @base_browser_rp_credentials[f21_key]
                     f21_access, f21_refresh = @base_browser_rp_credentials.fetch(f21_key)
                     f21_cookie = [
                       f21_headers.fetch("Cookie"),
                       "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f21_access)}",
                       "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f21_refresh)}",
                     ].join("; ")
                     f21_headers = f21_headers.merge(
                       "Cookie" => f21_cookie,
                       "HTTP_COOKIE" => f21_cookie,
                     )
                   end
                 end
                 f21_headers
               end
             fx21_harness.fetch("Cookie").split("; ").each do |pair|
               name, value = pair.split("=", 2)
               cookies[name] = Rack::Utils.unescape(value)
             end
             browser_headers.merge(fx21_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
           end.merge("Sec-Fetch-Site" => "same-origin")
    end

    assert_not_predicate other_token.reload, :revoked?
    assert_not_predicate @token.reload, :revoked?
  end

  test "D-33 uses the authenticated OP Root Session when the RP hint carries another sid" do
    sibling_token = ClientToken.create!(
      authentication_epoch: 0,
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    redirect_uri = @client.post_logout_redirect_uris.first
    headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id).except("Cookie", "HTTP_COOKIE")

    get visa_app_oidc_logout_url(host: @host),
        params: {
          id_token_hint: id_token(sid: sibling_token.public_id),
          post_logout_redirect_uri: redirect_uri,
          state: "same-subject-rp-hint",
          ri: "jp",
        },
        headers: headers

    assert_response :see_other
    assert_not_predicate @token.reload, :revoked?
    assert_equal @session_public_id, session.dig(SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY, "sid")
    assert_not_predicate sibling_token.reload, :revoked?
    assert_equal redirect_uri, session.dig(SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY, "post_logout_redirect_uri")

    post visa_app_oidc_logout_confirmation_path(host: @host, ri: "jp"), headers: headers

    assert_response :see_other
    assert_predicate @token.reload, :revoked?
    assert_not_predicate sibling_token.reload, :revoked?
  end

  test "D1 access token without sid cannot use its own subject's hint to end a sibling session" do
    sibling_token = ClientToken.create!(
      authentication_epoch: 0,
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = AuthenticationToken.encode(
      @user, host: @host, resource_type: "client", jwt_issuer_id: "surface:VISA_APP",
    )
    headers = browser_headers.merge("Host" => @host, "Sec-Fetch-Site" => "same-origin")
    redirect_uri = @client.post_logout_redirect_uris.first

    with_forgery_protection do
      get visa_app_oidc_logout_url(host: @host),
          params: {
            id_token_hint: id_token(sid: sibling_token.public_id), post_logout_redirect_uri: redirect_uri, ri: "jp",
          },
          headers: headers

      assert_response :bad_request
      assert_equal I18n.t("sign.shared.sign_out.idp_session_error"), response.body
      assert_nil session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]
      post visa_app_oidc_logout_confirmation_path(host: @host, ri: "jp"), headers: headers
    end

    assert_not_predicate sibling_token.reload, :revoked?
  end

  test "D1 swapping in another subject's hint on the POST ends neither session" do
    other_user = clients(:two)
    other_token = ClientToken.create!(
      authentication_epoch: 0,
      user: other_user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    other_hint = id_token(
      resource: other_user, subject: OidcSubject.for(other_user, resource_type: "client"), sid: other_token.public_id,
    )
    redirect_uri = @client.post_logout_redirect_uris.first

    with_forgery_protection do
      get visa_app_oidc_logout_url(host: @host),
          params: { id_token_hint: id_token, post_logout_redirect_uri: redirect_uri, ri: "jp" },
          headers: begin
            fx24_harness =
              begin
                f24_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
                f24_host = f24_headers["Host"]
                f24_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{f24_host}/") if f24_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                f24_family, f24_surface = f24_route&.fetch(:controller)&.split("/")
                if %w(base warp core edit).include?(f24_family) && f24_surface == "app"
                  f24_client_id =
                    case f24_family
                    when "base" then "base-#{f24_surface}-ww"
                    when "edit" then "edit-org-ww"
                    else "#{f24_family}-#{f24_surface}"
                    end
                  f24_token = ClientToken.includes(
                    :user,
                    :device_session,
                  ).find_by!(public_id: f24_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  f24_client = OidcClientRegistry.find!(f24_client_id)
                  f24_key = [f24_client.client_id, f24_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[f24_key] && f24_token.currently_usable? &&
                      !(f24_token.device_session_id && OpAppGrant.exists?(
                        device_session_id: f24_token.device_session_id,
                        oidc_client_id: f24_client.client_id,
                        revoked_at: nil,
                      ))
                    f24_token.rotate_refresh_token! unless f24_token.device_session_record.current_refresh_token_id
                    f24_now = Time.current
                    f24_session = OpAppGrant.create!(
                      authentication_epoch: 0,
                      client_token: f24_token, oidc_client_id: f24_client.client_id, oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f24_now,
                      refresh_token_expires_at: f24_now + 10.minutes,
                    )
                    f24_access = AuthenticationTokenService.encode(
                      f24_token.actor_record,
                      host: f24_host,
                      resource_type: "client",
                      session_public_id: f24_token.public_id,
                      base_session_public_id: f24_token.public_id,
                      oidc_sid: f24_session.public_id,
                      oidc_jti: f24_session.oidc_jti,
                      expires_at: f24_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(f24_client),
                      audiences: [f24_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f24_client),
                      subject: OidcSubject.for(
                        f24_token.actor_record,
                        resource_type: "client",
                      ),
                      client_id: f24_client.client_id,
                    )
                    @base_browser_rp_credentials[f24_key] =
                      [f24_access, f24_session.issue_refresh_token!]
                  end
                  if @base_browser_rp_credentials[f24_key]
                    f24_access, f24_refresh = @base_browser_rp_credentials.fetch(f24_key)
                    f24_cookie = [
                      f24_headers.fetch("Cookie"),
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f24_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f24_refresh)}",
                    ].join("; ")
                    f24_headers = f24_headers.merge(
                      "Cookie" => f24_cookie,
                      "HTTP_COOKIE" => f24_cookie,
                    )
                  end
                end
                f24_headers
              end
            fx24_harness.fetch("Cookie").split("; ").each do |pair|
              name, value = pair.split("=", 2)
              cookies[name] = Rack::Utils.unescape(value)
            end
            browser_headers.merge(fx24_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
          end.merge("Sec-Fetch-Site" => "same-origin")
      post visa_app_oidc_logout_url(host: @host),
           params: { id_token_hint: other_hint },
           headers: begin
             fx25_harness =
               begin
                 f25_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
                 f25_host = f25_headers["Host"]
                 f25_route =
                   begin
                     Rails.application.routes.recognize_path("https://#{f25_host}/") if f25_host.present?
                   rescue ActionController::RoutingError
                     nil
                   end
                 f25_family, f25_surface = f25_route&.fetch(:controller)&.split("/")
                 if %w(base warp core edit).include?(f25_family) && f25_surface == "app"
                   f25_client_id =
                     case f25_family
                     when "base" then "base-#{f25_surface}-ww"
                     when "edit" then "edit-org-ww"
                     else "#{f25_family}-#{f25_surface}"
                     end
                   f25_token = ClientToken.includes(
                     :user,
                     :device_session,
                   ).find_by!(public_id: f25_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                   f25_client = OidcClientRegistry.find!(f25_client_id)
                   f25_key = [f25_client.client_id, f25_token.public_id]
                   @base_browser_rp_credentials ||= {}
                   if !@base_browser_rp_credentials[f25_key] && f25_token.currently_usable? &&
                       !(f25_token.device_session_id && OpAppGrant.exists?(
                         device_session_id: f25_token.device_session_id,
                         oidc_client_id: f25_client.client_id,
                         revoked_at: nil,
                       ))
                     f25_token.rotate_refresh_token! unless f25_token.device_session_record.current_refresh_token_id
                     f25_now = Time.current
                     f25_session = OpAppGrant.create!(
                       authentication_epoch: 0,
                       client_token: f25_token, oidc_client_id: f25_client.client_id, oidc_scope: "openid profile",
                       oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f25_now,
                       refresh_token_expires_at: f25_now + 10.minutes,
                     )
                     f25_access = AuthenticationTokenService.encode(
                       f25_token.actor_record,
                       host: f25_host,
                       resource_type: "client",
                       session_public_id: f25_token.public_id,
                       base_session_public_id: f25_token.public_id,
                       oidc_sid: f25_session.public_id,
                       oidc_jti: f25_session.oidc_jti,
                       expires_at: f25_now + 10.minutes,
                       scopes: %w(openid profile),
                       issuer: OidcIssuer.for_client(f25_client),
                       audiences: [f25_client.aud],
                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f25_client),
                       subject: OidcSubject.for(
                         f25_token.actor_record,
                         resource_type: "client",
                       ),
                       client_id: f25_client.client_id,
                     )
                     @base_browser_rp_credentials[f25_key] =
                       [f25_access, f25_session.issue_refresh_token!]
                   end
                   if @base_browser_rp_credentials[f25_key]
                     f25_access, f25_refresh = @base_browser_rp_credentials.fetch(f25_key)
                     f25_cookie = [
                       f25_headers.fetch("Cookie"),
                       "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f25_access)}",
                       "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f25_refresh)}",
                     ].join("; ")
                     f25_headers = f25_headers.merge(
                       "Cookie" => f25_cookie,
                       "HTTP_COOKIE" => f25_cookie,
                     )
                   end
                 end
                 f25_headers
               end
             fx25_harness.fetch("Cookie").split("; ").each do |pair|
               name, value = pair.split("=", 2)
               cookies[name] = Rack::Utils.unescape(value)
             end
             browser_headers.merge(fx25_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
           end.merge("Sec-Fetch-Site" => "same-origin")
    end

    assert_not_predicate other_token.reload, :revoked?
    assert_not_predicate @token.reload, :revoked?
  end

  # BVA on the 5-minute staged-request lifetime: the stored expires_at is second-precision ISO 8601
  # and must be strictly in the future, so 4:59 is the last accepted second and 5:00 is refused.
  test "D1 staged logout POST one second before the 5-minute expiry ends the session" do
    redirect_uri = @client.post_logout_redirect_uris.first
    freeze_time

    http_headers_13 =
      begin
        fx26_harness =
          begin
            f26_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
            f26_host = f26_headers["Host"]
            f26_route =
              begin
                Rails.application.routes.recognize_path("https://#{f26_host}/") if f26_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f26_family, f26_surface = f26_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f26_family) && f26_surface == "app"
              f26_client_id =
                case f26_family
                when "base" then "base-#{f26_surface}-ww"
                when "edit" then "edit-org-ww"
                else "#{f26_family}-#{f26_surface}"
                end
              f26_token = ClientToken.includes(
                :user,
                :device_session,
              ).find_by!(public_id: f26_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f26_client = OidcClientRegistry.find!(f26_client_id)
              f26_key = [f26_client.client_id, f26_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f26_key] && f26_token.currently_usable? &&
                  !(f26_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f26_token.device_session_id,
                    oidc_client_id: f26_client.client_id,
                    revoked_at: nil,
                  ))
                f26_token.rotate_refresh_token! unless f26_token.device_session_record.current_refresh_token_id
                f26_now = Time.current
                f26_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f26_token, oidc_client_id: f26_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f26_now,
                  refresh_token_expires_at: f26_now + 10.minutes,
                )
                f26_access = AuthenticationTokenService.encode(
                  f26_token.actor_record, host: f26_host, resource_type: "client",
                                          session_public_id: f26_token.public_id,
                                          base_session_public_id: f26_token.public_id,
                                          oidc_sid: f26_session.public_id, oidc_jti: f26_session.oidc_jti,
                                          expires_at: f26_now + 10.minutes, scopes: %w(openid profile),
                                          issuer: OidcIssuer.for_client(f26_client), audiences: [f26_client.aud],
                                          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f26_client),
                                          subject: OidcSubject.for(
                                            f26_token.actor_record,
                                            resource_type: "client",
                                          ), client_id: f26_client.client_id,
                )
                @base_browser_rp_credentials[f26_key] =
                  [f26_access, f26_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f26_key]
                f26_access, f26_refresh = @base_browser_rp_credentials.fetch(f26_key)
                f26_cookie = [
                  f26_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f26_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f26_refresh)}",
                ].join("; ")
                f26_headers = f26_headers.merge(
                  "Cookie" => f26_cookie,
                  "HTTP_COOKIE" => f26_cookie,
                )
              end
            end
            f26_headers
          end
        fx26_harness.fetch("Cookie").split("; ").each do |pair|
          name, value = pair.split("=", 2)
          cookies[name] = Rack::Utils.unescape(value)
        end
        browser_headers.merge(fx26_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
      end
    get visa_app_oidc_logout_url(host: @host),
        params: { id_token_hint: id_token, post_logout_redirect_uri: redirect_uri, ri: "jp" },
        headers: http_headers_13

    travel 4.minutes + 59.seconds
    http_headers_12 =
      begin
        fx27_harness =
          begin
            f27_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
            f27_host = f27_headers["Host"]
            f27_route =
              begin
                Rails.application.routes.recognize_path("https://#{f27_host}/") if f27_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f27_family, f27_surface = f27_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f27_family) && f27_surface == "app"
              f27_client_id =
                case f27_family
                when "base" then "base-#{f27_surface}-ww"
                when "edit" then "edit-org-ww"
                else "#{f27_family}-#{f27_surface}"
                end
              f27_token = ClientToken.includes(
                :user,
                :device_session,
              ).find_by!(public_id: f27_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f27_client = OidcClientRegistry.find!(f27_client_id)
              f27_key = [f27_client.client_id, f27_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f27_key] && f27_token.currently_usable? &&
                  !(f27_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f27_token.device_session_id,
                    oidc_client_id: f27_client.client_id,
                    revoked_at: nil,
                  ))
                f27_token.rotate_refresh_token! unless f27_token.device_session_record.current_refresh_token_id
                f27_now = Time.current
                f27_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f27_token, oidc_client_id: f27_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f27_now,
                  refresh_token_expires_at: f27_now + 10.minutes,
                )
                f27_access = AuthenticationTokenService.encode(
                  f27_token.actor_record, host: f27_host, resource_type: "client",
                                          session_public_id: f27_token.public_id,
                                          base_session_public_id: f27_token.public_id,
                                          oidc_sid: f27_session.public_id, oidc_jti: f27_session.oidc_jti,
                                          expires_at: f27_now + 10.minutes, scopes: %w(openid profile),
                                          issuer: OidcIssuer.for_client(f27_client), audiences: [f27_client.aud],
                                          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f27_client),
                                          subject: OidcSubject.for(
                                            f27_token.actor_record,
                                            resource_type: "client",
                                          ), client_id: f27_client.client_id,
                )
                @base_browser_rp_credentials[f27_key] = [f27_access, f27_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f27_key]
                f27_access, f27_refresh = @base_browser_rp_credentials.fetch(f27_key)
                f27_cookie = [
                  f27_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f27_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f27_refresh)}",
                ].join("; ")
                f27_headers = f27_headers.merge(
                  "Cookie" => f27_cookie,
                  "HTTP_COOKIE" => f27_cookie,
                )
              end
            end
            f27_headers
          end
        fx27_harness.fetch("Cookie").split("; ").each do |pair|
          name, value = pair.split("=", 2)
          cookies[name] = Rack::Utils.unescape(value)
        end
        browser_headers.merge(fx27_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
      end
    post visa_app_oidc_logout_confirmation_path(host: @host, ri: "jp"), headers: http_headers_12

    assert_response :see_other
    assert_predicate @token.reload, :revoked?
  end

  test "D1 staged logout POST exactly at the 5-minute expiry does not end the session" do
    redirect_uri = @client.post_logout_redirect_uris.first
    freeze_time

    http_headers_11 =
      begin
        fx28_harness =
          begin
            f28_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
            f28_host = f28_headers["Host"]
            f28_route =
              begin
                Rails.application.routes.recognize_path("https://#{f28_host}/") if f28_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f28_family, f28_surface = f28_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f28_family) && f28_surface == "app"
              f28_client_id =
                case f28_family
                when "base" then "base-#{f28_surface}-ww"
                when "edit" then "edit-org-ww"
                else "#{f28_family}-#{f28_surface}"
                end
              f28_token = ClientToken.includes(
                :user,
                :device_session,
              ).find_by!(public_id: f28_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f28_client = OidcClientRegistry.find!(f28_client_id)
              f28_key = [f28_client.client_id, f28_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f28_key] && f28_token.currently_usable? &&
                  !(f28_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f28_token.device_session_id,
                    oidc_client_id: f28_client.client_id,
                    revoked_at: nil,
                  ))
                f28_token.rotate_refresh_token! unless f28_token.device_session_record.current_refresh_token_id
                f28_now = Time.current
                f28_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f28_token, oidc_client_id: f28_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f28_now,
                  refresh_token_expires_at: f28_now + 10.minutes,
                )
                f28_access = AuthenticationTokenService.encode(
                  f28_token.actor_record, host: f28_host, resource_type: "client",
                                          session_public_id: f28_token.public_id,
                                          base_session_public_id: f28_token.public_id,
                                          oidc_sid: f28_session.public_id, oidc_jti: f28_session.oidc_jti,
                                          expires_at: f28_now + 10.minutes, scopes: %w(openid profile),
                                          issuer: OidcIssuer.for_client(f28_client), audiences: [f28_client.aud],
                                          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f28_client),
                                          subject: OidcSubject.for(
                                            f28_token.actor_record,
                                            resource_type: "client",
                                          ), client_id: f28_client.client_id,
                )
                @base_browser_rp_credentials[f28_key] =
                  [f28_access, f28_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f28_key]
                f28_access, f28_refresh = @base_browser_rp_credentials.fetch(f28_key)
                f28_cookie = [
                  f28_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f28_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f28_refresh)}",
                ].join("; ")
                f28_headers = f28_headers.merge(
                  "Cookie" => f28_cookie,
                  "HTTP_COOKIE" => f28_cookie,
                )
              end
            end
            f28_headers
          end
        fx28_harness.fetch("Cookie").split("; ").each do |pair|
          name, value = pair.split("=", 2)
          cookies[name] = Rack::Utils.unescape(value)
        end
        browser_headers.merge(fx28_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
      end
    get visa_app_oidc_logout_url(host: @host),
        params: { id_token_hint: id_token, post_logout_redirect_uri: redirect_uri, ri: "jp" },
        headers: http_headers_11

    travel 5.minutes
    http_headers_10 =
      begin
        fx29_harness =
          begin
            f29_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
            f29_host = f29_headers["Host"]
            f29_route =
              begin
                Rails.application.routes.recognize_path("https://#{f29_host}/") if f29_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f29_family, f29_surface = f29_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f29_family) && f29_surface == "app"
              f29_client_id =
                case f29_family
                when "base" then "base-#{f29_surface}-ww"
                when "edit" then "edit-org-ww"
                else "#{f29_family}-#{f29_surface}"
                end
              f29_token = ClientToken.includes(
                :user,
                :device_session,
              ).find_by!(public_id: f29_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f29_client = OidcClientRegistry.find!(f29_client_id)
              f29_key = [f29_client.client_id, f29_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f29_key] && f29_token.currently_usable? &&
                  !(f29_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f29_token.device_session_id,
                    oidc_client_id: f29_client.client_id,
                    revoked_at: nil,
                  ))
                f29_token.rotate_refresh_token! unless f29_token.device_session_record.current_refresh_token_id
                f29_now = Time.current
                f29_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f29_token, oidc_client_id: f29_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f29_now,
                  refresh_token_expires_at: f29_now + 10.minutes,
                )
                f29_access = AuthenticationTokenService.encode(
                  f29_token.actor_record, host: f29_host, resource_type: "client",
                                          session_public_id: f29_token.public_id,
                                          base_session_public_id: f29_token.public_id,
                                          oidc_sid: f29_session.public_id, oidc_jti: f29_session.oidc_jti,
                                          expires_at: f29_now + 10.minutes, scopes: %w(openid profile),
                                          issuer: OidcIssuer.for_client(f29_client), audiences: [f29_client.aud],
                                          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f29_client),
                                          subject: OidcSubject.for(
                                            f29_token.actor_record,
                                            resource_type: "client",
                                          ), client_id: f29_client.client_id,
                )
                @base_browser_rp_credentials[f29_key] = [f29_access, f29_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f29_key]
                f29_access, f29_refresh = @base_browser_rp_credentials.fetch(f29_key)
                f29_cookie = [
                  f29_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f29_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f29_refresh)}",
                ].join("; ")
                f29_headers = f29_headers.merge(
                  "Cookie" => f29_cookie,
                  "HTTP_COOKIE" => f29_cookie,
                )
              end
            end
            f29_headers
          end
        fx29_harness.fetch("Cookie").split("; ").each do |pair|
          name, value = pair.split("=", 2)
          cookies[name] = Rack::Utils.unescape(value)
        end
        browser_headers.merge(fx29_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
      end
    post visa_app_oidc_logout_confirmation_path(host: @host, ri: "jp"), headers: http_headers_10

    assert_response :ok
    assert_not_predicate @token.reload, :revoked?
  end

  test "D1 replaying a completed logout POST does not end a session created afterwards" do
    redirect_uri = @client.post_logout_redirect_uris.first
    http_headers_9 =
      begin
        fx30_harness =
          begin
            f30_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
            f30_host = f30_headers["Host"]
            f30_route =
              begin
                Rails.application.routes.recognize_path("https://#{f30_host}/") if f30_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f30_family, f30_surface = f30_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f30_family) && f30_surface == "app"
              f30_client_id =
                case f30_family
                when "base" then "base-#{f30_surface}-ww"
                when "edit" then "edit-org-ww"
                else "#{f30_family}-#{f30_surface}"
                end
              f30_token = ClientToken.includes(
                :user,
                :device_session,
              ).find_by!(public_id: f30_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f30_client = OidcClientRegistry.find!(f30_client_id)
              f30_key = [f30_client.client_id, f30_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f30_key] && f30_token.currently_usable? &&
                  !(f30_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f30_token.device_session_id,
                    oidc_client_id: f30_client.client_id,
                    revoked_at: nil,
                  ))
                f30_token.rotate_refresh_token! unless f30_token.device_session_record.current_refresh_token_id
                f30_now = Time.current
                f30_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f30_token, oidc_client_id: f30_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f30_now,
                  refresh_token_expires_at: f30_now + 10.minutes,
                )
                f30_access = AuthenticationTokenService.encode(
                  f30_token.actor_record, host: f30_host, resource_type: "client",
                                          session_public_id: f30_token.public_id,
                                          base_session_public_id: f30_token.public_id,
                                          oidc_sid: f30_session.public_id, oidc_jti: f30_session.oidc_jti,
                                          expires_at: f30_now + 10.minutes, scopes: %w(openid profile),
                                          issuer: OidcIssuer.for_client(f30_client), audiences: [f30_client.aud],
                                          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f30_client),
                                          subject: OidcSubject.for(
                                            f30_token.actor_record,
                                            resource_type: "client",
                                          ), client_id: f30_client.client_id,
                )
                @base_browser_rp_credentials[f30_key] =
                  [f30_access, f30_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f30_key]
                f30_access, f30_refresh = @base_browser_rp_credentials.fetch(f30_key)
                f30_cookie = [
                  f30_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f30_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f30_refresh)}",
                ].join("; ")
                f30_headers = f30_headers.merge(
                  "Cookie" => f30_cookie,
                  "HTTP_COOKIE" => f30_cookie,
                )
              end
            end
            f30_headers
          end
        fx30_harness.fetch("Cookie").split("; ").each do |pair|
          name, value = pair.split("=", 2)
          cookies[name] = Rack::Utils.unescape(value)
        end
        browser_headers.merge(fx30_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
      end
    get visa_app_oidc_logout_url(host: @host),
        params: { id_token_hint: id_token, post_logout_redirect_uri: redirect_uri, ri: "jp" },
        headers: http_headers_9
    http_headers_8 =
      begin
        fx31_harness =
          begin
            f31_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
            f31_host = f31_headers["Host"]
            f31_route =
              begin
                Rails.application.routes.recognize_path("https://#{f31_host}/") if f31_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f31_family, f31_surface = f31_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f31_family) && f31_surface == "app"
              f31_client_id =
                case f31_family
                when "base" then "base-#{f31_surface}-ww"
                when "edit" then "edit-org-ww"
                else "#{f31_family}-#{f31_surface}"
                end
              f31_token = ClientToken.includes(
                :user,
                :device_session,
              ).find_by!(public_id: f31_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f31_client = OidcClientRegistry.find!(f31_client_id)
              f31_key = [f31_client.client_id, f31_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f31_key] && f31_token.currently_usable? &&
                  !(f31_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f31_token.device_session_id,
                    oidc_client_id: f31_client.client_id,
                    revoked_at: nil,
                  ))
                f31_token.rotate_refresh_token! unless f31_token.device_session_record.current_refresh_token_id
                f31_now = Time.current
                f31_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f31_token, oidc_client_id: f31_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f31_now,
                  refresh_token_expires_at: f31_now + 10.minutes,
                )
                f31_access = AuthenticationTokenService.encode(
                  f31_token.actor_record, host: f31_host, resource_type: "client",
                                          session_public_id: f31_token.public_id,
                                          base_session_public_id: f31_token.public_id,
                                          oidc_sid: f31_session.public_id, oidc_jti: f31_session.oidc_jti,
                                          expires_at: f31_now + 10.minutes, scopes: %w(openid profile),
                                          issuer: OidcIssuer.for_client(f31_client), audiences: [f31_client.aud],
                                          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f31_client),
                                          subject: OidcSubject.for(
                                            f31_token.actor_record,
                                            resource_type: "client",
                                          ), client_id: f31_client.client_id,
                )
                @base_browser_rp_credentials[f31_key] = [f31_access, f31_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f31_key]
                f31_access, f31_refresh = @base_browser_rp_credentials.fetch(f31_key)
                f31_cookie = [
                  f31_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f31_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f31_refresh)}",
                ].join("; ")
                f31_headers = f31_headers.merge(
                  "Cookie" => f31_cookie,
                  "HTTP_COOKIE" => f31_cookie,
                )
              end
            end
            f31_headers
          end
        fx31_harness.fetch("Cookie").split("; ").each do |pair|
          name, value = pair.split("=", 2)
          cookies[name] = Rack::Utils.unescape(value)
        end
        browser_headers.merge(fx31_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
      end
    post visa_app_oidc_logout_confirmation_path(host: @host, ri: "jp"), headers: http_headers_8

    assert_predicate @token.reload, :revoked?

    new_token = ClientToken.create!(
      authentication_epoch: 0,
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    @session_public_id = new_token.public_id
    http_headers_7 =
      begin
        fx32_harness =
          begin
            f32_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
            f32_host = f32_headers["Host"]
            f32_route =
              begin
                Rails.application.routes.recognize_path("https://#{f32_host}/") if f32_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f32_family, f32_surface = f32_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f32_family) && f32_surface == "app"
              f32_client_id =
                case f32_family
                when "base" then "base-#{f32_surface}-ww"
                when "edit" then "edit-org-ww"
                else "#{f32_family}-#{f32_surface}"
                end
              f32_token = ClientToken.includes(
                :user,
                :device_session,
              ).find_by!(public_id: f32_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f32_client = OidcClientRegistry.find!(f32_client_id)
              f32_key = [f32_client.client_id, f32_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f32_key] && f32_token.currently_usable? &&
                  !(f32_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f32_token.device_session_id,
                    oidc_client_id: f32_client.client_id,
                    revoked_at: nil,
                  ))
                f32_token.rotate_refresh_token! unless f32_token.device_session_record.current_refresh_token_id
                f32_now = Time.current
                f32_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f32_token, oidc_client_id: f32_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f32_now,
                  refresh_token_expires_at: f32_now + 10.minutes,
                )
                f32_access = AuthenticationTokenService.encode(
                  f32_token.actor_record, host: f32_host, resource_type: "client",
                                          session_public_id: f32_token.public_id,
                                          base_session_public_id: f32_token.public_id,
                                          oidc_sid: f32_session.public_id, oidc_jti: f32_session.oidc_jti,
                                          expires_at: f32_now + 10.minutes, scopes: %w(openid profile),
                                          issuer: OidcIssuer.for_client(f32_client), audiences: [f32_client.aud],
                                          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f32_client),
                                          subject: OidcSubject.for(
                                            f32_token.actor_record,
                                            resource_type: "client",
                                          ), client_id: f32_client.client_id,
                )
                @base_browser_rp_credentials[f32_key] = [f32_access, f32_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f32_key]
                f32_access, f32_refresh = @base_browser_rp_credentials.fetch(f32_key)
                f32_cookie = [
                  f32_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f32_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f32_refresh)}",
                ].join("; ")
                f32_headers = f32_headers.merge(
                  "Cookie" => f32_cookie,
                  "HTTP_COOKIE" => f32_cookie,
                )
              end
            end
            f32_headers
          end
        fx32_harness.fetch("Cookie").split("; ").each do |pair|
          name, value = pair.split("=", 2)
          cookies[name] = Rack::Utils.unescape(value)
        end
        browser_headers.merge(fx32_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
      end
    post visa_app_oidc_logout_confirmation_path(host: @host, ri: "jp"), headers: http_headers_7

    assert_response :ok
    assert_not_predicate new_token.reload, :revoked?
  end

  # Sentinels reaching the public parameter as HTTP values: omitted, empty string, array, hash, and a
  # NUL inside an otherwise valid token. JSON null is not representable in a form/query parameter.
  test "D1 malformed id_token_hint values never end a session" do
    redirect_uri = @client.post_logout_redirect_uris.first
    valid = id_token
    [
      { id_token_hint: [valid], post_logout_redirect_uri: redirect_uri, ri: "jp" },
      { id_token_hint: { "a" => valid }, post_logout_redirect_uri: redirect_uri, ri: "jp" },
      { id_token_hint: "#{valid}\u0000", post_logout_redirect_uri: redirect_uri, ri: "jp" },
    ].each do |params|
      http_headers_6 =
        begin
          fx33_harness =
            begin
              f33_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
              f33_host = f33_headers["Host"]
              f33_route =
                begin
                  Rails.application.routes.recognize_path("https://#{f33_host}/") if f33_host.present?
                rescue ActionController::RoutingError
                  nil
                end
              f33_family, f33_surface = f33_route&.fetch(:controller)&.split("/")
              if %w(base warp core edit).include?(f33_family) && f33_surface == "app"
                f33_client_id =
                  case f33_family
                  when "base" then "base-#{f33_surface}-ww"
                  when "edit" then "edit-org-ww"
                  else "#{f33_family}-#{f33_surface}"
                  end
                f33_token = ClientToken.includes(
                  :user,
                  :device_session,
                ).find_by!(public_id: f33_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                f33_client = OidcClientRegistry.find!(f33_client_id)
                f33_key = [f33_client.client_id, f33_token.public_id]
                @base_browser_rp_credentials ||= {}
                if !@base_browser_rp_credentials[f33_key] && f33_token.currently_usable? &&
                    !(f33_token.device_session_id && OpAppGrant.exists?(
                      device_session_id: f33_token.device_session_id,
                      oidc_client_id: f33_client.client_id,
                      revoked_at: nil,
                    ))
                  f33_token.rotate_refresh_token! unless f33_token.device_session_record.current_refresh_token_id
                  f33_now = Time.current
                  f33_session = OpAppGrant.create!(
                    authentication_epoch: 0,
                    client_token: f33_token, oidc_client_id: f33_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f33_now,
                    refresh_token_expires_at: f33_now + 10.minutes,
                  )
                  f33_access = AuthenticationTokenService.encode(
                    f33_token.actor_record, host: f33_host, resource_type: "client",
                                            session_public_id: f33_token.public_id,
                                            base_session_public_id: f33_token.public_id,
                                            oidc_sid: f33_session.public_id, oidc_jti: f33_session.oidc_jti,
                                            expires_at: f33_now + 10.minutes, scopes: %w(openid profile),
                                            issuer: OidcIssuer.for_client(f33_client), audiences: [f33_client.aud],
                                            jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f33_client),
                                            subject: OidcSubject.for(
                                              f33_token.actor_record,
                                              resource_type: "client",
                                            ), client_id: f33_client.client_id,
                  )
                  @base_browser_rp_credentials[f33_key] = [f33_access, f33_session.issue_refresh_token!]
                end
                if @base_browser_rp_credentials[f33_key]
                  f33_access, f33_refresh = @base_browser_rp_credentials.fetch(f33_key)
                  f33_cookie = [
                    f33_headers.fetch("Cookie"),
                    "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f33_access)}",
                    "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f33_refresh)}",
                  ].join("; ")
                  f33_headers = f33_headers.merge(
                    "Cookie" => f33_cookie,
                    "HTTP_COOKIE" => f33_cookie,
                  )
                end
              end
              f33_headers
            end
          fx33_harness.fetch("Cookie").split("; ").each do |pair|
            name, value = pair.split("=", 2)
            cookies[name] = Rack::Utils.unescape(value)
          end
          browser_headers.merge(fx33_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
        end
      get visa_app_oidc_logout_url(host: @host), params: params, headers: http_headers_6
      http_headers_5 =
        begin
          fx34_harness =
            begin
              f34_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
              f34_host = f34_headers["Host"]
              f34_route =
                begin
                  Rails.application.routes.recognize_path("https://#{f34_host}/") if f34_host.present?
                rescue ActionController::RoutingError
                  nil
                end
              f34_family, f34_surface = f34_route&.fetch(:controller)&.split("/")
              if %w(base warp core edit).include?(f34_family) && f34_surface == "app"
                f34_client_id =
                  case f34_family
                  when "base" then "base-#{f34_surface}-ww"
                  when "edit" then "edit-org-ww"
                  else "#{f34_family}-#{f34_surface}"
                  end
                f34_token = ClientToken.includes(
                  :user,
                  :device_session,
                ).find_by!(public_id: f34_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                f34_client = OidcClientRegistry.find!(f34_client_id)
                f34_key = [f34_client.client_id, f34_token.public_id]
                @base_browser_rp_credentials ||= {}
                if !@base_browser_rp_credentials[f34_key] && f34_token.currently_usable? &&
                    !(f34_token.device_session_id && OpAppGrant.exists?(
                      device_session_id: f34_token.device_session_id,
                      oidc_client_id: f34_client.client_id,
                      revoked_at: nil,
                    ))
                  f34_token.rotate_refresh_token! unless f34_token.device_session_record.current_refresh_token_id
                  f34_now = Time.current
                  f34_session = OpAppGrant.create!(
                    authentication_epoch: 0,
                    client_token: f34_token, oidc_client_id: f34_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f34_now,
                    refresh_token_expires_at: f34_now + 10.minutes,
                  )
                  f34_access = AuthenticationTokenService.encode(
                    f34_token.actor_record, host: f34_host, resource_type: "client",
                                            session_public_id: f34_token.public_id,
                                            base_session_public_id: f34_token.public_id,
                                            oidc_sid: f34_session.public_id, oidc_jti: f34_session.oidc_jti,
                                            expires_at: f34_now + 10.minutes, scopes: %w(openid profile),
                                            issuer: OidcIssuer.for_client(f34_client), audiences: [f34_client.aud],
                                            jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f34_client),
                                            subject: OidcSubject.for(
                                              f34_token.actor_record,
                                              resource_type: "client",
                                            ), client_id: f34_client.client_id,
                  )
                  @base_browser_rp_credentials[f34_key] = [f34_access, f34_session.issue_refresh_token!]
                end
                if @base_browser_rp_credentials[f34_key]
                  f34_access, f34_refresh = @base_browser_rp_credentials.fetch(f34_key)
                  f34_cookie = [
                    f34_headers.fetch("Cookie"),
                    "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f34_access)}",
                    "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f34_refresh)}",
                  ].join("; ")
                  f34_headers = f34_headers.merge(
                    "Cookie" => f34_cookie,
                    "HTTP_COOKIE" => f34_cookie,
                  )
                end
              end
              f34_headers
            end
          fx34_harness.fetch("Cookie").split("; ").each do |pair|
            name, value = pair.split("=", 2)
            cookies[name] = Rack::Utils.unescape(value)
          end
          browser_headers.merge(fx34_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
        end
      post visa_app_oidc_logout_confirmation_path(host: @host, ri: "jp"), headers: http_headers_5

      assert_not_predicate @token.reload, :revoked?, "revoked for #{params[:id_token_hint].inspect}"
    end
  end

  test "D1 a second staged request in the same browser does not replace the first" do
    redirect_uri = @client.post_logout_redirect_uris.first
    http_headers_4 =
      begin
        fx35_harness =
          begin
            f35_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
            f35_host = f35_headers["Host"]
            f35_route =
              begin
                Rails.application.routes.recognize_path("https://#{f35_host}/") if f35_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f35_family, f35_surface = f35_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f35_family) && f35_surface == "app"
              f35_client_id =
                case f35_family
                when "base" then "base-#{f35_surface}-ww"
                when "edit" then "edit-org-ww"
                else "#{f35_family}-#{f35_surface}"
                end
              f35_token = ClientToken.includes(
                :user,
                :device_session,
              ).find_by!(public_id: f35_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f35_client = OidcClientRegistry.find!(f35_client_id)
              f35_key = [f35_client.client_id, f35_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f35_key] && f35_token.currently_usable? &&
                  !(f35_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f35_token.device_session_id,
                    oidc_client_id: f35_client.client_id,
                    revoked_at: nil,
                  ))
                f35_token.rotate_refresh_token! unless f35_token.device_session_record.current_refresh_token_id
                f35_now = Time.current
                f35_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f35_token, oidc_client_id: f35_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f35_now,
                  refresh_token_expires_at: f35_now + 10.minutes,
                )
                f35_access = AuthenticationTokenService.encode(
                  f35_token.actor_record, host: f35_host, resource_type: "client",
                                          session_public_id: f35_token.public_id,
                                          base_session_public_id: f35_token.public_id,
                                          oidc_sid: f35_session.public_id, oidc_jti: f35_session.oidc_jti,
                                          expires_at: f35_now + 10.minutes, scopes: %w(openid profile),
                                          issuer: OidcIssuer.for_client(f35_client), audiences: [f35_client.aud],
                                          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f35_client),
                                          subject: OidcSubject.for(
                                            f35_token.actor_record,
                                            resource_type: "client",
                                          ), client_id: f35_client.client_id,
                )
                @base_browser_rp_credentials[f35_key] =
                  [f35_access, f35_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f35_key]
                f35_access, f35_refresh = @base_browser_rp_credentials.fetch(f35_key)
                f35_cookie = [
                  f35_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f35_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f35_refresh)}",
                ].join("; ")
                f35_headers = f35_headers.merge(
                  "Cookie" => f35_cookie,
                  "HTTP_COOKIE" => f35_cookie,
                )
              end
            end
            f35_headers
          end
        fx35_harness.fetch("Cookie").split("; ").each do |pair|
          name, value = pair.split("=", 2)
          cookies[name] = Rack::Utils.unescape(value)
        end
        browser_headers.merge(fx35_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
      end
    get visa_app_oidc_logout_url(host: @host),
        params: { id_token_hint: id_token, post_logout_redirect_uri: redirect_uri, state: "first", ri: "jp" },
        headers: http_headers_4
    http_headers_3 =
      begin
        fx36_harness =
          begin
            f36_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
            f36_host = f36_headers["Host"]
            f36_route =
              begin
                Rails.application.routes.recognize_path("https://#{f36_host}/") if f36_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f36_family, f36_surface = f36_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f36_family) && f36_surface == "app"
              f36_client_id =
                case f36_family
                when "base" then "base-#{f36_surface}-ww"
                when "edit" then "edit-org-ww"
                else "#{f36_family}-#{f36_surface}"
                end
              f36_token = ClientToken.includes(
                :user,
                :device_session,
              ).find_by!(public_id: f36_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f36_client = OidcClientRegistry.find!(f36_client_id)
              f36_key = [f36_client.client_id, f36_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f36_key] && f36_token.currently_usable? &&
                  !(f36_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f36_token.device_session_id,
                    oidc_client_id: f36_client.client_id,
                    revoked_at: nil,
                  ))
                f36_token.rotate_refresh_token! unless f36_token.device_session_record.current_refresh_token_id
                f36_now = Time.current
                f36_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f36_token, oidc_client_id: f36_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f36_now,
                  refresh_token_expires_at: f36_now + 10.minutes,
                )
                f36_access = AuthenticationTokenService.encode(
                  f36_token.actor_record, host: f36_host, resource_type: "client",
                                          session_public_id: f36_token.public_id,
                                          base_session_public_id: f36_token.public_id,
                                          oidc_sid: f36_session.public_id, oidc_jti: f36_session.oidc_jti,
                                          expires_at: f36_now + 10.minutes, scopes: %w(openid profile),
                                          issuer: OidcIssuer.for_client(f36_client), audiences: [f36_client.aud],
                                          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f36_client),
                                          subject: OidcSubject.for(
                                            f36_token.actor_record,
                                            resource_type: "client",
                                          ), client_id: f36_client.client_id,
                )
                @base_browser_rp_credentials[f36_key] =
                  [f36_access, f36_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f36_key]
                f36_access, f36_refresh = @base_browser_rp_credentials.fetch(f36_key)
                f36_cookie = [
                  f36_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f36_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f36_refresh)}",
                ].join("; ")
                f36_headers = f36_headers.merge(
                  "Cookie" => f36_cookie,
                  "HTTP_COOKIE" => f36_cookie,
                )
              end
            end
            f36_headers
          end
        fx36_harness.fetch("Cookie").split("; ").each do |pair|
          name, value = pair.split("=", 2)
          cookies[name] = Rack::Utils.unescape(value)
        end
        browser_headers.merge(fx36_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
      end
    get visa_app_oidc_logout_url(host: @host),
        params: { id_token_hint: id_token, post_logout_redirect_uri: redirect_uri, state: "second", ri: "jp" },
        headers: http_headers_3

    assert_response :ok

    http_headers_2 =
      begin
        fx37_harness =
          begin
            f37_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
            f37_host = f37_headers["Host"]
            f37_route =
              begin
                Rails.application.routes.recognize_path("https://#{f37_host}/") if f37_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f37_family, f37_surface = f37_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f37_family) && f37_surface == "app"
              f37_client_id =
                case f37_family
                when "base" then "base-#{f37_surface}-ww"
                when "edit" then "edit-org-ww"
                else "#{f37_family}-#{f37_surface}"
                end
              f37_token = ClientToken.includes(
                :user,
                :device_session,
              ).find_by!(public_id: f37_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f37_client = OidcClientRegistry.find!(f37_client_id)
              f37_key = [f37_client.client_id, f37_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f37_key] && f37_token.currently_usable? &&
                  !(f37_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f37_token.device_session_id,
                    oidc_client_id: f37_client.client_id,
                    revoked_at: nil,
                  ))
                f37_token.rotate_refresh_token! unless f37_token.device_session_record.current_refresh_token_id
                f37_now = Time.current
                f37_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f37_token, oidc_client_id: f37_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f37_now,
                  refresh_token_expires_at: f37_now + 10.minutes,
                )
                f37_access = AuthenticationTokenService.encode(
                  f37_token.actor_record, host: f37_host, resource_type: "client",
                                          session_public_id: f37_token.public_id,
                                          base_session_public_id: f37_token.public_id,
                                          oidc_sid: f37_session.public_id, oidc_jti: f37_session.oidc_jti,
                                          expires_at: f37_now + 10.minutes, scopes: %w(openid profile),
                                          issuer: OidcIssuer.for_client(f37_client), audiences: [f37_client.aud],
                                          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f37_client),
                                          subject: OidcSubject.for(
                                            f37_token.actor_record,
                                            resource_type: "client",
                                          ), client_id: f37_client.client_id,
                )
                @base_browser_rp_credentials[f37_key] = [f37_access, f37_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f37_key]
                f37_access, f37_refresh = @base_browser_rp_credentials.fetch(f37_key)
                f37_cookie = [
                  f37_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f37_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f37_refresh)}",
                ].join("; ")
                f37_headers = f37_headers.merge(
                  "Cookie" => f37_cookie,
                  "HTTP_COOKIE" => f37_cookie,
                )
              end
            end
            f37_headers
          end
        fx37_harness.fetch("Cookie").split("; ").each do |pair|
          name, value = pair.split("=", 2)
          cookies[name] = Rack::Utils.unescape(value)
        end
        browser_headers.merge(fx37_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
      end
    post visa_app_oidc_logout_confirmation_path(host: @host, ri: "jp"), headers: http_headers_2

    assert_response :see_other
    assert_predicate @token.reload, :revoked?
    query = Rack::Utils.parse_nested_query(URI.parse(jump_rt_url_from_location(response.location)).query.to_s)

    assert_equal "first", query["state"]
  end

  test "D1 hint issued for another realm's client and issuer ends no session" do
    org_client = OidcClientRegistry.find!("core-org-jp")
    foreign_hint = OidcIdTokenIssuer.call(
      resource: @user,
      client: org_client,
      nonce: "nonce",
      issuer: OidcIssuer.for_resource_type("operator"),
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("operator"),
      subject: OidcSubject.for(@user, resource_type: "client"),
      sid: @session_public_id,
    )

    http_headers_1 =
      begin
        fx38_harness =
          begin
            f38_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
            f38_host = f38_headers["Host"]
            f38_route =
              begin
                Rails.application.routes.recognize_path("https://#{f38_host}/") if f38_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f38_family, f38_surface = f38_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f38_family) && f38_surface == "app"
              f38_client_id =
                case f38_family
                when "base" then "base-#{f38_surface}-ww"
                when "edit" then "edit-org-ww"
                else "#{f38_family}-#{f38_surface}"
                end
              f38_token = ClientToken.includes(
                :user,
                :device_session,
              ).find_by!(public_id: f38_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f38_client = OidcClientRegistry.find!(f38_client_id)
              f38_key = [f38_client.client_id, f38_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f38_key] && f38_token.currently_usable? &&
                  !(f38_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f38_token.device_session_id,
                    oidc_client_id: f38_client.client_id,
                    revoked_at: nil,
                  ))
                f38_token.rotate_refresh_token! unless f38_token.device_session_record.current_refresh_token_id
                f38_now = Time.current
                f38_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f38_token, oidc_client_id: f38_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f38_now,
                  refresh_token_expires_at: f38_now + 10.minutes,
                )
                f38_access = AuthenticationTokenService.encode(
                  f38_token.actor_record, host: f38_host, resource_type: "client",
                                          session_public_id: f38_token.public_id,
                                          base_session_public_id: f38_token.public_id,
                                          oidc_sid: f38_session.public_id, oidc_jti: f38_session.oidc_jti,
                                          expires_at: f38_now + 10.minutes, scopes: %w(openid profile),
                                          issuer: OidcIssuer.for_client(f38_client), audiences: [f38_client.aud],
                                          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f38_client),
                                          subject: OidcSubject.for(
                                            f38_token.actor_record,
                                            resource_type: "client",
                                          ), client_id: f38_client.client_id,
                )
                @base_browser_rp_credentials[f38_key] =
                  [f38_access, f38_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f38_key]
                f38_access, f38_refresh = @base_browser_rp_credentials.fetch(f38_key)
                f38_cookie = [
                  f38_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f38_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f38_refresh)}",
                ].join("; ")
                f38_headers = f38_headers.merge(
                  "Cookie" => f38_cookie,
                  "HTTP_COOKIE" => f38_cookie,
                )
              end
            end
            f38_headers
          end
        fx38_harness.fetch("Cookie").split("; ").each do |pair|
          name, value = pair.split("=", 2)
          cookies[name] = Rack::Utils.unescape(value)
        end
        browser_headers.merge(fx38_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
      end
    get visa_app_oidc_logout_url(host: @host),
        params: { id_token_hint: foreign_hint,
                  post_logout_redirect_uri: @client.post_logout_redirect_uris.first,
                  ri: "jp", },
        headers: http_headers_1
    http_headers_0 =
      begin
        fx39_harness =
          begin
            f39_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
            f39_host = f39_headers["Host"]
            f39_route =
              begin
                Rails.application.routes.recognize_path("https://#{f39_host}/") if f39_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f39_family, f39_surface = f39_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f39_family) && f39_surface == "app"
              f39_client_id =
                case f39_family
                when "base" then "base-#{f39_surface}-ww"
                when "edit" then "edit-org-ww"
                else "#{f39_family}-#{f39_surface}"
                end
              f39_token = ClientToken.includes(
                :user,
                :device_session,
              ).find_by!(public_id: f39_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f39_client = OidcClientRegistry.find!(f39_client_id)
              f39_key = [f39_client.client_id, f39_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f39_key] && f39_token.currently_usable? &&
                  !(f39_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f39_token.device_session_id,
                    oidc_client_id: f39_client.client_id,
                    revoked_at: nil,
                  ))
                f39_token.rotate_refresh_token! unless f39_token.device_session_record.current_refresh_token_id
                f39_now = Time.current
                f39_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f39_token, oidc_client_id: f39_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f39_now,
                  refresh_token_expires_at: f39_now + 10.minutes,
                )
                f39_access = AuthenticationTokenService.encode(
                  f39_token.actor_record, host: f39_host, resource_type: "client",
                                          session_public_id: f39_token.public_id,
                                          base_session_public_id: f39_token.public_id,
                                          oidc_sid: f39_session.public_id, oidc_jti: f39_session.oidc_jti,
                                          expires_at: f39_now + 10.minutes, scopes: %w(openid profile),
                                          issuer: OidcIssuer.for_client(f39_client), audiences: [f39_client.aud],
                                          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f39_client),
                                          subject: OidcSubject.for(
                                            f39_token.actor_record,
                                            resource_type: "client",
                                          ), client_id: f39_client.client_id,
                )
                @base_browser_rp_credentials[f39_key] = [f39_access, f39_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f39_key]
                f39_access, f39_refresh = @base_browser_rp_credentials.fetch(f39_key)
                f39_cookie = [
                  f39_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f39_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f39_refresh)}",
                ].join("; ")
                f39_headers = f39_headers.merge(
                  "Cookie" => f39_cookie,
                  "HTTP_COOKIE" => f39_cookie,
                )
              end
            end
            f39_headers
          end
        fx39_harness.fetch("Cookie").split("; ").each do |pair|
          name, value = pair.split("=", 2)
          cookies[name] = Rack::Utils.unescape(value)
        end
        browser_headers.merge(fx39_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
      end
    post visa_app_oidc_logout_confirmation_path(host: @host, ri: "jp"), headers: http_headers_0

    assert_not_predicate @token.reload, :revoked?
  end

  test "D1 control: own-session logout ends only that session and leaves another subject's session active" do
    other_user = clients(:two)
    other_token = ClientToken.create!(
      authentication_epoch: 0,
      user: other_user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    redirect_uri = @client.post_logout_redirect_uris.first

    with_forgery_protection do
      get visa_app_oidc_logout_url(host: @host),
          params: { id_token_hint: id_token, post_logout_redirect_uri: redirect_uri, state: "s1", ri: "jp" },
          headers: begin
            fx40_harness =
              begin
                f40_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
                f40_host = f40_headers["Host"]
                f40_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{f40_host}/") if f40_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                f40_family, f40_surface = f40_route&.fetch(:controller)&.split("/")
                if %w(base warp core edit).include?(f40_family) && f40_surface == "app"
                  f40_client_id =
                    case f40_family
                    when "base" then "base-#{f40_surface}-ww"
                    when "edit" then "edit-org-ww"
                    else "#{f40_family}-#{f40_surface}"
                    end
                  f40_token = ClientToken.includes(
                    :user,
                    :device_session,
                  ).find_by!(public_id: f40_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  f40_client = OidcClientRegistry.find!(f40_client_id)
                  f40_key = [f40_client.client_id, f40_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[f40_key] && f40_token.currently_usable? &&
                      !(f40_token.device_session_id && OpAppGrant.exists?(
                        device_session_id: f40_token.device_session_id,
                        oidc_client_id: f40_client.client_id,
                        revoked_at: nil,
                      ))
                    f40_token.rotate_refresh_token! unless f40_token.device_session_record.current_refresh_token_id
                    f40_now = Time.current
                    f40_session = OpAppGrant.create!(
                      authentication_epoch: 0,
                      client_token: f40_token, oidc_client_id: f40_client.client_id, oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f40_now,
                      refresh_token_expires_at: f40_now + 10.minutes,
                    )
                    f40_access = AuthenticationTokenService.encode(
                      f40_token.actor_record,
                      host: f40_host,
                      resource_type: "client",
                      session_public_id: f40_token.public_id,
                      base_session_public_id: f40_token.public_id,
                      oidc_sid: f40_session.public_id,
                      oidc_jti: f40_session.oidc_jti,
                      expires_at: f40_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(f40_client),
                      audiences: [f40_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f40_client),
                      subject: OidcSubject.for(
                        f40_token.actor_record,
                        resource_type: "client",
                      ),
                      client_id: f40_client.client_id,
                    )
                    @base_browser_rp_credentials[f40_key] =
                      [f40_access, f40_session.issue_refresh_token!]
                  end
                  if @base_browser_rp_credentials[f40_key]
                    f40_access, f40_refresh = @base_browser_rp_credentials.fetch(f40_key)
                    f40_cookie = [
                      f40_headers.fetch("Cookie"),
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f40_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f40_refresh)}",
                    ].join("; ")
                    f40_headers = f40_headers.merge(
                      "Cookie" => f40_cookie,
                      "HTTP_COOKIE" => f40_cookie,
                    )
                  end
                end
                f40_headers
              end
            fx40_harness.fetch("Cookie").split("; ").each do |pair|
              name, value = pair.split("=", 2)
              cookies[name] = Rack::Utils.unescape(value)
            end
            browser_headers.merge(fx40_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
          end.merge("Sec-Fetch-Site" => "same-origin")

      assert_no_changes -> { @token.reload.revoked? } do
        follow_redirect!(
          headers: begin
            fx41_harness =
              begin
                f41_headers = as_user_headers(
                  @user, host: @host,
                         session_public_id: @session_public_id,
                )
                f41_host = f41_headers["Host"]
                f41_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{f41_host}/") if f41_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                f41_family, f41_surface = f41_route&.fetch(:controller)&.split("/")
                if %w(base warp core edit).include?(f41_family) && f41_surface == "app"
                  f41_client_id =
                    case f41_family
                    when "base" then "base-#{f41_surface}-ww"
                    when "edit" then "edit-org-ww"
                    else "#{f41_family}-#{f41_surface}"
                    end
                  f41_token = ClientToken.includes(
                    :user,
                    :device_session,
                  ).find_by!(public_id: f41_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  f41_client = OidcClientRegistry.find!(f41_client_id)
                  f41_key = [f41_client.client_id, f41_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[f41_key] && f41_token.currently_usable? &&
                      !(f41_token.device_session_id && OpAppGrant.exists?(
                        device_session_id: f41_token.device_session_id,
                        oidc_client_id: f41_client.client_id,
                        revoked_at: nil,
                      ))
                    f41_token.rotate_refresh_token! unless f41_token.device_session_record.current_refresh_token_id
                    f41_now = Time.current
                    f41_session = OpAppGrant.create!(
                      authentication_epoch: 0,
                      client_token: f41_token, oidc_client_id: f41_client.client_id, oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f41_now,
                      refresh_token_expires_at: f41_now + 10.minutes,
                    )
                    f41_access = AuthenticationTokenService.encode(
                      f41_token.actor_record,
                      host: f41_host,
                      resource_type: "client",
                      session_public_id: f41_token.public_id,
                      base_session_public_id: f41_token.public_id,
                      oidc_sid: f41_session.public_id,
                      oidc_jti: f41_session.oidc_jti,
                      expires_at: f41_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(f41_client),
                      audiences: [f41_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f41_client),
                      subject: OidcSubject.for(
                        f41_token.actor_record,
                        resource_type: "client",
                      ),
                      client_id: f41_client.client_id,
                    )
                    @base_browser_rp_credentials[f41_key] =
                      [f41_access, f41_session.issue_refresh_token!]
                  end
                  if @base_browser_rp_credentials[f41_key]
                    f41_access, f41_refresh = @base_browser_rp_credentials.fetch(f41_key)
                    f41_cookie = [
                      f41_headers.fetch("Cookie"),
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f41_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f41_refresh)}",
                    ].join("; ")
                    f41_headers = f41_headers.merge(
                      "Cookie" => f41_cookie,
                      "HTTP_COOKIE" => f41_cookie,
                    )
                  end
                end
                f41_headers
              end
            cookies[AuthenticationBase::ACCESS_COOKIE_KEY] =
              fx41_harness.fetch("Cookie").split("=", 2).last
            browser_headers.merge(fx41_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
          end.merge("Sec-Fetch-Site" => "same-origin"),
        )
      end

      csrf_token = response.parsed_body.at_css("meta[name='csrf-token']")&.[]("content")
      assert_withheld("logout confirmation must include a CSRF token") { csrf_token.present? }
      post visa_app_oidc_logout_confirmation_path(host: @host, ri: "jp"),
           params: { authenticity_token: csrf_token }, headers: begin
             fx42_harness =
               begin
                 f42_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
                 f42_host = f42_headers["Host"]
                 f42_route =
                   begin
                     Rails.application.routes.recognize_path("https://#{f42_host}/") if f42_host.present?
                   rescue ActionController::RoutingError
                     nil
                   end
                 f42_family, f42_surface = f42_route&.fetch(:controller)&.split("/")
                 if %w(base warp core edit).include?(f42_family) && f42_surface == "app"
                   f42_client_id =
                     case f42_family
                     when "base" then "base-#{f42_surface}-ww"
                     when "edit" then "edit-org-ww"
                     else "#{f42_family}-#{f42_surface}"
                     end
                   f42_token =
                     ClientToken.includes(:user, :device_session).find_by!(
                       public_id: f42_headers.fetch("X-TEST-SESSION-PUBLIC-ID"),
                     )
                   f42_client = OidcClientRegistry.find!(f42_client_id)
                   f42_key = [f42_client.client_id, f42_token.public_id]
                   @base_browser_rp_credentials ||= {}
                   if !@base_browser_rp_credentials[f42_key] && f42_token.currently_usable? &&
                       !(f42_token.device_session_id && OpAppGrant.exists?(
                         device_session_id: f42_token.device_session_id,
                         oidc_client_id: f42_client.client_id,
                         revoked_at: nil,
                       ))
                     f42_token.rotate_refresh_token! unless f42_token.device_session_record.current_refresh_token_id
                     f42_now = Time.current
                     f42_session = OpAppGrant.create!(
                       authentication_epoch: 0,
                       client_token: f42_token, oidc_client_id: f42_client.client_id, oidc_scope: "openid profile",
                       oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f42_now,
                       refresh_token_expires_at: f42_now + 10.minutes,
                     )
                     f42_access = AuthenticationTokenService.encode(
                       f42_token.actor_record, host: f42_host, resource_type: "client",
                                               session_public_id: f42_token.public_id,
                                               base_session_public_id: f42_token.public_id,
                                               oidc_sid: f42_session.public_id, oidc_jti: f42_session.oidc_jti,
                                               expires_at: f42_now + 10.minutes, scopes: %w(openid profile),
                                               issuer: OidcIssuer.for_client(f42_client), audiences: [f42_client.aud],
                                               jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f42_client),
                                               subject: OidcSubject.for(
                                                 f42_token.actor_record,
                                                 resource_type: "client",
                                               ), client_id: f42_client.client_id,
                     )
                     @base_browser_rp_credentials[f42_key] = [f42_access, f42_session.issue_refresh_token!]
                   end
                   if @base_browser_rp_credentials[f42_key]
                     f42_access, f42_refresh = @base_browser_rp_credentials.fetch(f42_key)
                     f42_cookie = [
                       f42_headers.fetch("Cookie"),
                       "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f42_access)}",
                       "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f42_refresh)}",
                     ].join("; ")
                     f42_headers = f42_headers.merge(
                       "Cookie" => f42_cookie,
                       "HTTP_COOKIE" => f42_cookie,
                     )
                   end
                 end
                 f42_headers
               end
             fx42_harness.fetch("Cookie").split("; ").each do |pair|
               name, value = pair.split("=", 2)
               cookies[name] = Rack::Utils.unescape(value)
             end
             browser_headers.merge(fx42_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
           end.merge("Sec-Fetch-Site" => "same-origin")
    end

    assert_response :see_other
    assert_predicate @token.reload, :revoked?
    assert_not_predicate other_token.reload, :revoked?
    assert_equal URI.parse(redirect_uri).host, URI.parse(jump_rt_url_from_location(response.location)).host
  end

  # D2: the coordinated-logout CSRF declaration used to replace the inherited check, so an ordinary
  # POST without logout_challenge ran no CSRF verification at all.
  test "D-33 refuses an Auth-origin logout challenge at the OP" do
    stops_before = OpAppAuthorityStop.count
    get visa_app_oidc_logout_path(logout_challenge: "retired-rp-challenge", ri: "jp"),
        headers: as_user_headers(@user, host: @host, session_public_id: @session_public_id)

    assert_response :bad_request
    assert_equal stops_before, OpAppAuthorityStop.count
    assert_nil session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]
    assert_not_predicate @token.reload, :revoked?
  end

  test "D-33 refuses coordinated RP logout challenges on POST" do
    stops_before = OpAppAuthorityStop.count
    post visa_app_oidc_logout_path(logout_challenge: "retired-rp-challenge", ri: "jp"),
         headers: as_user_headers(@user, host: @host, session_public_id: @session_public_id)

    assert_response :bad_request
    assert_equal stops_before, OpAppAuthorityStop.count
    assert_nil session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]
    assert_not_predicate @token.reload, :revoked?
  end

  test "D2 cross-site POST without logout_challenge or token does not end the staged session" do
    redirect_uri = @client.post_logout_redirect_uris.first

    with_forgery_protection do
      get visa_app_oidc_logout_url(host: @host),
          params: { id_token_hint: id_token, post_logout_redirect_uri: redirect_uri, ri: "jp" },
          headers: begin
            fx46_harness =
              begin
                f46_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
                f46_host = f46_headers["Host"]
                f46_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{f46_host}/") if f46_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                f46_family, f46_surface = f46_route&.fetch(:controller)&.split("/")
                if %w(base warp core edit).include?(f46_family) && f46_surface == "app"
                  f46_client_id =
                    case f46_family
                    when "base" then "base-#{f46_surface}-ww"
                    when "edit" then "edit-org-ww"
                    else "#{f46_family}-#{f46_surface}"
                    end
                  f46_token = ClientToken.includes(
                    :user,
                    :device_session,
                  ).find_by!(public_id: f46_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  f46_client = OidcClientRegistry.find!(f46_client_id)
                  f46_key = [f46_client.client_id, f46_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[f46_key] && f46_token.currently_usable? &&
                      !(f46_token.device_session_id && OpAppGrant.exists?(
                        device_session_id: f46_token.device_session_id,
                        oidc_client_id: f46_client.client_id,
                        revoked_at: nil,
                      ))
                    f46_token.rotate_refresh_token! unless f46_token.device_session_record.current_refresh_token_id
                    f46_now = Time.current
                    f46_session = OpAppGrant.create!(
                      authentication_epoch: 0,
                      client_token: f46_token, oidc_client_id: f46_client.client_id, oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f46_now,
                      refresh_token_expires_at: f46_now + 10.minutes,
                    )
                    f46_access = AuthenticationTokenService.encode(
                      f46_token.actor_record,
                      host: f46_host,
                      resource_type: "client",
                      session_public_id: f46_token.public_id,
                      base_session_public_id: f46_token.public_id,
                      oidc_sid: f46_session.public_id,
                      oidc_jti: f46_session.oidc_jti,
                      expires_at: f46_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(f46_client),
                      audiences: [f46_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f46_client),
                      subject: OidcSubject.for(
                        f46_token.actor_record,
                        resource_type: "client",
                      ),
                      client_id: f46_client.client_id,
                    )
                    @base_browser_rp_credentials[f46_key] =
                      [f46_access, f46_session.issue_refresh_token!]
                  end
                  if @base_browser_rp_credentials[f46_key]
                    f46_access, f46_refresh = @base_browser_rp_credentials.fetch(f46_key)
                    f46_cookie = [
                      f46_headers.fetch("Cookie"),
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f46_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f46_refresh)}",
                    ].join("; ")
                    f46_headers = f46_headers.merge(
                      "Cookie" => f46_cookie,
                      "HTTP_COOKIE" => f46_cookie,
                    )
                  end
                end
                f46_headers
              end
            fx46_harness.fetch("Cookie").split("; ").each do |pair|
              name, value = pair.split("=", 2)
              cookies[name] = Rack::Utils.unescape(value)
            end
            browser_headers.merge(fx46_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
          end.merge("Sec-Fetch-Site" => "same-origin")
      post visa_app_oidc_logout_confirmation_path(host: @host, ri: "jp"),
           headers: begin
             fx47_harness =
               begin
                 f47_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
                 f47_host = f47_headers["Host"]
                 f47_route =
                   begin
                     Rails.application.routes.recognize_path("https://#{f47_host}/") if f47_host.present?
                   rescue ActionController::RoutingError
                     nil
                   end
                 f47_family, f47_surface = f47_route&.fetch(:controller)&.split("/")
                 if %w(base warp core edit).include?(f47_family) && f47_surface == "app"
                   f47_client_id =
                     case f47_family
                     when "base" then "base-#{f47_surface}-ww"
                     when "edit" then "edit-org-ww"
                     else "#{f47_family}-#{f47_surface}"
                     end
                   f47_token = ClientToken.includes(
                     :user,
                     :device_session,
                   ).find_by!(public_id: f47_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                   f47_client = OidcClientRegistry.find!(f47_client_id)
                   f47_key = [f47_client.client_id, f47_token.public_id]
                   @base_browser_rp_credentials ||= {}
                   if !@base_browser_rp_credentials[f47_key] && f47_token.currently_usable? &&
                       !(f47_token.device_session_id && OpAppGrant.exists?(
                         device_session_id: f47_token.device_session_id,
                         oidc_client_id: f47_client.client_id,
                         revoked_at: nil,
                       ))
                     f47_token.rotate_refresh_token! unless f47_token.device_session_record.current_refresh_token_id
                     f47_now = Time.current
                     f47_session = OpAppGrant.create!(
                       authentication_epoch: 0,
                       client_token: f47_token, oidc_client_id: f47_client.client_id, oidc_scope: "openid profile",
                       oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f47_now,
                       refresh_token_expires_at: f47_now + 10.minutes,
                     )
                     f47_access = AuthenticationTokenService.encode(
                       f47_token.actor_record,
                       host: f47_host,
                       resource_type: "client",
                       session_public_id: f47_token.public_id,
                       base_session_public_id: f47_token.public_id,
                       oidc_sid: f47_session.public_id,
                       oidc_jti: f47_session.oidc_jti,
                       expires_at: f47_now + 10.minutes,
                       scopes: %w(openid profile),
                       issuer: OidcIssuer.for_client(f47_client),
                       audiences: [f47_client.aud],
                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f47_client),
                       subject: OidcSubject.for(
                         f47_token.actor_record,
                         resource_type: "client",
                       ),
                       client_id: f47_client.client_id,
                     )
                     @base_browser_rp_credentials[f47_key] =
                       [f47_access, f47_session.issue_refresh_token!]
                   end
                   if @base_browser_rp_credentials[f47_key]
                     f47_access, f47_refresh = @base_browser_rp_credentials.fetch(f47_key)
                     f47_cookie = [
                       f47_headers.fetch("Cookie"),
                       "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f47_access)}",
                       "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f47_refresh)}",
                     ].join("; ")
                     f47_headers = f47_headers.merge(
                       "Cookie" => f47_cookie,
                       "HTTP_COOKIE" => f47_cookie,
                     )
                   end
                 end
                 f47_headers
               end
             fx47_harness.fetch("Cookie").split("; ").each do |pair|
               name, value = pair.split("=", 2)
               cookies[name] = Rack::Utils.unescape(value)
             end
             browser_headers.merge(fx47_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
           end.except("X-CSRF-Token").merge("Sec-Fetch-Site" => "cross-site")
    end

    assert_not_predicate @token.reload, :revoked?
  end

  test "D2 same-origin POST without logout_challenge still ends the staged session" do
    redirect_uri = @client.post_logout_redirect_uris.first

    with_forgery_protection do
      get visa_app_oidc_logout_url(host: @host),
          params: { id_token_hint: id_token, post_logout_redirect_uri: redirect_uri, ri: "jp" },
          headers: begin
            fx48_harness =
              begin
                f48_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
                f48_host = f48_headers["Host"]
                f48_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{f48_host}/") if f48_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                f48_family, f48_surface = f48_route&.fetch(:controller)&.split("/")
                if %w(base warp core edit).include?(f48_family) && f48_surface == "app"
                  f48_client_id =
                    case f48_family
                    when "base" then "base-#{f48_surface}-ww"
                    when "edit" then "edit-org-ww"
                    else "#{f48_family}-#{f48_surface}"
                    end
                  f48_token = ClientToken.includes(
                    :user,
                    :device_session,
                  ).find_by!(public_id: f48_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  f48_client = OidcClientRegistry.find!(f48_client_id)
                  f48_key = [f48_client.client_id, f48_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[f48_key] && f48_token.currently_usable? &&
                      !(f48_token.device_session_id && OpAppGrant.exists?(
                        device_session_id: f48_token.device_session_id,
                        oidc_client_id: f48_client.client_id,
                        revoked_at: nil,
                      ))
                    f48_token.rotate_refresh_token! unless f48_token.device_session_record.current_refresh_token_id
                    f48_now = Time.current
                    f48_session = OpAppGrant.create!(
                      authentication_epoch: 0,
                      client_token: f48_token, oidc_client_id: f48_client.client_id, oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f48_now,
                      refresh_token_expires_at: f48_now + 10.minutes,
                    )
                    f48_access = AuthenticationTokenService.encode(
                      f48_token.actor_record,
                      host: f48_host,
                      resource_type: "client",
                      session_public_id: f48_token.public_id,
                      base_session_public_id: f48_token.public_id,
                      oidc_sid: f48_session.public_id,
                      oidc_jti: f48_session.oidc_jti,
                      expires_at: f48_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(f48_client),
                      audiences: [f48_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f48_client),
                      subject: OidcSubject.for(
                        f48_token.actor_record,
                        resource_type: "client",
                      ),
                      client_id: f48_client.client_id,
                    )
                    @base_browser_rp_credentials[f48_key] =
                      [f48_access, f48_session.issue_refresh_token!]
                  end
                  if @base_browser_rp_credentials[f48_key]
                    f48_access, f48_refresh = @base_browser_rp_credentials.fetch(f48_key)
                    f48_cookie = [
                      f48_headers.fetch("Cookie"),
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f48_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f48_refresh)}",
                    ].join("; ")
                    f48_headers = f48_headers.merge(
                      "Cookie" => f48_cookie,
                      "HTTP_COOKIE" => f48_cookie,
                    )
                  end
                end
                f48_headers
              end
            fx48_harness.fetch("Cookie").split("; ").each do |pair|
              name, value = pair.split("=", 2)
              cookies[name] = Rack::Utils.unescape(value)
            end
            browser_headers.merge(fx48_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
          end.merge("Sec-Fetch-Site" => "same-origin")
      follow_redirect! if response.redirect?

      assert_response :success
      csrf_token = response.parsed_body.at_css("meta[name='csrf-token']")&.[]("content")
      assert_withheld("logout confirmation must include a CSRF token") { csrf_token.present? }
      post visa_app_oidc_logout_confirmation_path(host: @host, ri: "jp"),
           params: { authenticity_token: csrf_token }, headers: begin
             fx49_harness =
               begin
                 f49_headers = as_user_headers(@user, host: @host, session_public_id: @session_public_id)
                 f49_host = f49_headers["Host"]
                 f49_route =
                   begin
                     Rails.application.routes.recognize_path("https://#{f49_host}/") if f49_host.present?
                   rescue ActionController::RoutingError
                     nil
                   end
                 f49_family, f49_surface = f49_route&.fetch(:controller)&.split("/")
                 if %w(base warp core edit).include?(f49_family) && f49_surface == "app"
                   f49_client_id =
                     case f49_family
                     when "base" then "base-#{f49_surface}-ww"
                     when "edit" then "edit-org-ww"
                     else "#{f49_family}-#{f49_surface}"
                     end
                   f49_token =
                     ClientToken.includes(:user, :device_session).find_by!(
                       public_id: f49_headers.fetch("X-TEST-SESSION-PUBLIC-ID"),
                     )
                   f49_client = OidcClientRegistry.find!(f49_client_id)
                   f49_key = [f49_client.client_id, f49_token.public_id]
                   @base_browser_rp_credentials ||= {}
                   if !@base_browser_rp_credentials[f49_key] && f49_token.currently_usable? &&
                       !(f49_token.device_session_id && OpAppGrant.exists?(
                         device_session_id: f49_token.device_session_id,
                         oidc_client_id: f49_client.client_id,
                         revoked_at: nil,
                       ))
                     f49_token.rotate_refresh_token! unless f49_token.device_session_record.current_refresh_token_id
                     f49_now = Time.current
                     f49_session = OpAppGrant.create!(
                       authentication_epoch: 0,
                       client_token: f49_token, oidc_client_id: f49_client.client_id, oidc_scope: "openid profile",
                       oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f49_now,
                       refresh_token_expires_at: f49_now + 10.minutes,
                     )
                     f49_access = AuthenticationTokenService.encode(
                       f49_token.actor_record, host: f49_host, resource_type: "client",
                                               session_public_id: f49_token.public_id,
                                               base_session_public_id: f49_token.public_id,
                                               oidc_sid: f49_session.public_id, oidc_jti: f49_session.oidc_jti,
                                               expires_at: f49_now + 10.minutes, scopes: %w(openid profile),
                                               issuer: OidcIssuer.for_client(f49_client), audiences: [f49_client.aud],
                                               jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f49_client),
                                               subject: OidcSubject.for(
                                                 f49_token.actor_record,
                                                 resource_type: "client",
                                               ), client_id: f49_client.client_id,
                     )
                     @base_browser_rp_credentials[f49_key] = [f49_access, f49_session.issue_refresh_token!]
                   end
                   if @base_browser_rp_credentials[f49_key]
                     f49_access, f49_refresh = @base_browser_rp_credentials.fetch(f49_key)
                     f49_cookie = [
                       f49_headers.fetch("Cookie"),
                       "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f49_access)}",
                       "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f49_refresh)}",
                     ].join("; ")
                     f49_headers = f49_headers.merge(
                       "Cookie" => f49_cookie,
                       "HTTP_COOKIE" => f49_cookie,
                     )
                   end
                 end
                 f49_headers
               end
             fx49_harness.fetch("Cookie").split("; ").each do |pair|
               name, value = pair.split("=", 2)
               cookies[name] = Rack::Utils.unescape(value)
             end
             browser_headers.merge(fx49_harness.except("Cookie", "HTTP_COOKIE", "Authorization"))
           end.merge("Sec-Fetch-Site" => "same-origin")
    end

    assert_response :see_other
    assert_predicate @token.reload, :revoked?
  end

  private

  # A real browser presents the access token as a cookie alongside the Rails session cookie. The
  # harness headers carry it as a raw Cookie header, which would replace the jar (and the staged
  # logout request in the session), so the harness-issued token is placed in the jar instead.

  def id_token(resource: @user, subject: OidcSubject.for(@user, resource_type: "client"),
               sid: @session_public_id)
    OidcIdTokenIssuer.call(
      resource: resource,
      client: @client,
      nonce: "nonce",
      issuer: OidcIssuer.for_resource_type("client"),
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
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
class Visa::App::Oidc::LogoutsControllerTest
  private
end

# DAMP local helper copy on the test class.
class Visa::App::Oidc::LogoutsControllerTest
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
    visitor = Visitor.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::NOTHING,
      visibility_id: VisitorVisibility::VISITOR,
    )
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
       BASE_COM VISA_APP VISA_ORG VISA_COM).each do |namespace|
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
class Visa::App::Oidc::LogoutsControllerTest
  private

  # Derive the issuer id from the test host. Visa OP hosts resolve to surface:VISA_* so
  # the access token issuer matches the surface the
  # controller validates against.
  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service =
      if normalized.include?("visa")
        "VISA"
      elsif normalized.include?("acme")
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
