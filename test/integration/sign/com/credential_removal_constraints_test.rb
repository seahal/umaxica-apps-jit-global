# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignComCredentialRemovalConstraintsTest < ActionDispatch::IntegrationTest
  setup do
    https!
    @host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    @base_host = @host
    host! @base_host
    Prosopite.pause do
      VisitorStatus.find_or_create_by!(id: VisitorStatus::ACTIVE)
      VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
      VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
      VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
      VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
      VisitorSecretCredentialKind.find_or_create_by!(id: VisitorSecretCredentialKind::LOGIN)
      VisitorSecretCredentialStatus.find_or_create_by!(id: VisitorSecretCredentialStatus::ACTIVE)
      VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
      VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::NOTHING)
      VisitorTokenStatus.ensure_defaults!
      VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
    end
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "email removal is blocked when it would remove the last usable step-up capability" do
    visitor = create_visitor
    email = create_verified_email(visitor, "com-removal-contact-email@example.com")
    create_verified_telephone(visitor, "+819022220000")

    http_headers_5 =
      begin
        fx0_visitor = visitor
        fx0_scope = "settings_email"
        fx0_host = @base_host
        fx0_token = VisitorToken.create!(
          authentication_epoch: 0,
          visitor: fx0_visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
          root_login_established_at: Time.current, established_authentication_method: "passkey",
        )
        BaseSelectorBootstrapAuthority.call(surface: :com, principal: fx0_visitor)
        BaseSelectorAuthority.prepare(surface: :com, principal: fx0_visitor, session: fx0_token)
        satisfy_visitor_verification(fx0_token)
        mark_token_step_up_satisfied_for_test(fx0_token, scope: fx0_scope)
        begin
          f0_cookie_pairs =
            begin
              f0_host = fx0_host
              f0_token = fx0_token
              f0_client = OidcClientRegistry.find!("base-com-ww")
              f0_key = [f0_client.client_id, f0_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f0_key] ||
                  (f0_token.currently_usable? &&
                    !(f0_token.device_session_id && OpComGrant.exists?(
                      device_session_id: f0_token.device_session_id,
                      oidc_client_id: f0_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f0_key]
                  f0_token.rotate_refresh_token! unless f0_token.device_session_record.current_refresh_token_id
                  f0_now = Time.current
                  f0_session = OpComGrant.create!(
                    authentication_epoch: 0,
                    visitor_token: f0_token, oidc_client_id: f0_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f0_now,
                    refresh_token_expires_at: f0_now + 10.minutes,
                  )
                  f0_access = AuthenticationTokenService.encode(
                    fx0_visitor,
                    host: f0_host,
                    resource_type: "visitor",
                    session_public_id: f0_token.public_id,
                    base_session_public_id: f0_token.public_id,
                    oidc_sid: f0_session.public_id,
                    oidc_jti: f0_session.oidc_jti,
                    expires_at: f0_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f0_client),
                    audiences: [f0_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f0_client),
                    subject: OidcSubject.for(
                      fx0_visitor,
                      resource_type: "visitor",
                    ),
                    client_id: f0_client.client_id,
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
          f0_headers = as_visitor_headers(fx0_visitor, host: fx0_host, session_public_id: fx0_token.public_id)
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
              when "edit" then "edit-org-ww"
              else "#{f0_family}-#{f0_surface}"
              end
            f0_token = VisitorToken.find_by!(public_id: f0_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f0_client = OidcClientRegistry.find!(f0_client_id)
            f0_key = [f0_client.client_id, f0_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f0_key] && f0_token.currently_usable? &&
                !(f0_token.device_session_id && OpComGrant.exists?(
                  device_session_id: f0_token.device_session_id,
                  oidc_client_id: f0_client.client_id,
                  revoked_at: nil,
                ))
              f0_token.rotate_refresh_token! unless f0_token.device_session_record.current_refresh_token_id
              f0_now = Time.current
              f0_session = OpComGrant.create!(
                authentication_epoch: 0,
                visitor_token: f0_token, oidc_client_id: f0_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f0_now,
                refresh_token_expires_at: f0_now + 10.minutes,
              )
              f0_access = AuthenticationTokenService.encode(
                f0_token.actor_record,
                host: f0_host,
                resource_type: "visitor",
                session_public_id: f0_token.public_id,
                base_session_public_id: f0_token.public_id,
                oidc_sid: f0_session.public_id,
                oidc_jti: f0_session.oidc_jti,
                expires_at: f0_now + 10.minutes,
                scopes: %w(openid profile),
                issuer: OidcIssuer.for_client(f0_client),
                audiences: [f0_client.aud],
                jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f0_client),
                subject: OidcSubject.for(
                  f0_token.actor_record,
                  resource_type: "visitor",
                ),
                client_id: f0_client.client_id,
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
    delete base_com_identity_email_url(email.public_id, ri: "jp", host: @base_host),
           headers: http_headers_5

    assert_redirected_to base_com_identity_emails_url(ri: "jp", host: @base_host)
    assert_equal VisitorEmailStatus::VERIFIED, email.reload.visitor_email_status_id
    assert_not email.binding_released?
  end

  test "telephone removal may leave a usable passkey-only identity" do
    visitor = create_visitor
    telephone = create_verified_telephone(visitor, "+819022220001")
    create_active_passkey(visitor)

    http_headers_4 =
      begin
        fx1_visitor = visitor
        fx1_scope = "settings_telephone"
        fx1_host = @base_host
        fx1_token = VisitorToken.create!(
          authentication_epoch: 0,
          visitor: fx1_visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
          root_login_established_at: Time.current, established_authentication_method: "passkey",
        )
        BaseSelectorBootstrapAuthority.call(surface: :com, principal: fx1_visitor)
        BaseSelectorAuthority.prepare(surface: :com, principal: fx1_visitor, session: fx1_token)
        satisfy_visitor_verification(fx1_token)
        mark_token_step_up_satisfied_for_test(fx1_token, scope: fx1_scope)
        begin
          f1_cookie_pairs =
            begin
              f1_host = fx1_host
              f1_token = fx1_token
              f1_client = OidcClientRegistry.find!("base-com-ww")
              f1_key = [f1_client.client_id, f1_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f1_key] ||
                  (f1_token.currently_usable? &&
                    !(f1_token.device_session_id && OpComGrant.exists?(
                      device_session_id: f1_token.device_session_id,
                      oidc_client_id: f1_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f1_key]
                  f1_token.rotate_refresh_token! unless f1_token.device_session_record.current_refresh_token_id
                  f1_now = Time.current
                  f1_session = OpComGrant.create!(
                    authentication_epoch: 0,
                    visitor_token: f1_token, oidc_client_id: f1_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f1_now,
                    refresh_token_expires_at: f1_now + 10.minutes,
                  )
                  f1_access = AuthenticationTokenService.encode(
                    fx1_visitor,
                    host: f1_host,
                    resource_type: "visitor",
                    session_public_id: f1_token.public_id,
                    base_session_public_id: f1_token.public_id,
                    oidc_sid: f1_session.public_id,
                    oidc_jti: f1_session.oidc_jti,
                    expires_at: f1_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f1_client),
                    audiences: [f1_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f1_client),
                    subject: OidcSubject.for(
                      fx1_visitor,
                      resource_type: "visitor",
                    ),
                    client_id: f1_client.client_id,
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
          f1_headers = as_visitor_headers(fx1_visitor, host: fx1_host, session_public_id: fx1_token.public_id)
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
              when "edit" then "edit-org-ww"
              else "#{f1_family}-#{f1_surface}"
              end
            f1_token = VisitorToken.find_by!(public_id: f1_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f1_client = OidcClientRegistry.find!(f1_client_id)
            f1_key = [f1_client.client_id, f1_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f1_key] && f1_token.currently_usable? &&
                !(f1_token.device_session_id && OpComGrant.exists?(
                  device_session_id: f1_token.device_session_id,
                  oidc_client_id: f1_client.client_id,
                  revoked_at: nil,
                ))
              f1_token.rotate_refresh_token! unless f1_token.device_session_record.current_refresh_token_id
              f1_now = Time.current
              f1_session = OpComGrant.create!(
                authentication_epoch: 0,
                visitor_token: f1_token, oidc_client_id: f1_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f1_now,
                refresh_token_expires_at: f1_now + 10.minutes,
              )
              f1_access = AuthenticationTokenService.encode(
                f1_token.actor_record,
                host: f1_host,
                resource_type: "visitor",
                session_public_id: f1_token.public_id,
                base_session_public_id: f1_token.public_id,
                oidc_sid: f1_session.public_id,
                oidc_jti: f1_session.oidc_jti,
                expires_at: f1_now + 10.minutes,
                scopes: %w(openid profile),
                issuer: OidcIssuer.for_client(f1_client),
                audiences: [f1_client.aud],
                jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f1_client),
                subject: OidcSubject.for(
                  f1_token.actor_record,
                  resource_type: "visitor",
                ),
                client_id: f1_client.client_id,
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
    delete base_com_identity_telephone_url(telephone.public_id, ri: "jp", host: @base_host),
           headers: http_headers_4

    assert_redirected_to base_com_identity_telephones_url(ri: "jp", host: @base_host)
    assert_equal VisitorTelephoneStatus::DELETED, telephone.reload.visitor_telephone_status_id
    assert_predicate telephone, :binding_released?
  end

  test "passkey removal is blocked when it would remove the last usable step-up capability" do
    visitor = create_visitor
    create_verified_telephone(visitor, "+819022220002")
    create_active_secret_credential(visitor)
    passkey = create_active_passkey(visitor)

    http_headers_3 =
      begin
        fx2_visitor = visitor
        fx2_scope = "settings_passkey"
        fx2_host = @base_host
        fx2_token = VisitorToken.create!(
          authentication_epoch: 0,
          visitor: fx2_visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
          root_login_established_at: Time.current, established_authentication_method: "passkey",
        )
        BaseSelectorBootstrapAuthority.call(surface: :com, principal: fx2_visitor)
        BaseSelectorAuthority.prepare(surface: :com, principal: fx2_visitor, session: fx2_token)
        satisfy_visitor_verification(fx2_token)
        mark_token_step_up_satisfied_for_test(fx2_token, scope: fx2_scope)
        begin
          f2_cookie_pairs =
            begin
              f2_host = fx2_host
              f2_token = fx2_token
              f2_client = OidcClientRegistry.find!("base-com-ww")
              f2_key = [f2_client.client_id, f2_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f2_key] ||
                  (f2_token.currently_usable? &&
                    !(f2_token.device_session_id && OpComGrant.exists?(
                      device_session_id: f2_token.device_session_id,
                      oidc_client_id: f2_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f2_key]
                  f2_token.rotate_refresh_token! unless f2_token.device_session_record.current_refresh_token_id
                  f2_now = Time.current
                  f2_session = OpComGrant.create!(
                    authentication_epoch: 0,
                    visitor_token: f2_token, oidc_client_id: f2_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f2_now,
                    refresh_token_expires_at: f2_now + 10.minutes,
                  )
                  f2_access = AuthenticationTokenService.encode(
                    fx2_visitor,
                    host: f2_host,
                    resource_type: "visitor",
                    session_public_id: f2_token.public_id,
                    base_session_public_id: f2_token.public_id,
                    oidc_sid: f2_session.public_id,
                    oidc_jti: f2_session.oidc_jti,
                    expires_at: f2_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f2_client),
                    audiences: [f2_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f2_client),
                    subject: OidcSubject.for(
                      fx2_visitor,
                      resource_type: "visitor",
                    ),
                    client_id: f2_client.client_id,
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
          f2_headers = as_visitor_headers(fx2_visitor, host: fx2_host, session_public_id: fx2_token.public_id)
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
              when "edit" then "edit-org-ww"
              else "#{f2_family}-#{f2_surface}"
              end
            f2_token = VisitorToken.find_by!(public_id: f2_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f2_client = OidcClientRegistry.find!(f2_client_id)
            f2_key = [f2_client.client_id, f2_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f2_key] && f2_token.currently_usable? &&
                !(f2_token.device_session_id && OpComGrant.exists?(
                  device_session_id: f2_token.device_session_id,
                  oidc_client_id: f2_client.client_id,
                  revoked_at: nil,
                ))
              f2_token.rotate_refresh_token! unless f2_token.device_session_record.current_refresh_token_id
              f2_now = Time.current
              f2_session = OpComGrant.create!(
                authentication_epoch: 0,
                visitor_token: f2_token, oidc_client_id: f2_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f2_now,
                refresh_token_expires_at: f2_now + 10.minutes,
              )
              f2_access = AuthenticationTokenService.encode(
                f2_token.actor_record,
                host: f2_host,
                resource_type: "visitor",
                session_public_id: f2_token.public_id,
                base_session_public_id: f2_token.public_id,
                oidc_sid: f2_session.public_id,
                oidc_jti: f2_session.oidc_jti,
                expires_at: f2_now + 10.minutes,
                scopes: %w(openid profile),
                issuer: OidcIssuer.for_client(f2_client),
                audiences: [f2_client.aud],
                jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f2_client),
                subject: OidcSubject.for(
                  f2_token.actor_record,
                  resource_type: "visitor",
                ),
                client_id: f2_client.client_id,
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
    delete base_com_identity_passkey_url(passkey.public_id, ri: "jp", host: @base_host),
           headers: http_headers_3

    assert_response :unprocessable_content
    assert_equal VisitorPasskeyStatus::ACTIVE, passkey.reload.status_id
  end

  test "secret removal requires an independent step-up method" do
    visitor = create_visitor
    create_verified_telephone(visitor, "+819022220003")
    secret_credential = create_active_secret_credential(visitor)

    http_headers_2 =
      begin
        fx3_visitor = visitor
        fx3_scope = "settings_secret_credential"
        fx3_host = @base_host
        fx3_token = VisitorToken.create!(
          authentication_epoch: 0,
          visitor: fx3_visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
          root_login_established_at: Time.current, established_authentication_method: "passkey",
        )
        BaseSelectorBootstrapAuthority.call(surface: :com, principal: fx3_visitor)
        BaseSelectorAuthority.prepare(surface: :com, principal: fx3_visitor, session: fx3_token)
        satisfy_visitor_verification(fx3_token)
        mark_token_step_up_satisfied_for_test(fx3_token, scope: fx3_scope)
        begin
          f3_cookie_pairs =
            begin
              f3_host = fx3_host
              f3_token = fx3_token
              f3_client = OidcClientRegistry.find!("base-com-ww")
              f3_key = [f3_client.client_id, f3_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f3_key] ||
                  (f3_token.currently_usable? &&
                    !(f3_token.device_session_id && OpComGrant.exists?(
                      device_session_id: f3_token.device_session_id,
                      oidc_client_id: f3_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f3_key]
                  f3_token.rotate_refresh_token! unless f3_token.device_session_record.current_refresh_token_id
                  f3_now = Time.current
                  f3_session = OpComGrant.create!(
                    authentication_epoch: 0,
                    visitor_token: f3_token, oidc_client_id: f3_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f3_now,
                    refresh_token_expires_at: f3_now + 10.minutes,
                  )
                  f3_access = AuthenticationTokenService.encode(
                    fx3_visitor,
                    host: f3_host,
                    resource_type: "visitor",
                    session_public_id: f3_token.public_id,
                    base_session_public_id: f3_token.public_id,
                    oidc_sid: f3_session.public_id,
                    oidc_jti: f3_session.oidc_jti,
                    expires_at: f3_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f3_client),
                    audiences: [f3_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f3_client),
                    subject: OidcSubject.for(
                      fx3_visitor,
                      resource_type: "visitor",
                    ),
                    client_id: f3_client.client_id,
                  )
                  @base_browser_rp_credentials[f3_key] =
                    [f3_access, f3_session.issue_refresh_token!]
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
        begin
          f3_headers = as_visitor_headers(fx3_visitor, host: fx3_host, session_public_id: fx3_token.public_id)
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
              when "edit" then "edit-org-ww"
              else "#{f3_family}-#{f3_surface}"
              end
            f3_token = VisitorToken.find_by!(public_id: f3_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f3_client = OidcClientRegistry.find!(f3_client_id)
            f3_key = [f3_client.client_id, f3_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f3_key] && f3_token.currently_usable? &&
                !(f3_token.device_session_id && OpComGrant.exists?(
                  device_session_id: f3_token.device_session_id,
                  oidc_client_id: f3_client.client_id,
                  revoked_at: nil,
                ))
              f3_token.rotate_refresh_token! unless f3_token.device_session_record.current_refresh_token_id
              f3_now = Time.current
              f3_session = OpComGrant.create!(
                authentication_epoch: 0,
                visitor_token: f3_token, oidc_client_id: f3_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f3_now,
                refresh_token_expires_at: f3_now + 10.minutes,
              )
              f3_access = AuthenticationTokenService.encode(
                f3_token.actor_record,
                host: f3_host,
                resource_type: "visitor",
                session_public_id: f3_token.public_id,
                base_session_public_id: f3_token.public_id,
                oidc_sid: f3_session.public_id,
                oidc_jti: f3_session.oidc_jti,
                expires_at: f3_now + 10.minutes,
                scopes: %w(openid profile),
                issuer: OidcIssuer.for_client(f3_client),
                audiences: [f3_client.aud],
                jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f3_client),
                subject: OidcSubject.for(
                  f3_token.actor_record,
                  resource_type: "visitor",
                ),
                client_id: f3_client.client_id,
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
        end.except("Cookie", "HTTP_COOKIE")
      end
    with_forgery_protection do
      get base_com_identity_secrets_url(ri: "jp", host: @base_host), headers: http_headers_2

      assert_response :success
      csrf_token = response.parsed_body.at_css('meta[name="csrf-token"]')&.[]("content")

      assert_predicate csrf_token, :present?

      delete base_com_identity_secret_url(secret_credential.public_id, ri: "jp", host: @base_host),
             headers: http_headers_2.merge("X-CSRF-Token" => csrf_token)

      assert_response :redirect
      assert_includes response.location, "/verification/setup"
      assert_equal VisitorSecretCredentialStatus::ACTIVE, secret_credential.reload.visitor_secret_credential_status_id
    end
  end

  test "email and passkey removals are allowed when capabilities remain" do
    visitor = create_visitor
    email = create_verified_email(visitor, "com-removal-email-allowed@example.com")
    create_verified_telephone(visitor, "+819022220004")
    passkey = create_active_passkey(visitor)
    create_active_passkey(visitor)

    http_headers_1 =
      begin
        fx4_visitor = visitor
        fx4_scope = "settings_email"
        fx4_host = @base_host
        fx4_token = VisitorToken.create!(
          authentication_epoch: 0,
          visitor: fx4_visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
          root_login_established_at: Time.current, established_authentication_method: "passkey",
        )
        BaseSelectorBootstrapAuthority.call(surface: :com, principal: fx4_visitor)
        BaseSelectorAuthority.prepare(surface: :com, principal: fx4_visitor, session: fx4_token)
        satisfy_visitor_verification(fx4_token)
        mark_token_step_up_satisfied_for_test(fx4_token, scope: fx4_scope)
        begin
          f4_cookie_pairs =
            begin
              f4_host = fx4_host
              f4_token = fx4_token
              f4_client = OidcClientRegistry.find!("base-com-ww")
              f4_key = [f4_client.client_id, f4_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f4_key] ||
                  (f4_token.currently_usable? &&
                    !(f4_token.device_session_id && OpComGrant.exists?(
                      device_session_id: f4_token.device_session_id,
                      oidc_client_id: f4_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f4_key]
                  f4_token.rotate_refresh_token! unless f4_token.device_session_record.current_refresh_token_id
                  f4_now = Time.current
                  f4_session = OpComGrant.create!(
                    authentication_epoch: 0,
                    visitor_token: f4_token, oidc_client_id: f4_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f4_now,
                    refresh_token_expires_at: f4_now + 10.minutes,
                  )
                  f4_access = AuthenticationTokenService.encode(
                    fx4_visitor,
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
                      fx4_visitor,
                      resource_type: "visitor",
                    ),
                    client_id: f4_client.client_id,
                  )
                  @base_browser_rp_credentials[f4_key] =
                    [f4_access, f4_session.issue_refresh_token!]
                end
                f4_access, f4_refresh = @base_browser_rp_credentials.fetch(f4_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f4_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f4_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f4_cookie_pairs, URI.parse("https://#{f4_host}/"))
        end
        begin
          f4_headers = as_visitor_headers(fx4_visitor, host: fx4_host, session_public_id: fx4_token.public_id)
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
              when "edit" then "edit-org-ww"
              else "#{f4_family}-#{f4_surface}"
              end
            f4_token = VisitorToken.find_by!(public_id: f4_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f4_client = OidcClientRegistry.find!(f4_client_id)
            f4_key = [f4_client.client_id, f4_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f4_key] && f4_token.currently_usable? &&
                !(f4_token.device_session_id && OpComGrant.exists?(
                  device_session_id: f4_token.device_session_id,
                  oidc_client_id: f4_client.client_id,
                  revoked_at: nil,
                ))
              f4_token.rotate_refresh_token! unless f4_token.device_session_record.current_refresh_token_id
              f4_now = Time.current
              f4_session = OpComGrant.create!(
                authentication_epoch: 0,
                visitor_token: f4_token, oidc_client_id: f4_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f4_now,
                refresh_token_expires_at: f4_now + 10.minutes,
              )
              f4_access = AuthenticationTokenService.encode(
                f4_token.actor_record,
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
                  f4_token.actor_record,
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
        end.except("Cookie", "HTTP_COOKIE")
      end
    delete base_com_identity_email_url(email.public_id, ri: "jp", host: @base_host),
           headers: http_headers_1

    assert_equal VisitorEmailStatus::DELETED, email.reload.visitor_email_status_id
    assert_predicate email, :binding_released?

    http_headers_0 =
      begin
        fx5_visitor = visitor
        fx5_scope = "settings_passkey"
        fx5_host = @base_host
        fx5_token = VisitorToken.create!(
          authentication_epoch: 0,
          visitor: fx5_visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
          root_login_established_at: Time.current, established_authentication_method: "passkey",
        )
        BaseSelectorBootstrapAuthority.call(surface: :com, principal: fx5_visitor)
        BaseSelectorAuthority.prepare(surface: :com, principal: fx5_visitor, session: fx5_token)
        satisfy_visitor_verification(fx5_token)
        mark_token_step_up_satisfied_for_test(fx5_token, scope: fx5_scope)
        begin
          f5_cookie_pairs =
            begin
              f5_host = fx5_host
              f5_token = fx5_token
              f5_client = OidcClientRegistry.find!("base-com-ww")
              f5_key = [f5_client.client_id, f5_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f5_key] ||
                  (f5_token.currently_usable? &&
                    !(f5_token.device_session_id && OpComGrant.exists?(
                      device_session_id: f5_token.device_session_id,
                      oidc_client_id: f5_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f5_key]
                  f5_token.rotate_refresh_token! unless f5_token.device_session_record.current_refresh_token_id
                  f5_now = Time.current
                  f5_session = OpComGrant.create!(
                    authentication_epoch: 0,
                    visitor_token: f5_token, oidc_client_id: f5_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f5_now,
                    refresh_token_expires_at: f5_now + 10.minutes,
                  )
                  f5_access = AuthenticationTokenService.encode(
                    fx5_visitor,
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
                      fx5_visitor,
                      resource_type: "visitor",
                    ),
                    client_id: f5_client.client_id,
                  )
                  @base_browser_rp_credentials[f5_key] =
                    [f5_access, f5_session.issue_refresh_token!]
                end
                f5_access, f5_refresh = @base_browser_rp_credentials.fetch(f5_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f5_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f5_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f5_cookie_pairs, URI.parse("https://#{f5_host}/"))
        end
        begin
          f5_headers = as_visitor_headers(fx5_visitor, host: fx5_host, session_public_id: fx5_token.public_id)
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
              when "edit" then "edit-org-ww"
              else "#{f5_family}-#{f5_surface}"
              end
            f5_token = VisitorToken.find_by!(public_id: f5_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f5_client = OidcClientRegistry.find!(f5_client_id)
            f5_key = [f5_client.client_id, f5_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f5_key] && f5_token.currently_usable? &&
                !(f5_token.device_session_id && OpComGrant.exists?(
                  device_session_id: f5_token.device_session_id,
                  oidc_client_id: f5_client.client_id,
                  revoked_at: nil,
                ))
              f5_token.rotate_refresh_token! unless f5_token.device_session_record.current_refresh_token_id
              f5_now = Time.current
              f5_session = OpComGrant.create!(
                authentication_epoch: 0,
                visitor_token: f5_token, oidc_client_id: f5_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f5_now,
                refresh_token_expires_at: f5_now + 10.minutes,
              )
              f5_access = AuthenticationTokenService.encode(
                f5_token.actor_record,
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
                  f5_token.actor_record,
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
        end.except("Cookie", "HTTP_COOKIE")
      end
    delete base_com_identity_passkey_url(passkey.public_id, ri: "jp", host: @base_host),
           headers: http_headers_0

    assert_not VisitorPasskey.exists?(passkey.id)
  end

  test "visitor can browse and rename an active secret credential" do
    visitor = create_visitor
    create_verified_telephone(visitor, "+819022220005")
    create_active_passkey(visitor)
    secret_credential = create_active_secret_credential(visitor)
    headers =
      begin
        fx6_visitor = visitor
        fx6_scope = "settings_secret_credential"
        fx6_host = @base_host
        fx6_token = VisitorToken.create!(
          authentication_epoch: 0,
          visitor: fx6_visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
          root_login_established_at: Time.current, established_authentication_method: "passkey",
        )
        BaseSelectorBootstrapAuthority.call(surface: :com, principal: fx6_visitor)
        BaseSelectorAuthority.prepare(surface: :com, principal: fx6_visitor, session: fx6_token)
        satisfy_visitor_verification(fx6_token)
        mark_token_step_up_satisfied_for_test(fx6_token, scope: fx6_scope)
        begin
          f6_cookie_pairs =
            begin
              f6_host = fx6_host
              f6_token = fx6_token
              f6_client = OidcClientRegistry.find!("base-com-ww")
              f6_key = [f6_client.client_id, f6_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f6_key] ||
                  (f6_token.currently_usable? &&
                    !(f6_token.device_session_id && OpComGrant.exists?(
                      device_session_id: f6_token.device_session_id,
                      oidc_client_id: f6_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f6_key]
                  f6_token.rotate_refresh_token! unless f6_token.device_session_record.current_refresh_token_id
                  f6_now = Time.current
                  f6_session = OpComGrant.create!(
                    authentication_epoch: 0,
                    visitor_token: f6_token, oidc_client_id: f6_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f6_now,
                    refresh_token_expires_at: f6_now + 10.minutes,
                  )
                  f6_access = AuthenticationTokenService.encode(
                    fx6_visitor,
                    host: f6_host,
                    resource_type: "visitor",
                    session_public_id: f6_token.public_id,
                    base_session_public_id: f6_token.public_id,
                    oidc_sid: f6_session.public_id,
                    oidc_jti: f6_session.oidc_jti,
                    expires_at: f6_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f6_client),
                    audiences: [f6_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f6_client),
                    subject: OidcSubject.for(
                      fx6_visitor,
                      resource_type: "visitor",
                    ),
                    client_id: f6_client.client_id,
                  )
                  @base_browser_rp_credentials[f6_key] =
                    [f6_access, f6_session.issue_refresh_token!]
                end
                f6_access, f6_refresh = @base_browser_rp_credentials.fetch(f6_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f6_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f6_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f6_cookie_pairs, URI.parse("https://#{f6_host}/"))
        end
        begin
          f6_headers = as_visitor_headers(fx6_visitor, host: fx6_host, session_public_id: fx6_token.public_id)
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
              when "edit" then "edit-org-ww"
              else "#{f6_family}-#{f6_surface}"
              end
            f6_token = VisitorToken.find_by!(public_id: f6_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f6_client = OidcClientRegistry.find!(f6_client_id)
            f6_key = [f6_client.client_id, f6_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f6_key] && f6_token.currently_usable? &&
                !(f6_token.device_session_id && OpComGrant.exists?(
                  device_session_id: f6_token.device_session_id,
                  oidc_client_id: f6_client.client_id,
                  revoked_at: nil,
                ))
              f6_token.rotate_refresh_token! unless f6_token.device_session_record.current_refresh_token_id
              f6_now = Time.current
              f6_session = OpComGrant.create!(
                authentication_epoch: 0,
                visitor_token: f6_token, oidc_client_id: f6_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f6_now,
                refresh_token_expires_at: f6_now + 10.minutes,
              )
              f6_access = AuthenticationTokenService.encode(
                f6_token.actor_record,
                host: f6_host,
                resource_type: "visitor",
                session_public_id: f6_token.public_id,
                base_session_public_id: f6_token.public_id,
                oidc_sid: f6_session.public_id,
                oidc_jti: f6_session.oidc_jti,
                expires_at: f6_now + 10.minutes,
                scopes: %w(openid profile),
                issuer: OidcIssuer.for_client(f6_client),
                audiences: [f6_client.aud],
                jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f6_client),
                subject: OidcSubject.for(f6_token.actor_record, resource_type: "visitor"),
                client_id: f6_client.client_id,
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
        end.except("Cookie", "HTTP_COOKIE")
      end

    get base_com_identity_secrets_url(ri: "jp", host: @base_host), headers: headers

    assert_response :success
    assert_includes response.body, secret_credential.name

    get base_com_identity_secret_url(secret_credential.public_id, ri: "jp", host: @base_host), headers: headers

    assert_response :success
    assert_includes response.body, secret_credential.name

    patch base_com_identity_secret_url(secret_credential.public_id, ri: "jp", host: @base_host),
          params: { visitor_secret_credential: { name: "Renamed credential", enabled: "1" } },
          headers: headers

    assert_redirected_to base_com_identity_secret_url(secret_credential.public_id, ri: "jp", host: @base_host)
    assert_equal "Renamed credential", secret_credential.reload.name
    assert_predicate secret_credential, :active?
  end

  private

  def create_visitor
    Visitor.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: VisitorStatus::ACTIVE,
      visibility_id: VisitorVisibility::VISITOR,
    )
  end

  def create_verified_email(visitor, address)
    VisitorEmail.create!(
      visitor: visitor,
      address: address,
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      confirm_policy: true,
    ).tap(&:finalize_binding!)
  end

  def create_verified_telephone(visitor, number)
    VisitorTelephone.create!(
      visitor: visitor,
      number: number,
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    ).tap(&:finalize_binding!)
  end

  def create_active_passkey(visitor)
    VisitorPasskey.create!(
      visitor: visitor,
      webauthn_id: "com_removal_passkey_#{SecureRandom.hex(8)}",
      public_key: "public_key_#{SecureRandom.hex(8)}",
      sign_count: 0,
      description: "Removal guard passkey",
      status_id: VisitorPasskeyStatus::ACTIVE,
      uv_verified_at: Time.current,
    )
  end

  def create_active_secret_credential(visitor)
    VisitorSecretCredential.create!(
      visitor: visitor,
      name: "Removal guard secret_credential",
      password: "a" * 32,
      visitor_secret_credential_kind_id: VisitorSecretCredentialKind::LOGIN,
      visitor_secret_credential_status_id: VisitorSecretCredentialStatus::ACTIVE,
    )
  end
end

# DAMP local helper copy for former shared test support.
class SignComCredentialRemovalConstraintsTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
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
      elsif normalized.include?("base")
        "BASE"
      else
        "AUTH"
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

  def create_verified_user_with_email(email_address: "user-#{SecureRandom.hex(4)}@example.com")
    ensure_user_reference_records!
    user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::NOTHING,
      visibility_id: ClientVisibility::USER,
    )
    insert_verified_user_email!(user_id: user.id, address: email_address)
    user.reload
  end

  def insert_verified_user_email!(user_id:, address:)
    ClientEmail.create!(
      user_id: user_id,
      address: address,
      address_digest: IdentifierBlindIndex.bidx_for_email(address, realm: :app),
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
  end

  def insert_verified_visitor_email!(visitor_id:, address:)
    VisitorEmail.insert_all(
      [
        {
          visitor_id: visitor_id,
          address: address,
          address_digest: IdentifierBlindIndex.bidx_for_email(address, realm: :com),
          visitor_email_status_id: VisitorEmailStatus::VERIFIED,
          otp_attempts_count: 0,
          public_id: SecureRandom.alphanumeric(21),
          created_at: Time.current,
          updated_at: Time.current,
        },
      ],
    )
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

    passkey = token.visitor.visitor_passkeys.active.where("discard_at > ?", at).where.not(uv_verified_at: nil).first
    email = token.visitor.visitor_emails.effective_binding.where(
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    ).first
    method, credential_ref, phishing_resistant, user_verified =
      if passkey
        ["passkey", passkey.public_id, true, true]
      elsif email
        ["email_otp", email.public_id, false, false]
      else
        ["passkey", nil, true, true]
      end
    attrs = {
      last_step_up_at: at,
      last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
      last_step_up_aal: ("aal2" if token.has_attribute?(:last_step_up_aal)),
      last_step_up_method: (method if token.has_attribute?(:last_step_up_method)),
      last_step_up_session_public_id: (token.public_id if token.has_attribute?(:last_step_up_session_public_id)),
      last_step_up_purpose: ("step_up" if token.has_attribute?(:last_step_up_purpose)),
      last_step_up_audience: (step_up_test_audience_for_token(token) if token.has_attribute?(:last_step_up_audience)),
      last_step_up_credential_ref: (credential_ref if token.has_attribute?(:last_step_up_credential_ref)),
      last_step_up_phishing_resistant: (
        phishing_resistant if token.has_attribute?(:last_step_up_phishing_resistant)
      ),
      last_step_up_user_verified: (user_verified if token.has_attribute?(:last_step_up_user_verified)),
      last_step_up_full_reauthentication: (
        false if token.has_attribute?(:last_step_up_full_reauthentication)
      ),
      updated_at: Time.current,
    }.compact
    token.update_columns(attrs)
  end

  def step_up_test_audience_for_token(token)
    case token.class.name
    when "OperatorToken" then "step_up:org"
    when "VisitorToken" then "step_up:com"
    else "step_up:app"
    end
  end

  def signed_step_up_pt_for(path, surface:, session_nonce:)
    safe_path = path.to_s
    return nil if safe_path.blank? || !safe_path.start_with?("/") || safe_path.match?(/[\x00-\x1F\x7F]/)

    verifier = ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("path_target_token", 32),
      digest: "SHA256",
      serializer: JSON,
      url_safe: true,
    )
    verifier.generate(
      { "flow" => "step_up.bootstrap",
        "surface" => surface.to_s,
        "session_nonce" => session_nonce.to_s,
        "pt" => safe_path, },
      purpose: :path_target,
      expires_in: 15.minutes,
    )
  end

  def signed_step_up_grant_for(actor:, token:, scope:, return_to:, surface:, methods: %i(email_otp totp passkey),
                               aal: "aal2")
    IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: surface.to_s,
      actor_ref: actor.public_id,
      session_ref: token.public_id,
      required_scope: scope.to_s,
      required_aal: aal,
      allowed_methods: methods,
      return_to: return_to,
      expires_at: 15.minutes.from_now,
    ).grant
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

  def csrf_headers(token)
    { "X-CSRF-Token" => token }
  end

  def fetch_csrf_token(path)
    get(path)
    response.body[/name="authenticity_token" value="([^"]+)"/, 1] || response.body
  end

  def social_callback_headers(host)
    scheme = host.to_s.include?("localhost") ? "http" : "https"
    origin = "#{scheme}://#{host}"
    cookies["csrf_token"] = csrf_token_value if respond_to?(:cookies)
    {
      "Host" => host,
      "Origin" => origin,
      "Referer" => "#{origin}/",
      "Sec-Fetch-Site" => "same-origin",
      "X-STRICT-SOCIAL-STATE" => "1",
      "X-CSRF-Token" => csrf_token_value,
    }
  end

  def social_auth_state_from_response
    session[:social_auth_state].presence || begin
      uri = URI.parse(response.location.to_s)
      Rack::Utils.parse_nested_query(uri.query.to_s)["state"].presence
    rescue URI::InvalidURIError
      nil
    end
  end

  def seed_social_auth_session(provider:, intent: "login", user: nil, entry: nil, ri: "jp", rt: nil, referer: nil)
    host = configured_host(:sign_service)
    host!(host) if respond_to?(:host!)
    normalized_provider = SocialIdentifiable.normalize_provider(provider)
    continue_path =
      if intent.to_s == "link"
        public_send(:"auth_app_settings_#{normalized_provider}_path", ri: ri)
      elsif entry.to_s == "sign_up"
        public_send(:"auth_app_social_#{normalized_provider}_registration_path", ri: ri, rt: rt)
      else
        public_send(:"auth_app_social_#{normalized_provider}_session_path", ri: ri, rt: rt)
      end
    headers = social_callback_headers(host)
    headers["Referer"] = referer if referer.present?
    if user
      user_headers =
        as_user_headers(user, host: host)
      token = ClientToken.find_by(public_id: user_headers["X-TEST-SESSION-PUBLIC-ID"])
      mark_token_step_up_satisfied_for_test(
        token,
        scope: SocialAuth::SOCIAL_LINK_SCOPE,
      ) if intent.to_s == "link" && token
      headers = headers.merge(user_headers)
    end
    post(continue_path, headers: headers)
    social_auth_state_from_response
  end

  def assert_oidc_authorize_redirect(location, host:, client_id: "base-rails-rp")
    uri = URI.parse(location)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal host, uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_equal client_id, query["client_id"]
    assert_predicate query["state"], :present?
  end
end

# DAMP local helper copy on the test class.
class SignComCredentialRemovalConstraintsTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )
  PREFERENCE_JWT_KEY = OpenSSL::PKey::EC.generate("secp384r1") unless const_defined?(:PREFERENCE_JWT_KEY, false)

  private

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
    host_headers.merge("X-CSRF-Token" => csrf_token, "Sec-Fetch-Site" => "same-origin")
  end

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
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
