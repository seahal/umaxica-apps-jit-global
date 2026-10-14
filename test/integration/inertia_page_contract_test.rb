# typed: false
# frozen_string_literal: true

require "test_helper"

# Contract for the Rails-side Inertia protocol on the only Inertia endpoint in the application
# (Base::App::GroupsController#index).
#
# The pre-existing controller test asserted HTML substrings only, so it could not observe the page
# object Inertia actually navigates on: component, props, url, version. Every assertion here reads
# the protocol payload rather than the markup around it.
class InertiaPageContractTest < ActionDispatch::IntegrationTest
  setup do
    @host = configured_host(:base_service)
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)
  end

  test "initial response embeds the full page object, not just a component name" do
    http_headers_12 =
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
            rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
            rp_now = Time.current
            rp_session = ClientRpSession.create!(
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
    get(
      base_app_groups_url(ri: "jp", host: @host), headers: http_headers_12,
    )

    assert_response :success

    page = initial_page

    assert_equal "base/app/groups/index", page.fetch("component")
    assert_equal "Groups", page.dig("props", "title")
    assert_kind_of Array, page.dig("props", "groups")
    assert_equal ViteRuby.digest, page.fetch("version")
    assert page.fetch("encryptHistory"), "encrypt_history is configured on, so the page must carry it"
  end

  # The `url` key is the client's notion of the current page. Inertia resolves every subsequent
  # visit and every history entry against it, so a wrong value desynchronises the SPA from the
  # address bar.
  test "initial page url is the requested path including the query string" do
    http_headers_11 =
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
            rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
            rp_now = Time.current
            rp_session = ClientRpSession.create!(
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
    get(
      base_app_groups_url(ri: "jp", host: @host), headers: http_headers_11,
    )

    assert_response :success
    assert_equal "/groups?ri=jp", initial_page.fetch("url")
  end

  test "an Inertia visit returns the page object as JSON with the same current page url" do
    http_headers_10 =
      begin
        fx0_version = ViteRuby.digest
        begin
          f0_headers = as_user_headers(@user, host: @host)
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
              when "edit" then "edit-org"
              else "#{f0_family}-#{f0_surface}"
              end
            f0_token = ClientToken.find_by!(public_id: f0_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f0_client = OidcClientRegistry.find!(f0_client_id)
            f0_key = [f0_client.client_id, f0_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f0_key] && f0_token.currently_usable? &&
                !(f0_token.device_session_id && ClientRpSession.exists?(
                  device_session_id: f0_token.device_session_id,
                  oidc_client_id: f0_client.client_id,
                  revoked_at: nil,
                ))
              f0_token.rotate_refresh_token! unless f0_token.device_session_record.current_refresh_token_id
              f0_now = Time.current
              f0_session = ClientRpSession.create!(
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
              @base_browser_rp_credentials[f0_key] =
                [f0_access, f0_session.issue_refresh_token!]
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
        end.merge(inertia_headers(version: fx0_version))
      end
    get(
      base_app_groups_url(ri: "jp", host: @host),
      headers: http_headers_10,
    )

    assert_response :success
    assert_equal "true", response.headers["X-Inertia"]
    assert_equal "application/json", response.media_type

    page = response.parsed_body

    assert_equal "base/app/groups/index", page.fetch("component")
    assert_equal "/groups?ri=jp", page.fetch("url")
    assert_equal ViteRuby.digest, page.fetch("version")
  end

  # Inertia.js 3 reads the initial page from a JSON <script> element keyed by the root element id.
  # The older form, a `data-page` attribute on the root element, is not read by the client at all.
  # The root element id is the inertia_rails default, and `createInertiaApp` is booted without an
  # `id` override (gait/entrypoints/inertia.test.ts), so both sides meet on the upstream default.
  test "initial response carries the page in a script element and leaves the root element bare" do
    http_headers_9 =
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
            rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
            rp_now = Time.current
            rp_session = ClientRpSession.create!(
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
    get(
      base_app_groups_url(ri: "jp", host: @host), headers: http_headers_9,
    )

    assert_response :success
    assert_select "script[data-page='app'][type='application/json']", count: 1
    assert_select "div#app", count: 1
    assert_select "div[data-page]", count: 0
  end

  test "initial page script carries the response CSP nonce" do
    http_headers_8 =
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
            rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
            rp_now = Time.current
            rp_session = ClientRpSession.create!(
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
    get(
      base_app_groups_url(ri: "jp", host: @host), headers: http_headers_8,
    )

    assert_response :success

    nonce = css_select("meta[property='csp-nonce']").first["nonce"]

    assert_predicate nonce, :present?
    assert_equal nonce, css_select("script[data-page='app']").first["nonce"]
  end

  test "a page with no validation failure still carries an empty errors hash" do
    http_headers_7 =
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
            rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
            rp_now = Time.current
            rp_session = ClientRpSession.create!(
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
    get(
      base_app_groups_url(ri: "jp", host: @host), headers: http_headers_7,
    )

    assert_response :success
    assert_empty(initial_page.fetch("props").fetch("errors"))

    http_headers_6 =
      begin
        fx1_version = ViteRuby.digest
        begin
          f1_headers = as_user_headers(@user, host: @host)
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
              when "edit" then "edit-org"
              else "#{f1_family}-#{f1_surface}"
              end
            f1_token = ClientToken.find_by!(public_id: f1_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f1_client = OidcClientRegistry.find!(f1_client_id)
            f1_key = [f1_client.client_id, f1_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f1_key] && f1_token.currently_usable? &&
                !(f1_token.device_session_id && ClientRpSession.exists?(
                  device_session_id: f1_token.device_session_id,
                  oidc_client_id: f1_client.client_id,
                  revoked_at: nil,
                ))
              f1_token.rotate_refresh_token! unless f1_token.device_session_record.current_refresh_token_id
              f1_now = Time.current
              f1_session = ClientRpSession.create!(
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
        end.merge(inertia_headers(version: fx1_version))
      end
    get(
      base_app_groups_url(ri: "jp", host: @host),
      headers: http_headers_6,
    )

    assert_response :success
    assert_empty(response.parsed_body.fetch("props").fetch("errors"))
  end

  test "history is encrypted and not cleared on an ordinary page, initial and Inertia alike" do
    http_headers_5 =
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
            rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
            rp_now = Time.current
            rp_session = ClientRpSession.create!(
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
    get(
      base_app_groups_url(ri: "jp", host: @host), headers: http_headers_5,
    )

    assert_response :success
    assert initial_page.fetch("encryptHistory")
    assert_not initial_page.fetch("clearHistory")

    http_headers_4 =
      begin
        fx2_version = ViteRuby.digest
        begin
          f2_headers = as_user_headers(@user, host: @host)
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
              when "edit" then "edit-org"
              else "#{f2_family}-#{f2_surface}"
              end
            f2_token = ClientToken.find_by!(public_id: f2_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f2_client = OidcClientRegistry.find!(f2_client_id)
            f2_key = [f2_client.client_id, f2_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f2_key] && f2_token.currently_usable? &&
                !(f2_token.device_session_id && ClientRpSession.exists?(
                  device_session_id: f2_token.device_session_id,
                  oidc_client_id: f2_client.client_id,
                  revoked_at: nil,
                ))
              f2_token.rotate_refresh_token! unless f2_token.device_session_record.current_refresh_token_id
              f2_now = Time.current
              f2_session = ClientRpSession.create!(
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
        end.merge(inertia_headers(version: fx2_version))
      end
    get(
      base_app_groups_url(ri: "jp", host: @host),
      headers: http_headers_4,
    )

    assert_response :success
    assert response.parsed_body.fetch("encryptHistory")
    assert_not response.parsed_body.fetch("clearHistory")
  end

  # The page url is origin-relative by protocol: it never names a host, so one tenant's host cannot
  # reach another tenant's page object through it. Partitions: several parameters, and a
  # percent-encoded non-ASCII value, which must come back byte for byte rather than re-encoded.
  test "page url keeps several query parameters and stays origin-relative" do
    http_headers_3 =
      begin
        fx3_version = ViteRuby.digest
        begin
          f3_headers = as_user_headers(@user, host: @host)
          f3_host = f3_headers["Host"]
          f3_route =
            begin
              Rails.application.routes.recognize_path("https://#{f3_host}/") if f3_host.present?
            rescue ActionController::RoutingError
              nil
            end
          f3_family, f3_surface = f3_route&.fetch(:controller)&.split("/")
          if %w(base warp core edit).include?(f3_family) && f3_surface == "app"
            f3_client_id =
              case f3_family
              when "base" then "base-#{f3_surface}-ww"
              when "edit" then "edit-org"
              else "#{f3_family}-#{f3_surface}"
              end
            f3_token = ClientToken.find_by!(public_id: f3_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f3_client = OidcClientRegistry.find!(f3_client_id)
            f3_key = [f3_client.client_id, f3_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f3_key] && f3_token.currently_usable? &&
                !(f3_token.device_session_id && ClientRpSession.exists?(
                  device_session_id: f3_token.device_session_id,
                  oidc_client_id: f3_client.client_id,
                  revoked_at: nil,
                ))
              f3_token.rotate_refresh_token! unless f3_token.device_session_record.current_refresh_token_id
              f3_now = Time.current
              f3_session = ClientRpSession.create!(
                client_token: f3_token, oidc_client_id: f3_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f3_now,
                refresh_token_expires_at: f3_now + 10.minutes,
              )
              f3_access = AuthenticationTokenService.encode(
                f3_token.actor_record, host: f3_host, resource_type: "client",
                                       session_public_id: f3_token.public_id,
                                       base_session_public_id: f3_token.public_id,
                                       oidc_sid: f3_session.public_id, oidc_jti: f3_session.oidc_jti,
                                       expires_at: f3_now + 10.minutes, scopes: %w(openid profile),
                                       issuer: OidcIssuer.for_client(f3_client), audiences: [f3_client.aud],
                                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f3_client),
                                       subject: OidcSubject.for(
                                         f3_token.actor_record,
                                         resource_type: "client",
                                       ), client_id: f3_client.client_id,
              )
              @base_browser_rp_credentials[f3_key] =
                [f3_access, f3_session.issue_refresh_token!]
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
        end.merge(inertia_headers(version: fx3_version))
      end
    get(
      base_app_groups_url(ri: "jp", page: "2", host: @host),
      headers: http_headers_3,
    )

    assert_response :success
    assert_equal "/groups?page=2&ri=jp", response.parsed_body.fetch("url")
  end

  test "page url keeps a percent-encoded non-ASCII query value unchanged" do
    http_headers_2 =
      begin
        fx4_version = ViteRuby.digest
        begin
          f4_headers = as_user_headers(@user, host: @host)
          f4_host = f4_headers["Host"]
          f4_route =
            begin
              Rails.application.routes.recognize_path("https://#{f4_host}/") if f4_host.present?
            rescue ActionController::RoutingError
              nil
            end
          f4_family, f4_surface = f4_route&.fetch(:controller)&.split("/")
          if %w(base warp core edit).include?(f4_family) && f4_surface == "app"
            f4_client_id =
              case f4_family
              when "base" then "base-#{f4_surface}-ww"
              when "edit" then "edit-org"
              else "#{f4_family}-#{f4_surface}"
              end
            f4_token = ClientToken.find_by!(public_id: f4_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f4_client = OidcClientRegistry.find!(f4_client_id)
            f4_key = [f4_client.client_id, f4_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f4_key] && f4_token.currently_usable? &&
                !(f4_token.device_session_id && ClientRpSession.exists?(
                  device_session_id: f4_token.device_session_id,
                  oidc_client_id: f4_client.client_id,
                  revoked_at: nil,
                ))
              f4_token.rotate_refresh_token! unless f4_token.device_session_record.current_refresh_token_id
              f4_now = Time.current
              f4_session = ClientRpSession.create!(
                client_token: f4_token, oidc_client_id: f4_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f4_now,
                refresh_token_expires_at: f4_now + 10.minutes,
              )
              f4_access = AuthenticationTokenService.encode(
                f4_token.actor_record, host: f4_host, resource_type: "client",
                                       session_public_id: f4_token.public_id,
                                       base_session_public_id: f4_token.public_id,
                                       oidc_sid: f4_session.public_id, oidc_jti: f4_session.oidc_jti,
                                       expires_at: f4_now + 10.minutes, scopes: %w(openid profile),
                                       issuer: OidcIssuer.for_client(f4_client), audiences: [f4_client.aud],
                                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f4_client),
                                       subject: OidcSubject.for(
                                         f4_token.actor_record,
                                         resource_type: "client",
                                       ), client_id: f4_client.client_id,
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
        end.merge(inertia_headers(version: fx4_version))
      end
    get(
      "https://#{@host}/groups?ri=jp&q=%E6%9D%B1%E4%BA%AC%20a%2Bb",
      headers: http_headers_2,
    )

    assert_response :success
    assert_equal "/groups?ri=jp&q=%E6%9D%B1%E4%BA%AC%20a%2Bb", response.parsed_body.fetch("url")
  end

  # The version is derived from the Vite sources once per process, so a request for another
  # tenant's host cannot make it differ.
  test "asset version is identical for an Inertia page served on another surface host" do
    http_headers_1 =
      begin
        fx5_version = ViteRuby.digest
        begin
          f5_headers = as_user_headers(@user, host: @host)
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
              when "edit" then "edit-org"
              else "#{f5_family}-#{f5_surface}"
              end
            f5_token = ClientToken.find_by!(public_id: f5_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f5_client = OidcClientRegistry.find!(f5_client_id)
            f5_key = [f5_client.client_id, f5_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f5_key] && f5_token.currently_usable? &&
                !(f5_token.device_session_id && ClientRpSession.exists?(
                  device_session_id: f5_token.device_session_id,
                  oidc_client_id: f5_client.client_id,
                  revoked_at: nil,
                ))
              f5_token.rotate_refresh_token! unless f5_token.device_session_record.current_refresh_token_id
              f5_now = Time.current
              f5_session = ClientRpSession.create!(
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
        end.merge(inertia_headers(version: fx5_version))
      end
    get(
      base_app_groups_url(ri: "jp", host: @host),
      headers: http_headers_1,
    )

    assert_response :success

    app_version = response.parsed_body.fetch("version")
    com_host = configured_host(:base_corporate)

    get(
      base_com_preference_url(ri: "jp", host: com_host),
      headers: { "Host" => com_host, "X-Inertia" => "true", "X-Inertia-Version" => app_version },
    )

    assert_response :success
    assert_equal app_version, response.parsed_body.fetch("version")
  end

  # The stale-version refresh names the request's own origin. Sent to the com host, it must come
  # back for the com host and never for the app host this test class otherwise uses.
  test "a stale version refresh on another surface host names that host and keeps the query" do
    com_host = configured_host(:base_corporate)

    get(
      base_com_preference_url(ri: "jp", host: com_host),
      headers: { "Host" => com_host, "X-Inertia" => "true", "X-Inertia-Version" => "stale-asset-version" },
    )

    assert_response :conflict

    location = URI.parse(response.headers["X-Inertia-Location"])

    assert_equal com_host, location.host
    assert_equal "/preference", location.path
    assert_equal "ri=jp", location.query
    assert_not_equal @host, location.host
  end

  test "an Inertia visit carrying a stale asset version is answered with a hard location refresh" do
    http_headers_0 =
      begin
        fx6_version = "stale-asset-version"
        begin
          f6_headers = as_user_headers(@user, host: @host)
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
              when "edit" then "edit-org"
              else "#{f6_family}-#{f6_surface}"
              end
            f6_token = ClientToken.find_by!(public_id: f6_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f6_client = OidcClientRegistry.find!(f6_client_id)
            f6_key = [f6_client.client_id, f6_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f6_key] && f6_token.currently_usable? &&
                !(f6_token.device_session_id && ClientRpSession.exists?(
                  device_session_id: f6_token.device_session_id,
                  oidc_client_id: f6_client.client_id,
                  revoked_at: nil,
                ))
              f6_token.rotate_refresh_token! unless f6_token.device_session_record.current_refresh_token_id
              f6_now = Time.current
              f6_session = ClientRpSession.create!(
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
        end.merge(inertia_headers(version: fx6_version))
      end
    get(
      base_app_groups_url(ri: "jp", host: @host),
      headers: http_headers_0,
    )

    assert_response :conflict
    assert_equal(
      base_app_groups_url(ri: "jp", host: @host),
      response.headers["X-Inertia-Location"],
    )
  end

  # An Inertia visit is a `fetch` call. A 302 is followed transparently by the browser, so the
  # client receives the sign-in HTML page as the body of what it believes is an Inertia response,
  # throws "All Inertia requests must receive a valid Inertia response", and leaves the SPA on the
  # stale current page. The protocol's answer for leaving the Inertia application is a 409 with
  # X-Inertia-Location, which the client turns into a full document visit.
  test "an unauthenticated Inertia visit leaves the app with a location refresh, not a redirect" do
    get(base_app_groups_url(ri: "jp", host: @host), headers: inertia_headers(version: ViteRuby.digest))

    assert_response :conflict

    location = response.headers["X-Inertia-Location"]

    assert_predicate location, :present?

    assert_base_sign_entry_redirect(location, surface: :app)
  end

  test "a plain unauthenticated browser request still redirects" do
    get(base_app_groups_url(ri: "jp", host: @host), headers: host_headers(@host))

    assert_response :redirect
  end

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def inertia_headers(version: nil)
    headers = host_headers(@host).merge(
      "X-Inertia" => "true",
      "Accept" => "text/html, application/xhtml+xml",
    )
    headers["X-Inertia-Version"] = version if version
    headers
  end

  def initial_page
    element = css_select("script[data-page='app']").first

    assert element, "the initial response must embed the Inertia page object"

    JSON.parse(element.text)
  end
end
