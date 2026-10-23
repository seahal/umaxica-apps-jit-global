# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::Identity::EmailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    https!
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    @client = clients(:one)
    @passkey = @client.client_passkeys.create!(
      webauthn_id: "app-email-controller-#{SecureRandom.hex(8)}",
      public_key: "public-key-#{SecureRandom.hex(8)}",
      description: "Email controller test passkey",
      uv_verified_at: Time.current,
    )
    @email = ClientEmail.create!(
      user: @client, address: "app-email-destroy-#{SecureRandom.hex(4)}@example.com", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    ).tap(&:finalize_binding!)
  end

  test "destroy with fresh step-up removes the email" do
    http_headers_2 =
      begin
        fx0_step_up_scope = "settings_email"
        fx0_token = ClientToken.create!(
          authentication_epoch: 0,
          user: @client, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
          user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 1.day.from_now,
          root_login_established_at: Time.current, established_authentication_method: "passkey",
        )
        BaseSelectorBootstrapAuthority.call(surface: :app, principal: @client)
        BaseSelectorAuthority.prepare(surface: :app, principal: @client, session: fx0_token)
        if fx0_step_up_scope
          _, fx0_raw_verification = ClientVerification.issue_for_token!(token: fx0_token)
          cookies[ClientVerification.cookie_name] = fx0_raw_verification
          fx0_token.update!(
            last_step_up_at: Time.current, last_step_up_scope: fx0_step_up_scope,
            last_step_up_aal: "aal2", last_step_up_method: "passkey",
            last_step_up_session_public_id: fx0_token.public_id, last_step_up_purpose: "step_up",
            last_step_up_audience: "step_up:app", last_step_up_credential_ref: @passkey.public_id,
            last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
            last_step_up_full_reauthentication: false,
          )
        end
        begin
          f0_cookie_pairs =
            begin
              f0_host = @host
              f0_token = fx0_token
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
                    authentication_epoch: 0,
                    client_token: f0_token, oidc_client_id: f0_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f0_now,
                    refresh_token_expires_at: f0_now + 10.minutes,
                  )
                  f0_access = AuthenticationTokenService.encode(
                    @client, host: f0_host, resource_type: "client",
                             session_public_id: f0_token.public_id, base_session_public_id: f0_token.public_id,
                             oidc_sid: f0_session.public_id, oidc_jti: f0_session.oidc_jti,
                             expires_at: f0_now + 10.minutes, scopes: %w(openid profile),
                             issuer: OidcIssuer.for_client(f0_client), audiences: [f0_client.aud],
                             jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f0_client),
                             subject: OidcSubject.for(
                               @client,
                               resource_type: "client",
                             ), client_id: f0_client.client_id,
                  )
                  @base_browser_rp_credentials[f0_key] =
                    [f0_access, f0_session.issue_refresh_token!]
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
        begin
          f0_headers = as_user_headers(
            @client,
            host: @host,
            session_public_id: fx0_token.public_id,
          )
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
            f0_token = ClientToken.find_by!(public_id: f0_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
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
        end.except("Cookie", "HTTP_COOKIE")
      end
    delete base_app_identity_email_url(@email.public_id, ri: "jp", host: @host),
           headers: http_headers_2

    assert_response :see_other
    assert_equal ClientEmailStatus::DELETED, @email.reload.user_email_status_id
    assert_predicate @email, :binding_released?
    audit = ClientContactAuditOutbox.find_by!(contact_ref: @email.public_id, event_name: "released")

    assert_equal @client.public_id, audit.owner_ref
    assert_equal @client.public_id, audit.actor_ref
    assert_nil audit.acknowledged_at
  end

  test "destroy without fresh step-up is refused and keeps the email" do
    http_headers_1 =
      begin
        fx1_step_up_scope = nil
        fx1_token = ClientToken.create!(
          authentication_epoch: 0,
          user: @client, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
          user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 1.day.from_now,
          root_login_established_at: Time.current, established_authentication_method: "passkey",
        )
        BaseSelectorBootstrapAuthority.call(surface: :app, principal: @client)
        BaseSelectorAuthority.prepare(surface: :app, principal: @client, session: fx1_token)
        if fx1_step_up_scope
          _, fx1_raw_verification = ClientVerification.issue_for_token!(token: fx1_token)
          cookies[ClientVerification.cookie_name] = fx1_raw_verification
          fx1_token.update!(
            last_step_up_at: Time.current, last_step_up_scope: fx1_step_up_scope,
            last_step_up_aal: "aal2", last_step_up_method: "passkey",
            last_step_up_session_public_id: fx1_token.public_id, last_step_up_purpose: "step_up",
            last_step_up_audience: "step_up:app", last_step_up_credential_ref: @passkey.public_id,
            last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
            last_step_up_full_reauthentication: false,
          )
        end
        begin
          f1_cookie_pairs =
            begin
              f1_host = @host
              f1_token = fx1_token
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
                    authentication_epoch: 0,
                    client_token: f1_token, oidc_client_id: f1_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f1_now,
                    refresh_token_expires_at: f1_now + 10.minutes,
                  )
                  f1_access = AuthenticationTokenService.encode(
                    @client, host: f1_host, resource_type: "client",
                             session_public_id: f1_token.public_id, base_session_public_id: f1_token.public_id,
                             oidc_sid: f1_session.public_id, oidc_jti: f1_session.oidc_jti,
                             expires_at: f1_now + 10.minutes, scopes: %w(openid profile),
                             issuer: OidcIssuer.for_client(f1_client), audiences: [f1_client.aud],
                             jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f1_client),
                             subject: OidcSubject.for(
                               @client,
                               resource_type: "client",
                             ), client_id: f1_client.client_id,
                  )
                  @base_browser_rp_credentials[f1_key] =
                    [f1_access, f1_session.issue_refresh_token!]
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
        begin
          f1_headers = as_user_headers(
            @client,
            host: @host,
            session_public_id: fx1_token.public_id,
          )
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
            f1_token = ClientToken.find_by!(public_id: f1_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
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
        end.except("Cookie", "HTTP_COOKIE")
      end
    delete base_app_identity_email_url(@email.public_id, ri: "jp", host: @host),
           headers: http_headers_1

    assert_response :unauthorized
    assert ClientEmail.exists?(@email.id)
  end

  test "destroy with step-up for another scope is refused and keeps the email" do
    http_headers_0 =
      begin
        fx2_step_up_scope = "settings_secret_credential"
        fx2_token = ClientToken.create!(
          authentication_epoch: 0,
          user: @client, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
          user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 1.day.from_now,
          root_login_established_at: Time.current, established_authentication_method: "passkey",
        )
        BaseSelectorBootstrapAuthority.call(surface: :app, principal: @client)
        BaseSelectorAuthority.prepare(surface: :app, principal: @client, session: fx2_token)
        if fx2_step_up_scope
          _, fx2_raw_verification = ClientVerification.issue_for_token!(token: fx2_token)
          cookies[ClientVerification.cookie_name] = fx2_raw_verification
          fx2_token.update!(
            last_step_up_at: Time.current, last_step_up_scope: fx2_step_up_scope,
            last_step_up_aal: "aal2", last_step_up_method: "passkey",
            last_step_up_session_public_id: fx2_token.public_id, last_step_up_purpose: "step_up",
            last_step_up_audience: "step_up:app", last_step_up_credential_ref: @passkey.public_id,
            last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
            last_step_up_full_reauthentication: false,
          )
        end
        begin
          f2_cookie_pairs =
            begin
              f2_host = @host
              f2_token = fx2_token
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
                    authentication_epoch: 0,
                    client_token: f2_token, oidc_client_id: f2_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f2_now,
                    refresh_token_expires_at: f2_now + 10.minutes,
                  )
                  f2_access = AuthenticationTokenService.encode(
                    @client, host: f2_host, resource_type: "client",
                             session_public_id: f2_token.public_id, base_session_public_id: f2_token.public_id,
                             oidc_sid: f2_session.public_id, oidc_jti: f2_session.oidc_jti,
                             expires_at: f2_now + 10.minutes, scopes: %w(openid profile),
                             issuer: OidcIssuer.for_client(f2_client), audiences: [f2_client.aud],
                             jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f2_client),
                             subject: OidcSubject.for(
                               @client,
                               resource_type: "client",
                             ), client_id: f2_client.client_id,
                  )
                  @base_browser_rp_credentials[f2_key] =
                    [f2_access, f2_session.issue_refresh_token!]
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
        begin
          f2_headers = as_user_headers(
            @client,
            host: @host,
            session_public_id: fx2_token.public_id,
          )
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
            f2_token = ClientToken.find_by!(public_id: f2_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
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
        end.except("Cookie", "HTTP_COOKIE")
      end
    delete base_app_identity_email_url(@email.public_id, ri: "jp", host: @host),
           headers: http_headers_0

    assert_response :unauthorized
    assert ClientEmail.exists?(@email.id)
  end

  private
end
