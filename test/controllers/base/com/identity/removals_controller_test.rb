# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Com::Identity::RemovalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    https!
    @host = configured_host(:base_corporate)
    @visitor = create_verified_visitor_with_email(email_address: "com-removal-#{SecureRandom.hex(4)}@example.com")
    @secret = create_active_secret_credential(@visitor)
    headers =
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
            rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
            rp_now = Time.current
            rp_session = VisitorRpSession.create!(
              visitor_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.visitor, host: rp_host, resource_type: "visitor",
                                session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                                oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                subject: OidcSubject.for(
                                  rp_token.visitor,
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
    token = VisitorToken.find_by!(public_id: headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
    token.update!(root_login_established_at: Time.current, established_authentication_method: "passkey")
    BaseSelectorBootstrapAuthority.call(surface: :com, principal: @visitor)
    BaseSelectorAuthority.prepare(surface: :com, principal: @visitor, session: token)
    begin
      rp_cookie_pairs =
        begin
          rp_host = @host
          rp_token = token
          rp_client = OidcClientRegistry.find!("base-com-ww")
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if @base_browser_rp_credentials[rp_key] ||
              (rp_token.currently_usable? &&
                !(rp_token.device_session_id && VisitorRpSession.exists?(
                  device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                )))
            unless @base_browser_rp_credentials[rp_key]
              rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
              rp_now = Time.current
              rp_session = VisitorRpSession.create!(
                visitor_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                @visitor, host: rp_host, resource_type: "visitor",
                          session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                          oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                          expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                          issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                          subject: OidcSubject.for(@visitor, resource_type: "visitor"), client_id: rp_client.client_id,
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
        end
      cookies.merge(rp_cookie_pairs, URI.parse("https://#{rp_host}/"))
    end
  end

  test "removes the secret credential when another AAL1 method still remains" do
    http_headers_2 =
      begin
        fx0_actor = @visitor
        fx0_host = @host
        fx0_headers =
          begin
            f0_headers = as_visitor_headers(fx0_actor, host: fx0_host)
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
                  f0_token.visitor,
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
                    f0_token.visitor,
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
          end
        VisitorToken.find_by!(public_id: fx0_headers.fetch("X-TEST-SESSION-PUBLIC-ID")).update_columns(
          last_step_up_at: Time.current,
          last_step_up_scope: "settings_secret_credential",
          last_step_up_aal: "aal2",
          last_step_up_method: "email_otp",
          last_step_up_session_public_id: fx0_headers.fetch("X-TEST-SESSION-PUBLIC-ID"),
          last_step_up_purpose: "step_up",
          last_step_up_audience: "step_up:com",
          last_step_up_credential_ref: fx0_actor.visitor_emails.effective_binding.first!.public_id,
          last_step_up_phishing_resistant: false,
          last_step_up_user_verified: false,
          last_step_up_full_reauthentication: false,
        )
        fx0_headers.except("Cookie", "HTTP_COOKIE")
      end
    post base_com_identity_secret_removal_url(@secret.public_id, ri: "jp", host: @host),
         headers: http_headers_2

    assert_response :see_other
    assert_redirected_to base_com_identity_secrets_path(ri: "jp")

    @secret.reload

    assert_equal VisitorSecretCredential.status_id_for(:deleted), @secret.visitor_secret_credential_status_id
    assert_predicate @secret.discard_at, :present?
  end

  test "direct secret credential deletion without fresh step-up is refused" do
    create_active_secret_credential(@visitor)

    delete base_com_identity_secret_url(@secret.public_id, ri: "jp", host: @host),
           headers: begin
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
                     device_session_id: rp_token.device_session_id,
                     oidc_client_id: rp_client.client_id,
                     revoked_at: nil,
                   ))
                 rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
                 rp_now = Time.current
                 rp_session = VisitorRpSession.create!(
                   visitor_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                   oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                   refresh_token_expires_at: rp_now + 10.minutes,
                 )
                 rp_access = AuthenticationTokenService.encode(
                   rp_token.visitor, host: rp_host, resource_type: "visitor",
                                     session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                                     oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                     expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                     issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                     subject: OidcSubject.for(
                                       rp_token.visitor,
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
           end.except("Cookie", "HTTP_COOKIE")

    assert_response :unauthorized
    assert_equal VisitorSecretCredentialStatus::ACTIVE, @secret.reload.visitor_secret_credential_status_id
  end

  test "removes Secret when telephone is only the non-sign-in contact and email supplies Step-Up" do
    @visitor.visitor_telephones.create!(
      number: "+8190#{format("%08d", SecureRandom.random_number(100_000_000))}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )

    http_headers_1 =
      begin
        fx1_actor = @visitor
        fx1_host = @host
        fx1_headers =
          begin
            f1_headers = as_visitor_headers(fx1_actor, host: fx1_host)
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
                  f1_token.visitor,
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
                    f1_token.visitor,
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
          end
        VisitorToken.find_by!(public_id: fx1_headers.fetch("X-TEST-SESSION-PUBLIC-ID")).update_columns(
          last_step_up_at: Time.current,
          last_step_up_scope: "settings_secret_credential",
          last_step_up_aal: "aal2",
          last_step_up_method: "email_otp",
          last_step_up_session_public_id: fx1_headers.fetch("X-TEST-SESSION-PUBLIC-ID"),
          last_step_up_purpose: "step_up",
          last_step_up_audience: "step_up:com",
          last_step_up_credential_ref: fx1_actor.visitor_emails.effective_binding.first!.public_id,
          last_step_up_phishing_resistant: false,
          last_step_up_user_verified: false,
          last_step_up_full_reauthentication: false,
        )
        fx1_headers.except("Cookie", "HTTP_COOKIE")
      end
    post base_com_identity_secret_removal_url(@secret.public_id, ri: "jp", host: @host),
         headers: http_headers_1

    assert_response :see_other
    assert_redirected_to base_com_identity_secrets_path(ri: "jp")

    @secret.reload

    assert_equal VisitorSecretCredentialStatus::DELETED, @secret.visitor_secret_credential_status_id
  end

  test "a credential owned by another visitor is not found" do
    other = create_verified_visitor_with_email(email_address: "com-removal-other-#{SecureRandom.hex(4)}@example.com")
    other_secret = create_active_secret_credential(other)

    http_headers_0 =
      begin
        fx2_actor = @visitor
        fx2_host = @host
        fx2_headers =
          begin
            f2_headers = as_visitor_headers(fx2_actor, host: fx2_host)
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
                  f2_token.visitor,
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
                    f2_token.visitor,
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
          end
        VisitorToken.find_by!(public_id: fx2_headers.fetch("X-TEST-SESSION-PUBLIC-ID")).update_columns(
          last_step_up_at: Time.current,
          last_step_up_scope: "settings_secret_credential",
          last_step_up_aal: "aal2",
          last_step_up_method: "email_otp",
          last_step_up_session_public_id: fx2_headers.fetch("X-TEST-SESSION-PUBLIC-ID"),
          last_step_up_purpose: "step_up",
          last_step_up_audience: "step_up:com",
          last_step_up_credential_ref: fx2_actor.visitor_emails.effective_binding.first!.public_id,
          last_step_up_phishing_resistant: false,
          last_step_up_user_verified: false,
          last_step_up_full_reauthentication: false,
        )
        fx2_headers.except("Cookie", "HTTP_COOKIE")
      end
    post base_com_identity_secret_removal_url(other_secret.public_id, ri: "jp", host: @host),
         headers: http_headers_0

    assert_response :not_found
    assert_equal VisitorSecretCredentialStatus::ACTIVE, other_secret.reload.visitor_secret_credential_status_id
  end

  test "removal without fresh step-up is refused and keeps the credential" do
    post base_com_identity_secret_removal_url(@secret.public_id, ri: "jp", host: @host),
         headers: begin
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
               rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
               rp_now = Time.current
               rp_session = VisitorRpSession.create!(
                 visitor_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                 oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                 refresh_token_expires_at: rp_now + 10.minutes,
               )
               rp_access = AuthenticationTokenService.encode(
                 rp_token.visitor, host: rp_host, resource_type: "visitor",
                                   session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                                   oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                   expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                   issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                   jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                   subject: OidcSubject.for(
                                     rp_token.visitor,
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
         end.except("Cookie", "HTTP_COOKIE")

    assert_response :unauthorized
    assert_equal VisitorSecretCredentialStatus::ACTIVE, @secret.reload.visitor_secret_credential_status_id
  end

  private

  def create_active_secret_credential(visitor)
    VisitorSecretCredential.create!(
      visitor: visitor,
      name: "Removal test secret credential",
      password: "a" * 32,
      visitor_secret_credential_kind_id: VisitorSecretCredentialKind::LOGIN,
      visitor_secret_credential_status_id: VisitorSecretCredentialStatus::ACTIVE,
    )
  end

  # DAMP local helper copy for former shared test support.
  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def create_verified_visitor_with_email(email_address: "visitor-#{SecureRandom.hex(4)}@example.com")
    ensure_visitor_reference_records!
    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    VisitorEmail.create!(
      visitor_id: visitor.id,
      address: email_address,
      address_digest: IdentifierBlindIndex.bidx_for_email(email_address, realm: :com),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      binding_finalized_at: VisitorEmail.database_now,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
    visitor.reload
    visitor.refresh_mfa_status! if visitor.respond_to?(:refresh_mfa_status!)
    visitor.reload
  end

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    [
      VisitorSecretCredentialStatus::ACTIVE,
      VisitorSecretCredentialStatus::DELETED,
      VisitorSecretCredentialStatus::NOTHING,
    ].each { |id| VisitorSecretCredentialStatus.find_or_create_by!(id: id) }
    VisitorSecretCredentialKind.find_or_create_by!(id: VisitorSecretCredentialKind::LOGIN)
  end
end
