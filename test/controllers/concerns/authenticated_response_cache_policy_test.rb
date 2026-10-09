# typed: false
# frozen_string_literal: true

require "test_helper"

# Authenticated pages must not outlive the session in a browser: an authenticated HTML or Inertia
# response is `Cache-Control: no-store` (so neither the HTTP cache nor the back/forward cache keeps
# it), and a response that ends a session tells Inertia to clear its encrypted history. Ordinary
# authenticated navigation does not clear history. Base is a Global policy root, so public pages and
# JSON endpoints that make no cache decision are `no-store` too, from `DefaultNoStore`
# (adr/global-and-publishing-default-no-store-policy.md) rather than from the authenticated-page rule.
class AuthenticatedResponseCachePolicyTest < ActionDispatch::IntegrationTest
  setup do
    https!
    @host = configured_host(:base_service)
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    bootstrap_and_select!(@user, @token)
  end

  test "an authenticated HTML page is no-store" do
    get base_app_accounts_url(ri: "jp", host: @host), headers: begin
      rp_headers = as_user_headers(@user, host: @host)
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
          when "edit" then "edit-org"
          else "#{rp_family}-#{rp_surface}"
          end
        rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
        rp_client = OidcClientRegistry.find!(rp_client_id)
        rp_key = [rp_client.client_id, rp_token.public_id]
        @base_browser_rp_credentials ||= {}
        if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
            !(rp_token.device_session_id && ClientRpSession.exists?(
              device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
            ))
          rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
          rp_now = Time.current
          rp_session = ClientRpSession.create!(
            client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
            oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
            refresh_token_expires_at: rp_now + 10.minutes,
          )
          rp_access = AuthenticationTokenService.encode(
            rp_token.user, host: rp_host, resource_type: "client",
                           session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                           oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                           expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                           issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                           jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                           subject: OidcSubject.for(
                             rp_token.user,
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

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_no_store
  end

  # Rack adds a validator to the page, and a 304 is produced only after the action ran. A
  # conditional request therefore cannot skip the credential check: without a valid credential the
  # matching validator earns the sign-in redirect, never a 304.
  test "a matching validator does not let a conditional request bypass authentication" do
    headers =
      begin
        rp_headers = as_user_headers(@user, host: @host)
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
            when "edit" then "edit-org"
            else "#{rp_family}-#{rp_surface}"
            end
          rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && ClientRpSession.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
            rp_now = Time.current
            rp_session = ClientRpSession.create!(
              client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.user, host: rp_host, resource_type: "client",
                             session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                             oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                             expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                             issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                             jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                             subject: OidcSubject.for(
                               rp_token.user,
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
    get base_app_accounts_url(ri: "jp", host: @host), headers: headers

    assert_response :success
    assert_no_store
    validator = response.headers.fetch("ETag")

    get base_app_accounts_url(ri: "jp", host: @host), headers: host_headers(@host).merge("If-None-Match" => validator)

    assert_response :redirect
    assert_equal "/sign", URI.parse(response.location).path

    @token.device_session.revoke!(reason: "cache-policy-test")
    get base_app_accounts_url(ri: "jp", host: @host), headers: headers.merge("If-None-Match" => validator)

    assert_not_equal 304, response.status
    assert_response :redirect
  end

  test "an authenticated Inertia visit is no-store" do
    get base_app_accounts_url(ri: "jp", host: @host), headers: begin
      rp_headers = as_user_headers(@user, host: @host)
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
          when "edit" then "edit-org"
          else "#{rp_family}-#{rp_surface}"
          end
        rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
        rp_client = OidcClientRegistry.find!(rp_client_id)
        rp_key = [rp_client.client_id, rp_token.public_id]
        @base_browser_rp_credentials ||= {}
        if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
            !(rp_token.device_session_id && ClientRpSession.exists?(
              device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
            ))
          rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
          rp_now = Time.current
          rp_session = ClientRpSession.create!(
            client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
            oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
            refresh_token_expires_at: rp_now + 10.minutes,
          )
          rp_access = AuthenticationTokenService.encode(
            rp_token.user, host: rp_host, resource_type: "client",
                           session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                           oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                           expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                           issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                           jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                           subject: OidcSubject.for(
                             rp_token.user,
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
    version = inertia_page.fetch("version")

    get base_app_accounts_url(ri: "jp", host: @host),
        headers: begin
          rp_headers = as_user_headers(@user, host: @host)
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
              when "edit" then "edit-org"
              else "#{rp_family}-#{rp_surface}"
              end
            rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            rp_client = OidcClientRegistry.find!(rp_client_id)
            rp_key = [rp_client.client_id, rp_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                !(rp_token.device_session_id && ClientRpSession.exists?(
                  device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                ))
              rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
              rp_now = Time.current
              rp_session = ClientRpSession.create!(
                client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                rp_token.user, host: rp_host, resource_type: "client",
                               session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                               oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                               expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                               issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                               jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                               subject: OidcSubject.for(
                                 rp_token.user,
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
        end.merge("X-Inertia" => "true", "X-Inertia-Version" => version.to_s)

    assert_response :success
    assert_equal "true", response.headers["X-Inertia"]
    assert_no_store
  end

  test "ordinary authenticated navigation does not clear Inertia history" do
    get base_app_accounts_url(ri: "jp", host: @host), headers: begin
      rp_headers = as_user_headers(@user, host: @host)
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
          when "edit" then "edit-org"
          else "#{rp_family}-#{rp_surface}"
          end
        rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
        rp_client = OidcClientRegistry.find!(rp_client_id)
        rp_key = [rp_client.client_id, rp_token.public_id]
        @base_browser_rp_credentials ||= {}
        if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
            !(rp_token.device_session_id && ClientRpSession.exists?(
              device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
            ))
          rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
          rp_now = Time.current
          rp_session = ClientRpSession.create!(
            client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
            oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
            refresh_token_expires_at: rp_now + 10.minutes,
          )
          rp_access = AuthenticationTokenService.encode(
            rp_token.user, host: rp_host, resource_type: "client",
                           session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                           oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                           expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                           issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                           jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                           subject: OidcSubject.for(
                             rp_token.user,
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

    assert_response :success
    assert_not inertia_page.fetch("clearHistory")
  end

  test "an anonymous public HTML page carries the Global default no-store" do
    get edit_base_app_preference_cookie_url(ri: "jp", host: @host), headers: host_headers(@host)

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "an open page answered for a signed-in user is no-store" do
    get edit_base_app_preference_cookie_url(ri: "jp", host: @host), headers: begin
      rp_headers = as_user_headers(@user, host: @host)
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
          when "edit" then "edit-org"
          else "#{rp_family}-#{rp_surface}"
          end
        rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
        rp_client = OidcClientRegistry.find!(rp_client_id)
        rp_key = [rp_client.client_id, rp_token.public_id]
        @base_browser_rp_credentials ||= {}
        if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
            !(rp_token.device_session_id && ClientRpSession.exists?(
              device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
            ))
          rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
          rp_now = Time.current
          rp_session = ClientRpSession.create!(
            client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
            oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
            refresh_token_expires_at: rp_now + 10.minutes,
          )
          rp_access = AuthenticationTokenService.encode(
            rp_token.user, host: rp_host, resource_type: "client",
                           session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                           oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                           expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                           issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                           jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                           subject: OidcSubject.for(
                             rp_token.user,
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

    assert_response :success
    assert_no_store
  end

  test "an authenticated JSON response carries the Global default no-store" do
    get base_app_selector_url(ri: "jp", host: @host, format: :json), headers: begin
      rp_headers = as_user_headers(@user, host: @host)
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
          when "edit" then "edit-org"
          else "#{rp_family}-#{rp_surface}"
          end
        rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
        rp_client = OidcClientRegistry.find!(rp_client_id)
        rp_key = [rp_client.client_id, rp_token.public_id]
        @base_browser_rp_credentials ||= {}
        if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
            !(rp_token.device_session_id && ClientRpSession.exists?(
              device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
            ))
          rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
          rp_now = Time.current
          rp_session = ClientRpSession.create!(
            client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
            oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
            refresh_token_expires_at: rp_now + 10.minutes,
          )
          rp_access = AuthenticationTokenService.encode(
            rp_token.user, host: rp_host, resource_type: "client",
                           session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                           oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                           expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                           issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                           jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                           subject: OidcSubject.for(
                             rp_token.user,
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

    assert_equal "application/json", response.media_type
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "signing out clears Inertia history on the signed-out page" do
    headers =
      begin
        rp_headers = as_user_headers(@user, host: @host)
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
            when "edit" then "edit-org"
            else "#{rp_family}-#{rp_surface}"
            end
          rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && ClientRpSession.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
            rp_now = Time.current
            rp_session = ClientRpSession.create!(
              client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.user, host: rp_host, resource_type: "client",
                             session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                             oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                             expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                             issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                             jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                             subject: OidcSubject.for(
                               rp_token.user,
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
    post base_app_sign_out_url(ri: "jp", host: @host), headers: headers
    challenge = Rack::Utils.parse_nested_query(URI.parse(response.location).query).fetch("logout_challenge")
    8.times do
      if response.redirect?
        uri = URI.parse(response.location)
        assert_equal @host, uri.host if uri.host
        get uri.request_uri, headers: host_headers(@host)
      else
        break if AcmeLogoutTransactionCoordinator.find_by!(logout_challenge: challenge).finalized?

        assert_response :success
        document = response.parsed_body
        authority_form = document.at_css('form input[name="logout_challenge"]')&.ancestors("form")&.first
        if authority_form
          action = authority_form["action"]
          fields = authority_form.css("input[type='hidden']").to_h { |input| [input["name"], input["value"]] }
        else
          confirmation = inertia_page.fetch("props").fetch("form")
          action = confirmation.fetch("action")
          fields = { logout_challenge: confirmation.fetch("logout_challenge") }
        end
        post action, params: fields, headers: host_headers(@host).merge(
          "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin",
        )
      end
    end

    assert_predicate AcmeLogoutTransactionCoordinator.find_by!(logout_challenge: challenge), :finalized?
    assert_not_predicate @token.reload, :currently_usable?
    assert_response :success
    assert inertia_page.fetch("clearHistory")
    get base_app_root_url(ri: "jp", host: @host), headers: host_headers(@host)

    assert_response :success
    assert_not inertia_page.fetch("clearHistory")
  end

  # Stale credentials on an :open page are detached and the request continues anonymously. If it
  # arrived as an Inertia visit, the signed-in pages are still in that document's history, so the
  # anonymous page that replaces them must clear it.
  test "detaching stale credentials clears Inertia history on the page that follows" do
    headers =
      begin
        rp_headers = as_user_headers(@user, host: @host)
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
            when "edit" then "edit-org"
            else "#{rp_family}-#{rp_surface}"
            end
          rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && ClientRpSession.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
            rp_now = Time.current
            rp_session = ClientRpSession.create!(
              client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.user, host: rp_host, resource_type: "client",
                             session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                             oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                             expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                             issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                             jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                             subject: OidcSubject.for(
                               rp_token.user,
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
    ClientToken.where(id: @token.id).delete_all

    get base_app_root_url(ri: "jp", host: @host), headers: headers

    assert_response :success
    assert inertia_page.fetch("clearHistory")
  end

  private

  def assert_no_store
    assert_includes response.headers["Cache-Control"].to_s.split(",").map(&:strip), "no-store",
                    "expected no-store, got #{response.headers["Cache-Control"].inspect}"
  end

  def same_host?(location)
    URI.parse(location).host.in?([nil, @host])
  end

  def bootstrap_and_select!(user, token)
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: user)
    BaseSelectorAuthority.prepare(surface: :app, principal: user, session: token)
  end

  # DAMP local helper copy, as in the other Base controller tests.
  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end
end
