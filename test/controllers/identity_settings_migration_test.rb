# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentitySettingsMigrationTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_token_kinds, :client_token_statuses

  setup do
    https!
    @sign_host = ENV.fetch("PRIVATE_AUTH_SERVICE_URL")
    @acme_host = ENV.fetch("PRIVATE_BASE_SERVICE_URL")
    host! @acme_host
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
  end

  test "sign settings root remains limited to retained credential settings" do
    get sign_app_settings_url(ri: "jp"), headers: sign_headers

    assert_response :redirect
  end

  test "moved sign get routes are unroutable" do
    assert_unroutable_auth_settings_path("/settings/emails", :get)
    assert_unroutable_auth_settings_path("/settings/birthdate", :get)
    assert_unroutable_auth_settings_path("/settings/activities", :get)
  end

  test "moved sign mutation routes are unroutable" do
    assert_unroutable_auth_settings_path("/settings/emails/missing", :patch)
    assert_unroutable_auth_settings_path("/settings/emails/missing", :delete)
    assert_unroutable_auth_settings_path("/settings/mfa/reset", :post)
  end

  test "sign passkey management route is retired" do
    assert_unroutable_auth_settings_path("/settings/passkeys", :get)
  end

  test "acme identity routes exist and authenticate" do
    http_headers_3 =
      begin
        BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
        BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)
        begin
          f0_cookie_pairs =
            begin
              f0_host = @acme_host
              f0_token = @token
              f0_client = OidcClientRegistry.find!("base-app-ww")
              f0_key = [f0_client.client_id, f0_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f0_key] ||
                  (f0_token.currently_usable? &&
                    !(f0_token.device_session_id && OpAppGrant.exists?(
                      device_session_id: f0_token.device_session_id,
                      oidc_client_id: f0_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f0_key]
                  f0_token.rotate_refresh_token! unless f0_token.device_session_record.current_refresh_token_id
                  f0_now = Time.current
                  f0_session = OpAppGrant.create!(
                    client_token: f0_token, oidc_client_id: f0_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f0_now,
                    refresh_token_expires_at: f0_now + 10.minutes,
                  )
                  f0_access = AuthenticationTokenService.encode(
                    @user, host: f0_host, resource_type: "client",
                           session_public_id: f0_token.public_id, base_session_public_id: f0_token.public_id,
                           oidc_sid: f0_session.public_id, oidc_jti: f0_session.oidc_jti,
                           expires_at: f0_now + 10.minutes, scopes: %w(openid profile),
                           issuer: OidcIssuer.for_client(f0_client), audiences: [f0_client.aud],
                           jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f0_client),
                           subject: OidcSubject.for(
                             @user,
                             resource_type: "client",
                           ), client_id: f0_client.client_id,
                  )
                  @base_browser_rp_credentials[f0_key] = [f0_access, f0_session.issue_refresh_token!]
                end
                f0_access, f0_refresh = @base_browser_rp_credentials.fetch(f0_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f0_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f0_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f0_cookie_pairs, URI.parse("https://#{f0_host}/"))
        end
        acme_headers
      end
    get acme_app_identity_url(ri: "jp"), headers: http_headers_3

    assert_response :success

    http_headers_2 =
      begin
        BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
        BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)
        begin
          f1_cookie_pairs =
            begin
              f1_host = @acme_host
              f1_token = @token
              f1_client = OidcClientRegistry.find!("base-app-ww")
              f1_key = [f1_client.client_id, f1_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f1_key] ||
                  (f1_token.currently_usable? &&
                    !(f1_token.device_session_id && OpAppGrant.exists?(
                      device_session_id: f1_token.device_session_id,
                      oidc_client_id: f1_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f1_key]
                  f1_token.rotate_refresh_token! unless f1_token.device_session_record.current_refresh_token_id
                  f1_now = Time.current
                  f1_session = OpAppGrant.create!(
                    client_token: f1_token, oidc_client_id: f1_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f1_now,
                    refresh_token_expires_at: f1_now + 10.minutes,
                  )
                  f1_access = AuthenticationTokenService.encode(
                    @user, host: f1_host, resource_type: "client",
                           session_public_id: f1_token.public_id, base_session_public_id: f1_token.public_id,
                           oidc_sid: f1_session.public_id, oidc_jti: f1_session.oidc_jti,
                           expires_at: f1_now + 10.minutes, scopes: %w(openid profile),
                           issuer: OidcIssuer.for_client(f1_client), audiences: [f1_client.aud],
                           jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f1_client),
                           subject: OidcSubject.for(
                             @user,
                             resource_type: "client",
                           ), client_id: f1_client.client_id,
                  )
                  @base_browser_rp_credentials[f1_key] = [f1_access, f1_session.issue_refresh_token!]
                end
                f1_access, f1_refresh = @base_browser_rp_credentials.fetch(f1_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f1_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f1_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f1_cookie_pairs, URI.parse("https://#{f1_host}/"))
        end
        acme_headers
      end
    get acme_app_identity_emails_url(ri: "jp"), headers: http_headers_2

    assert_response :success

    http_headers_1 =
      begin
        BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
        BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)
        begin
          f2_cookie_pairs =
            begin
              f2_host = @acme_host
              f2_token = @token
              f2_client = OidcClientRegistry.find!("base-app-ww")
              f2_key = [f2_client.client_id, f2_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f2_key] ||
                  (f2_token.currently_usable? &&
                    !(f2_token.device_session_id && OpAppGrant.exists?(
                      device_session_id: f2_token.device_session_id,
                      oidc_client_id: f2_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f2_key]
                  f2_token.rotate_refresh_token! unless f2_token.device_session_record.current_refresh_token_id
                  f2_now = Time.current
                  f2_session = OpAppGrant.create!(
                    client_token: f2_token, oidc_client_id: f2_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f2_now,
                    refresh_token_expires_at: f2_now + 10.minutes,
                  )
                  f2_access = AuthenticationTokenService.encode(
                    @user, host: f2_host, resource_type: "client",
                           session_public_id: f2_token.public_id, base_session_public_id: f2_token.public_id,
                           oidc_sid: f2_session.public_id, oidc_jti: f2_session.oidc_jti,
                           expires_at: f2_now + 10.minutes, scopes: %w(openid profile),
                           issuer: OidcIssuer.for_client(f2_client), audiences: [f2_client.aud],
                           jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f2_client),
                           subject: OidcSubject.for(
                             @user,
                             resource_type: "client",
                           ), client_id: f2_client.client_id,
                  )
                  @base_browser_rp_credentials[f2_key] = [f2_access, f2_session.issue_refresh_token!]
                end
                f2_access, f2_refresh = @base_browser_rp_credentials.fetch(f2_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f2_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f2_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f2_cookie_pairs, URI.parse("https://#{f2_host}/"))
        end
        acme_headers
      end
    get acme_app_identity_sessions_url(ri: "jp"), headers: http_headers_1

    assert_response :success
  end

  test "acme identity does not depend on sign settings path in overview" do
    http_headers_0 =
      begin
        BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
        BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)
        begin
          f3_cookie_pairs =
            begin
              f3_host = @acme_host
              f3_token = @token
              f3_client = OidcClientRegistry.find!("base-app-ww")
              f3_key = [f3_client.client_id, f3_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f3_key] ||
                  (f3_token.currently_usable? &&
                    !(f3_token.device_session_id && OpAppGrant.exists?(
                      device_session_id: f3_token.device_session_id,
                      oidc_client_id: f3_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f3_key]
                  f3_token.rotate_refresh_token! unless f3_token.device_session_record.current_refresh_token_id
                  f3_now = Time.current
                  f3_session = OpAppGrant.create!(
                    client_token: f3_token, oidc_client_id: f3_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f3_now,
                    refresh_token_expires_at: f3_now + 10.minutes,
                  )
                  f3_access = AuthenticationTokenService.encode(
                    @user, host: f3_host, resource_type: "client",
                           session_public_id: f3_token.public_id, base_session_public_id: f3_token.public_id,
                           oidc_sid: f3_session.public_id, oidc_jti: f3_session.oidc_jti,
                           expires_at: f3_now + 10.minutes, scopes: %w(openid profile),
                           issuer: OidcIssuer.for_client(f3_client), audiences: [f3_client.aud],
                           jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f3_client),
                           subject: OidcSubject.for(
                             @user,
                             resource_type: "client",
                           ), client_id: f3_client.client_id,
                  )
                  @base_browser_rp_credentials[f3_key] = [f3_access, f3_session.issue_refresh_token!]
                end
                f3_access, f3_refresh = @base_browser_rp_credentials.fetch(f3_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f3_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f3_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f3_cookie_pairs, URI.parse("https://#{f3_host}/"))
        end
        acme_headers
      end
    get acme_app_identity_url(ri: "jp"), headers: http_headers_0

    assert_response :success
    assert_no_match(%r{/settings(?!/google|/apple)}, response.body)
  end

  private

  def sign_headers
    bearer_headers(
      AuthenticationToken.encode(
        @user, host: @sign_host, session_public_id: @token.public_id, resource_type: "client",
               jwt_issuer_id: "surface:AUTH_APP",
      ),
      host: @sign_host,
    )
  end

  def acme_headers
    as_user_headers(@user, host: @acme_host, session_public_id: @token.public_id)
      .except("Cookie", "HTTP_COOKIE")
  end

  def bearer_headers(token, host: nil, headers: {})
    base = host.present? ? { "Host" => host } : {}
    base.merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def assert_unroutable_auth_settings_path(path, method)
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{@sign_host}#{path}",
        method: method,
      )
    end
  end
end

# DAMP local route helper aliases for former shared test support.
class IdentitySettingsMigrationTest
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
