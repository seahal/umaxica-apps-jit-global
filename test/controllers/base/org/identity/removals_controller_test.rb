# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Org::Identity::RemovalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    https!
    @host = configured_host(:base_staff)
    ensure_operator_reference_records!
    @operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    @operator = OperatorPasskeyTestSupport.give_two_active_passkeys!(@operator)
    @step_up_passkey = @operator.operator_passkeys.create!(
      webauthn_id: "org-removal-step-up-#{SecureRandom.hex(8)}",
      external_id: SecureRandom.uuid, public_key: "public_key_#{SecureRandom.hex(8)}",
      description: "Removal test step-up passkey", status_id: OperatorPasskeyStatus::ACTIVE,
      uv_verified_at: Time.current,
    )
    headers =
      begin
        rp_headers = as_staff_headers(@operator, host: @host)
        rp_host = rp_headers["Host"]
        rp_route =
          begin
            Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
          rescue ActionController::RoutingError
            nil
          end
        rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
        if %w(base warp core edit).include?(rp_family) && rp_surface == "org"
          rp_client_id =
            case rp_family
            when "base" then "base-#{rp_surface}-ww"
            when "edit" then "edit-org-ww"
            when "tech" then "tech-org-ww"
            else "#{rp_family}-#{rp_surface}-jp"
            end
          rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && OpOrgGrant.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
            rp_now = Time.current
            rp_session = OpOrgGrant.create!(
              authentication_epoch: 0,
              operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.actor_record, host: rp_host, resource_type: "operator",
                                     session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                                     oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                     expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                     issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                     subject: OidcSubject.for(
                                       rp_token.actor_record,
                                       resource_type: "operator",
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
    token = OperatorToken.find_by!(public_id: headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
    token.update!(root_login_established_at: Time.current, established_authentication_method: "passkey")
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: token)
    begin
      rp_cookie_pairs =
        begin
          rp_host = @host
          rp_token = token
          rp_client = OidcClientRegistry.find!("base-org-ww")
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if @base_browser_rp_credentials[rp_key] ||
              (rp_token.currently_usable? &&
                !(rp_token.device_session_id && OpOrgGrant.exists?(
                  device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                )))
            unless @base_browser_rp_credentials[rp_key]
              rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
              rp_now = Time.current
              rp_session = OpOrgGrant.create!(
                authentication_epoch: 0,
                operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                @operator, host: rp_host, resource_type: "operator",
                           session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                           oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                           expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                           issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                           jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                           subject: OidcSubject.for(
                             @operator,
                             resource_type: "operator",
                           ), client_id: rp_client.client_id,
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

  test "removes the secret credential when another sign-in method still remains" do
    target = create_active_secret_credential(@operator)
    OperatorPasskeyStatus.find_or_create_by!(id: OperatorPasskeyStatus::ACTIVE)
    OperatorPasskey.create!(
      staff: @operator,
      webauthn_id: "org-removal-alternative-#{SecureRandom.hex(8)}",
      external_id: SecureRandom.uuid,
      public_key: "public_key_#{SecureRandom.hex(8)}",
      description: "Alternative sign-in passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )

    assert_equal [:passkey],
                 AuthenticationCredentialInventory.call(@operator, excluding: target).sign_in_methods

    http_headers_3 =
      begin
        fx0_actor = @operator
        fx0_host = @host
        fx0_headers =
          begin
            f0_headers = as_staff_headers(fx0_actor, host: fx0_host)
            f0_host = f0_headers["Host"]
            f0_route =
              begin
                Rails.application.routes.recognize_path("https://#{f0_host}/") if f0_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f0_family, f0_surface = f0_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f0_family) && f0_surface == "org"
              f0_client_id =
                case f0_family
                when "base" then "base-#{f0_surface}-ww"
                when "edit" then "edit-org-ww"
                when "tech" then "tech-org-ww"
                else "#{f0_family}-#{f0_surface}"
                end
              f0_token = OperatorToken.find_by!(public_id: f0_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f0_client = OidcClientRegistry.find!(f0_client_id)
              f0_key = [f0_client.client_id, f0_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f0_key] && f0_token.currently_usable? &&
                  !(f0_token.device_session_id && OpOrgGrant.exists?(
                    device_session_id: f0_token.device_session_id,
                    oidc_client_id: f0_client.client_id,
                    revoked_at: nil,
                  ))
                f0_token.rotate_refresh_token! unless f0_token.device_session_record.current_refresh_token_id
                f0_now = Time.current
                f0_session = OpOrgGrant.create!(
                  authentication_epoch: 0,
                  operator_token: f0_token, oidc_client_id: f0_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f0_now,
                  refresh_token_expires_at: f0_now + 10.minutes,
                )
                f0_access = AuthenticationTokenService.encode(
                  f0_token.actor_record, host: f0_host, resource_type: "operator",
                                         session_public_id: f0_token.public_id,
                                         base_session_public_id: f0_token.public_id,
                                         oidc_sid: f0_session.public_id, oidc_jti: f0_session.oidc_jti,
                                         expires_at: f0_now + 10.minutes, scopes: %w(openid profile),
                                         issuer: OidcIssuer.for_client(f0_client), audiences: [f0_client.aud],
                                         jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f0_client),
                                         subject: OidcSubject.for(
                                           f0_token.actor_record,
                                           resource_type: "operator",
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
          end
        OperatorToken.find_by!(public_id: fx0_headers.fetch("X-TEST-SESSION-PUBLIC-ID")).update_columns(
          last_step_up_at: Time.current,
          last_step_up_scope: "settings_secret_credential",
          last_step_up_aal: "aal2",
          last_step_up_method: "passkey",
          last_step_up_session_public_id: fx0_headers.fetch("X-TEST-SESSION-PUBLIC-ID"),
          last_step_up_purpose: "step_up",
          last_step_up_audience: "step_up:org",
          last_step_up_credential_ref: @step_up_passkey.external_id,
          last_step_up_phishing_resistant: true,
          last_step_up_user_verified: true,
          last_step_up_full_reauthentication: false,
        )
        fx0_headers.except("Cookie", "HTTP_COOKIE")
      end
    post base_org_identity_secret_removal_url(target.public_id, ri: "jp", host: @host),
         headers: http_headers_3

    assert_response :see_other
    assert_redirected_to base_org_identity_secrets_path(ri: "jp")
    assert_not_equal OperatorSecretCredentialStatus::ACTIVE, target.reload.staff_secret_status_id
  end

  test "direct secret credential deletion without fresh step-up is refused" do
    target = create_active_secret_credential(@operator)
    create_active_secret_credential(@operator)

    delete base_org_identity_secret_url(target.public_id, ri: "jp", host: @host),
           headers: begin
             rp_headers = as_staff_headers(@operator, host: @host)
             rp_host = rp_headers["Host"]
             rp_route =
               begin
                 Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
               rescue ActionController::RoutingError
                 nil
               end
             rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
             if %w(base warp core edit).include?(rp_family) && rp_surface == "org"
               rp_client_id =
                 case rp_family
                 when "base" then "base-#{rp_surface}-ww"
                 when "edit" then "edit-org-ww"
                 when "tech" then "tech-org-ww"
                 else "#{rp_family}-#{rp_surface}-jp"
                 end
               rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
               rp_client = OidcClientRegistry.find!(rp_client_id)
               rp_key = [rp_client.client_id, rp_token.public_id]
               @base_browser_rp_credentials ||= {}
               if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                   !(rp_token.device_session_id && OpOrgGrant.exists?(
                     device_session_id: rp_token.device_session_id,
                     oidc_client_id: rp_client.client_id,
                     revoked_at: nil,
                   ))
                 rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                 rp_now = Time.current
                 rp_session = OpOrgGrant.create!(
                   authentication_epoch: 0,
                   operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                   oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                   refresh_token_expires_at: rp_now + 10.minutes,
                 )
                 rp_access = AuthenticationTokenService.encode(
                   rp_token.actor_record, host: rp_host, resource_type: "operator",
                                          session_public_id: rp_token.public_id,
                                          base_session_public_id: rp_token.public_id,
                                          oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                          expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                          issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                          subject: OidcSubject.for(
                                            rp_token.actor_record,
                                            resource_type: "operator",
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

    assert_not response.location.to_s.end_with?(base_org_identity_secrets_path(ri: "jp"))
    assert_equal OperatorSecretCredentialStatus::ACTIVE, target.reload.staff_secret_status_id
  end

  test "removes a Secret when the registered Passkey remains as the sign-in method" do
    only = create_active_secret_credential(@operator)

    http_headers_2 =
      begin
        fx1_actor = @operator
        fx1_host = @host
        fx1_headers =
          begin
            f1_headers = as_staff_headers(fx1_actor, host: fx1_host)
            f1_host = f1_headers["Host"]
            f1_route =
              begin
                Rails.application.routes.recognize_path("https://#{f1_host}/") if f1_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f1_family, f1_surface = f1_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f1_family) && f1_surface == "org"
              f1_client_id =
                case f1_family
                when "base" then "base-#{f1_surface}-ww"
                when "edit" then "edit-org-ww"
                when "tech" then "tech-org-ww"
                else "#{f1_family}-#{f1_surface}"
                end
              f1_token = OperatorToken.find_by!(public_id: f1_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f1_client = OidcClientRegistry.find!(f1_client_id)
              f1_key = [f1_client.client_id, f1_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f1_key] && f1_token.currently_usable? &&
                  !(f1_token.device_session_id && OpOrgGrant.exists?(
                    device_session_id: f1_token.device_session_id,
                    oidc_client_id: f1_client.client_id,
                    revoked_at: nil,
                  ))
                f1_token.rotate_refresh_token! unless f1_token.device_session_record.current_refresh_token_id
                f1_now = Time.current
                f1_session = OpOrgGrant.create!(
                  authentication_epoch: 0,
                  operator_token: f1_token, oidc_client_id: f1_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f1_now,
                  refresh_token_expires_at: f1_now + 10.minutes,
                )
                f1_access = AuthenticationTokenService.encode(
                  f1_token.actor_record, host: f1_host, resource_type: "operator",
                                         session_public_id: f1_token.public_id,
                                         base_session_public_id: f1_token.public_id,
                                         oidc_sid: f1_session.public_id, oidc_jti: f1_session.oidc_jti,
                                         expires_at: f1_now + 10.minutes, scopes: %w(openid profile),
                                         issuer: OidcIssuer.for_client(f1_client), audiences: [f1_client.aud],
                                         jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f1_client),
                                         subject: OidcSubject.for(
                                           f1_token.actor_record,
                                           resource_type: "operator",
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
        OperatorToken.find_by!(public_id: fx1_headers.fetch("X-TEST-SESSION-PUBLIC-ID")).update_columns(
          last_step_up_at: Time.current,
          last_step_up_scope: "settings_secret_credential",
          last_step_up_aal: "aal2",
          last_step_up_method: "passkey",
          last_step_up_session_public_id: fx1_headers.fetch("X-TEST-SESSION-PUBLIC-ID"),
          last_step_up_purpose: "step_up",
          last_step_up_audience: "step_up:org",
          last_step_up_credential_ref: @step_up_passkey.external_id,
          last_step_up_phishing_resistant: true,
          last_step_up_user_verified: true,
          last_step_up_full_reauthentication: false,
        )
        fx1_headers.except("Cookie", "HTTP_COOKIE")
      end
    post base_org_identity_secret_removal_url(only.public_id, ri: "jp", host: @host),
         headers: http_headers_2

    assert_response :see_other
    assert_redirected_to base_org_identity_secrets_path(ri: "jp")
    assert_not_equal OperatorSecretCredentialStatus::ACTIVE, only.reload.staff_secret_status_id
  end

  test "a credential owned by another operator is not found" do
    other = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    other_secret = create_active_secret_credential(other)
    create_active_secret_credential(other)

    http_headers_1 =
      begin
        fx2_actor = @operator
        fx2_host = @host
        fx2_headers =
          begin
            f2_headers = as_staff_headers(fx2_actor, host: fx2_host)
            f2_host = f2_headers["Host"]
            f2_route =
              begin
                Rails.application.routes.recognize_path("https://#{f2_host}/") if f2_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f2_family, f2_surface = f2_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f2_family) && f2_surface == "org"
              f2_client_id =
                case f2_family
                when "base" then "base-#{f2_surface}-ww"
                when "edit" then "edit-org-ww"
                when "tech" then "tech-org-ww"
                else "#{f2_family}-#{f2_surface}"
                end
              f2_token = OperatorToken.find_by!(public_id: f2_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f2_client = OidcClientRegistry.find!(f2_client_id)
              f2_key = [f2_client.client_id, f2_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f2_key] && f2_token.currently_usable? &&
                  !(f2_token.device_session_id && OpOrgGrant.exists?(
                    device_session_id: f2_token.device_session_id,
                    oidc_client_id: f2_client.client_id,
                    revoked_at: nil,
                  ))
                f2_token.rotate_refresh_token! unless f2_token.device_session_record.current_refresh_token_id
                f2_now = Time.current
                f2_session = OpOrgGrant.create!(
                  authentication_epoch: 0,
                  operator_token: f2_token, oidc_client_id: f2_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f2_now,
                  refresh_token_expires_at: f2_now + 10.minutes,
                )
                f2_access = AuthenticationTokenService.encode(
                  f2_token.actor_record, host: f2_host, resource_type: "operator",
                                         session_public_id: f2_token.public_id,
                                         base_session_public_id: f2_token.public_id,
                                         oidc_sid: f2_session.public_id, oidc_jti: f2_session.oidc_jti,
                                         expires_at: f2_now + 10.minutes, scopes: %w(openid profile),
                                         issuer: OidcIssuer.for_client(f2_client), audiences: [f2_client.aud],
                                         jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f2_client),
                                         subject: OidcSubject.for(
                                           f2_token.actor_record,
                                           resource_type: "operator",
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
        OperatorToken.find_by!(public_id: fx2_headers.fetch("X-TEST-SESSION-PUBLIC-ID")).update_columns(
          last_step_up_at: Time.current,
          last_step_up_scope: "settings_secret_credential",
          last_step_up_aal: "aal2",
          last_step_up_method: "passkey",
          last_step_up_session_public_id: fx2_headers.fetch("X-TEST-SESSION-PUBLIC-ID"),
          last_step_up_purpose: "step_up",
          last_step_up_audience: "step_up:org",
          last_step_up_credential_ref: @step_up_passkey.external_id,
          last_step_up_phishing_resistant: true,
          last_step_up_user_verified: true,
          last_step_up_full_reauthentication: false,
        )
        fx2_headers.except("Cookie", "HTTP_COOKIE")
      end
    post base_org_identity_secret_removal_url(other_secret.public_id, ri: "jp", host: @host),
         headers: http_headers_1

    assert_response :not_found
    assert_equal OperatorSecretCredentialStatus::ACTIVE, other_secret.reload.staff_secret_status_id
  end

  test "removal without fresh step-up is refused and keeps the credential" do
    target = create_active_secret_credential(@operator)
    create_active_secret_credential(@operator)

    post base_org_identity_secret_removal_url(target.public_id, ri: "jp", host: @host),
         headers: begin
           rp_headers = as_staff_headers(@operator, host: @host)
           rp_host = rp_headers["Host"]
           rp_route =
             begin
               Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
             rescue ActionController::RoutingError
               nil
             end
           rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
           if %w(base warp core edit).include?(rp_family) && rp_surface == "org"
             rp_client_id =
               case rp_family
               when "base" then "base-#{rp_surface}-ww"
               when "edit" then "edit-org-ww"
               when "tech" then "tech-org-ww"
               else "#{rp_family}-#{rp_surface}-jp"
               end
             rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
             rp_client = OidcClientRegistry.find!(rp_client_id)
             rp_key = [rp_client.client_id, rp_token.public_id]
             @base_browser_rp_credentials ||= {}
             if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                 !(rp_token.device_session_id && OpOrgGrant.exists?(
                   device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                 ))
               rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
               rp_now = Time.current
               rp_session = OpOrgGrant.create!(
                 authentication_epoch: 0,
                 operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                 oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                 refresh_token_expires_at: rp_now + 10.minutes,
               )
               rp_access = AuthenticationTokenService.encode(
                 rp_token.actor_record, host: rp_host, resource_type: "operator",
                                        session_public_id: rp_token.public_id,
                                        base_session_public_id: rp_token.public_id,
                                        oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                        expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                        issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                        subject: OidcSubject.for(
                                          rp_token.actor_record,
                                          resource_type: "operator",
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

    assert_not response.location.to_s.end_with?(base_org_identity_secrets_path(ri: "jp"))
    assert_equal OperatorSecretCredentialStatus::ACTIVE, target.reload.staff_secret_status_id
  end

  test "an Emergency session cannot remove a credential" do
    target = create_active_secret_credential(@operator)
    create_active_secret_credential(@operator)
    emergency_token = OperatorToken.create!(
      authentication_epoch: 0,
      staff: @operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, discard_at: 30.days.from_now,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      authentication_context: AuthenticationContextValue::STANDBY_KEY,
    )

    http_headers_0 =
      begin
        rp_headers = as_staff_headers(@operator, host: @host, session_public_id: emergency_token.public_id)
        rp_host = rp_headers["Host"]
        rp_route =
          begin
            Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
          rescue ActionController::RoutingError
            nil
          end
        rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
        if %w(base warp core edit).include?(rp_family) && rp_surface == "org"
          rp_client_id =
            case rp_family
            when "base" then "base-#{rp_surface}-ww"
            when "edit" then "edit-org-ww"
            when "tech" then "tech-org-ww"
            else "#{rp_family}-#{rp_surface}-jp"
            end
          rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && OpOrgGrant.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
            rp_now = Time.current
            rp_session = OpOrgGrant.create!(
              authentication_epoch: 0,
              operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.actor_record, host: rp_host, resource_type: "operator",
                                     session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                                     oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                     expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                     issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                     subject: OidcSubject.for(
                                       rp_token.actor_record,
                                       resource_type: "operator",
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
    post base_org_identity_secret_removal_url(target.public_id, ri: "jp", host: @host),
         headers: http_headers_0

    assert_not response.location.to_s.end_with?(base_org_identity_secrets_path(ri: "jp"))
    assert_equal OperatorSecretCredentialStatus::ACTIVE, target.reload.staff_secret_status_id
  end

  private

  def create_active_secret_credential(operator)
    OperatorSecretCredential.create!(
      staff: operator,
      name: "Removal test secret credential #{SecureRandom.hex(4)}",
      password_digest: "digest",
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
      staff_secret_status_id: OperatorSecretCredentialStatus::ACTIVE,
    )
  end

  def ensure_operator_reference_records!
    OperatorStatus.find_or_create_by!(id: OperatorStatus::ACTIVE)
    OperatorEmailStatus.ensure_defaults!
    [
      OperatorSecretCredentialStatus::ACTIVE,
      OperatorSecretCredentialStatus::DELETED,
      OperatorSecretCredentialStatus::REVOKED,
    ].each { |id| OperatorSecretCredentialStatus.find_or_create_by!(id: id) }
    OperatorSecretCredentialKind.find_or_create_by!(id: OperatorSecretCredentialKind::LOGIN)
  end

  # DAMP local helper copy for former shared test support.
  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end
end
