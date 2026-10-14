# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Org::DashboardAvatarImagesControllerTest < ActionDispatch::IntegrationTest
  STORED_PNG = Base64.decode64(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
  ).freeze

  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    @operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    @token = OperatorToken.create!(staff: @operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    @bootstrap = BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: @token)
  end

  test "no selected Avatar is a normal absence: no image element and a 404 image" do
    assert_nil @token.reload.selected_avatar_public_id

    http_headers_7 =
      begin
        begin
          f0_headers =
            begin
              rp_headers = as_staff_headers(@operator, host: @host, session_public_id: @token.public_id)
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
                  when "edit" then "edit-org"
                  else "#{rp_family}-#{rp_surface}"
                  end
                rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                rp_client = OidcClientRegistry.find!(rp_client_id)
                rp_key = [rp_client.client_id, rp_token.public_id]
                @base_browser_rp_credentials ||= {}
                if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                    !(rp_token.device_session_id && OperatorRpSession.exists?(
                      device_session_id: rp_token.device_session_id,
                      oidc_client_id: rp_client.client_id,
                      revoked_at: nil,
                    ))
                  rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                  rp_now = Time.current
                  rp_session = OperatorRpSession.create!(
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
            end
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
              when "edit" then "edit-org"
              else "#{f0_family}-#{f0_surface}"
              end
            f0_token = OperatorToken.find_by!(public_id: f0_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f0_client = OidcClientRegistry.find!(f0_client_id)
            f0_key = [f0_client.client_id, f0_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f0_key] && f0_token.currently_usable? &&
                !(f0_token.device_session_id && OperatorRpSession.exists?(
                  device_session_id: f0_token.device_session_id,
                  oidc_client_id: f0_client.client_id,
                  revoked_at: nil,
                ))
              f0_token.rotate_refresh_token! unless f0_token.device_session_record.current_refresh_token_id
              f0_now = Time.current
              f0_session = OperatorRpSession.create!(
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
      end
    get base_org_dashboard_url(ri: "jp"), headers: http_headers_7

    assert_response :success
    assert_not inertia_props.dig("sections", 0, "current_identity").key?("avatar_image")

    http_headers_6 =
      begin
        begin
          f1_headers =
            begin
              rp_headers = as_staff_headers(@operator, host: @host, session_public_id: @token.public_id)
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
                  when "edit" then "edit-org"
                  else "#{rp_family}-#{rp_surface}"
                  end
                rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                rp_client = OidcClientRegistry.find!(rp_client_id)
                rp_key = [rp_client.client_id, rp_token.public_id]
                @base_browser_rp_credentials ||= {}
                if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                    !(rp_token.device_session_id && OperatorRpSession.exists?(
                      device_session_id: rp_token.device_session_id,
                      oidc_client_id: rp_client.client_id,
                      revoked_at: nil,
                    ))
                  rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                  rp_now = Time.current
                  rp_session = OperatorRpSession.create!(
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
            end
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
              when "edit" then "edit-org"
              else "#{f1_family}-#{f1_surface}"
              end
            f1_token = OperatorToken.find_by!(public_id: f1_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f1_client = OidcClientRegistry.find!(f1_client_id)
            f1_key = [f1_client.client_id, f1_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f1_key] && f1_token.currently_usable? &&
                !(f1_token.device_session_id && OperatorRpSession.exists?(
                  device_session_id: f1_token.device_session_id,
                  oidc_client_id: f1_client.client_id,
                  revoked_at: nil,
                ))
              f1_token.rotate_refresh_token! unless f1_token.device_session_record.current_refresh_token_id
              f1_now = Time.current
              f1_session = OperatorRpSession.create!(
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
      end
    get base_org_dashboard_avatar_image_url(ri: "jp"), headers: http_headers_6

    assert_response :not_found
  end

  test "a selected Avatar without a stored image is a normal absence with no default image" do
    select_avatar!(provision_avatar!)

    http_headers_5 =
      begin
        begin
          f2_headers =
            begin
              rp_headers = as_staff_headers(@operator, host: @host, session_public_id: @token.public_id)
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
                  when "edit" then "edit-org"
                  else "#{rp_family}-#{rp_surface}"
                  end
                rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                rp_client = OidcClientRegistry.find!(rp_client_id)
                rp_key = [rp_client.client_id, rp_token.public_id]
                @base_browser_rp_credentials ||= {}
                if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                    !(rp_token.device_session_id && OperatorRpSession.exists?(
                      device_session_id: rp_token.device_session_id,
                      oidc_client_id: rp_client.client_id,
                      revoked_at: nil,
                    ))
                  rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                  rp_now = Time.current
                  rp_session = OperatorRpSession.create!(
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
            end
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
              when "edit" then "edit-org"
              else "#{f2_family}-#{f2_surface}"
              end
            f2_token = OperatorToken.find_by!(public_id: f2_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f2_client = OidcClientRegistry.find!(f2_client_id)
            f2_key = [f2_client.client_id, f2_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f2_key] && f2_token.currently_usable? &&
                !(f2_token.device_session_id && OperatorRpSession.exists?(
                  device_session_id: f2_token.device_session_id,
                  oidc_client_id: f2_client.client_id,
                  revoked_at: nil,
                ))
              f2_token.rotate_refresh_token! unless f2_token.device_session_record.current_refresh_token_id
              f2_now = Time.current
              f2_session = OperatorRpSession.create!(
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
      end
    get base_org_dashboard_url(ri: "jp"), headers: http_headers_5

    assert_response :success
    assert_not inertia_props.dig("sections", 0, "current_identity").key?("avatar_image")

    http_headers_4 =
      begin
        begin
          f3_headers =
            begin
              rp_headers = as_staff_headers(@operator, host: @host, session_public_id: @token.public_id)
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
                  when "edit" then "edit-org"
                  else "#{rp_family}-#{rp_surface}"
                  end
                rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                rp_client = OidcClientRegistry.find!(rp_client_id)
                rp_key = [rp_client.client_id, rp_token.public_id]
                @base_browser_rp_credentials ||= {}
                if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                    !(rp_token.device_session_id && OperatorRpSession.exists?(
                      device_session_id: rp_token.device_session_id,
                      oidc_client_id: rp_client.client_id,
                      revoked_at: nil,
                    ))
                  rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                  rp_now = Time.current
                  rp_session = OperatorRpSession.create!(
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
            end
          f3_host = f3_headers["Host"]
          f3_route =
            begin
              Rails.application.routes.recognize_path("https://#{f3_host}/") if f3_host.present?
            rescue ActionController::RoutingError
              nil
            end
          f3_family, f3_surface = f3_route&.fetch(:controller)&.split("/")
          if %w(base warp core edit).include?(f3_family) && f3_surface == "org"
            f3_client_id =
              case f3_family
              when "base" then "base-#{f3_surface}-ww"
              when "edit" then "edit-org"
              else "#{f3_family}-#{f3_surface}"
              end
            f3_token = OperatorToken.find_by!(public_id: f3_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f3_client = OidcClientRegistry.find!(f3_client_id)
            f3_key = [f3_client.client_id, f3_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f3_key] && f3_token.currently_usable? &&
                !(f3_token.device_session_id && OperatorRpSession.exists?(
                  device_session_id: f3_token.device_session_id,
                  oidc_client_id: f3_client.client_id,
                  revoked_at: nil,
                ))
              f3_token.rotate_refresh_token! unless f3_token.device_session_record.current_refresh_token_id
              f3_now = Time.current
              f3_session = OperatorRpSession.create!(
                operator_token: f3_token, oidc_client_id: f3_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f3_now,
                refresh_token_expires_at: f3_now + 10.minutes,
              )
              f3_access = AuthenticationTokenService.encode(
                f3_token.actor_record, host: f3_host, resource_type: "operator",
                                       session_public_id: f3_token.public_id,
                                       base_session_public_id: f3_token.public_id,
                                       oidc_sid: f3_session.public_id, oidc_jti: f3_session.oidc_jti,
                                       expires_at: f3_now + 10.minutes, scopes: %w(openid profile),
                                       issuer: OidcIssuer.for_client(f3_client), audiences: [f3_client.aud],
                                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f3_client),
                                       subject: OidcSubject.for(
                                         f3_token.actor_record,
                                         resource_type: "operator",
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
      end
    get base_org_dashboard_avatar_image_url(ri: "jp"), headers: http_headers_4

    assert_response :not_found
    assert_empty response.body
  end

  test "a selected Avatar with a stored image is shown and streamed privately" do
    avatar = provision_avatar!
    avatar.update!(image: png_io)
    select_avatar!(avatar)

    http_headers_3 =
      begin
        begin
          f4_headers =
            begin
              rp_headers = as_staff_headers(@operator, host: @host, session_public_id: @token.public_id)
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
                  when "edit" then "edit-org"
                  else "#{rp_family}-#{rp_surface}"
                  end
                rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                rp_client = OidcClientRegistry.find!(rp_client_id)
                rp_key = [rp_client.client_id, rp_token.public_id]
                @base_browser_rp_credentials ||= {}
                if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                    !(rp_token.device_session_id && OperatorRpSession.exists?(
                      device_session_id: rp_token.device_session_id,
                      oidc_client_id: rp_client.client_id,
                      revoked_at: nil,
                    ))
                  rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                  rp_now = Time.current
                  rp_session = OperatorRpSession.create!(
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
            end
          f4_host = f4_headers["Host"]
          f4_route =
            begin
              Rails.application.routes.recognize_path("https://#{f4_host}/") if f4_host.present?
            rescue ActionController::RoutingError
              nil
            end
          f4_family, f4_surface = f4_route&.fetch(:controller)&.split("/")
          if %w(base warp core edit).include?(f4_family) && f4_surface == "org"
            f4_client_id =
              case f4_family
              when "base" then "base-#{f4_surface}-ww"
              when "edit" then "edit-org"
              else "#{f4_family}-#{f4_surface}"
              end
            f4_token = OperatorToken.find_by!(public_id: f4_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f4_client = OidcClientRegistry.find!(f4_client_id)
            f4_key = [f4_client.client_id, f4_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f4_key] && f4_token.currently_usable? &&
                !(f4_token.device_session_id && OperatorRpSession.exists?(
                  device_session_id: f4_token.device_session_id,
                  oidc_client_id: f4_client.client_id,
                  revoked_at: nil,
                ))
              f4_token.rotate_refresh_token! unless f4_token.device_session_record.current_refresh_token_id
              f4_now = Time.current
              f4_session = OperatorRpSession.create!(
                operator_token: f4_token, oidc_client_id: f4_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f4_now,
                refresh_token_expires_at: f4_now + 10.minutes,
              )
              f4_access = AuthenticationTokenService.encode(
                f4_token.actor_record, host: f4_host, resource_type: "operator",
                                       session_public_id: f4_token.public_id,
                                       base_session_public_id: f4_token.public_id,
                                       oidc_sid: f4_session.public_id, oidc_jti: f4_session.oidc_jti,
                                       expires_at: f4_now + 10.minutes, scopes: %w(openid profile),
                                       issuer: OidcIssuer.for_client(f4_client), audiences: [f4_client.aud],
                                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f4_client),
                                       subject: OidcSubject.for(
                                         f4_token.actor_record,
                                         resource_type: "operator",
                                       ), client_id: f4_client.client_id,
              )
              @base_browser_rp_credentials[f4_key] = [f4_access, f4_session.issue_refresh_token!]
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
      end
    get base_org_dashboard_url(ri: "jp"), headers: http_headers_3

    assert_equal(
      { "src" => base_org_dashboard_avatar_image_path(v: avatar.image_cache_key) },
      inertia_props.dig("sections", 0, "current_identity", "avatar_image"),
    )

    http_headers_2 =
      begin
        begin
          f5_headers =
            begin
              rp_headers = as_staff_headers(@operator, host: @host, session_public_id: @token.public_id)
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
                  when "edit" then "edit-org"
                  else "#{rp_family}-#{rp_surface}"
                  end
                rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                rp_client = OidcClientRegistry.find!(rp_client_id)
                rp_key = [rp_client.client_id, rp_token.public_id]
                @base_browser_rp_credentials ||= {}
                if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                    !(rp_token.device_session_id && OperatorRpSession.exists?(
                      device_session_id: rp_token.device_session_id,
                      oidc_client_id: rp_client.client_id,
                      revoked_at: nil,
                    ))
                  rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                  rp_now = Time.current
                  rp_session = OperatorRpSession.create!(
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
            end
          f5_host = f5_headers["Host"]
          f5_route =
            begin
              Rails.application.routes.recognize_path("https://#{f5_host}/") if f5_host.present?
            rescue ActionController::RoutingError
              nil
            end
          f5_family, f5_surface = f5_route&.fetch(:controller)&.split("/")
          if %w(base warp core edit).include?(f5_family) && f5_surface == "org"
            f5_client_id =
              case f5_family
              when "base" then "base-#{f5_surface}-ww"
              when "edit" then "edit-org"
              else "#{f5_family}-#{f5_surface}"
              end
            f5_token = OperatorToken.find_by!(public_id: f5_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f5_client = OidcClientRegistry.find!(f5_client_id)
            f5_key = [f5_client.client_id, f5_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f5_key] && f5_token.currently_usable? &&
                !(f5_token.device_session_id && OperatorRpSession.exists?(
                  device_session_id: f5_token.device_session_id,
                  oidc_client_id: f5_client.client_id,
                  revoked_at: nil,
                ))
              f5_token.rotate_refresh_token! unless f5_token.device_session_record.current_refresh_token_id
              f5_now = Time.current
              f5_session = OperatorRpSession.create!(
                operator_token: f5_token, oidc_client_id: f5_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f5_now,
                refresh_token_expires_at: f5_now + 10.minutes,
              )
              f5_access = AuthenticationTokenService.encode(
                f5_token.actor_record, host: f5_host, resource_type: "operator",
                                       session_public_id: f5_token.public_id,
                                       base_session_public_id: f5_token.public_id,
                                       oidc_sid: f5_session.public_id, oidc_jti: f5_session.oidc_jti,
                                       expires_at: f5_now + 10.minutes, scopes: %w(openid profile),
                                       issuer: OidcIssuer.for_client(f5_client), audiences: [f5_client.aud],
                                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f5_client),
                                       subject: OidcSubject.for(
                                         f5_token.actor_record,
                                         resource_type: "operator",
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
      end
    get base_org_dashboard_avatar_image_url(ri: "jp"), headers: http_headers_2

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal STORED_PNG.b, response.body.b
    assert_includes response.headers["Cache-Control"].to_s, "private"
    assert_includes response.headers["Cache-Control"].to_s, "must-revalidate"
  end

  test "switching back to the Avatar-less selection drops the previous Avatar's image" do
    avatar = provision_avatar!
    avatar.update!(image: png_io)
    select_avatar!(avatar)
    http_headers_1 =
      begin
        begin
          f6_headers =
            begin
              rp_headers = as_staff_headers(@operator, host: @host, session_public_id: @token.public_id)
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
                  when "edit" then "edit-org"
                  else "#{rp_family}-#{rp_surface}"
                  end
                rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                rp_client = OidcClientRegistry.find!(rp_client_id)
                rp_key = [rp_client.client_id, rp_token.public_id]
                @base_browser_rp_credentials ||= {}
                if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                    !(rp_token.device_session_id && OperatorRpSession.exists?(
                      device_session_id: rp_token.device_session_id,
                      oidc_client_id: rp_client.client_id,
                      revoked_at: nil,
                    ))
                  rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                  rp_now = Time.current
                  rp_session = OperatorRpSession.create!(
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
            end
          f6_host = f6_headers["Host"]
          f6_route =
            begin
              Rails.application.routes.recognize_path("https://#{f6_host}/") if f6_host.present?
            rescue ActionController::RoutingError
              nil
            end
          f6_family, f6_surface = f6_route&.fetch(:controller)&.split("/")
          if %w(base warp core edit).include?(f6_family) && f6_surface == "org"
            f6_client_id =
              case f6_family
              when "base" then "base-#{f6_surface}-ww"
              when "edit" then "edit-org"
              else "#{f6_family}-#{f6_surface}"
              end
            f6_token = OperatorToken.find_by!(public_id: f6_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f6_client = OidcClientRegistry.find!(f6_client_id)
            f6_key = [f6_client.client_id, f6_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f6_key] && f6_token.currently_usable? &&
                !(f6_token.device_session_id && OperatorRpSession.exists?(
                  device_session_id: f6_token.device_session_id,
                  oidc_client_id: f6_client.client_id,
                  revoked_at: nil,
                ))
              f6_token.rotate_refresh_token! unless f6_token.device_session_record.current_refresh_token_id
              f6_now = Time.current
              f6_session = OperatorRpSession.create!(
                operator_token: f6_token, oidc_client_id: f6_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f6_now,
                refresh_token_expires_at: f6_now + 10.minutes,
              )
              f6_access = AuthenticationTokenService.encode(
                f6_token.actor_record, host: f6_host, resource_type: "operator",
                                       session_public_id: f6_token.public_id,
                                       base_session_public_id: f6_token.public_id,
                                       oidc_sid: f6_session.public_id, oidc_jti: f6_session.oidc_jti,
                                       expires_at: f6_now + 10.minutes, scopes: %w(openid profile),
                                       issuer: OidcIssuer.for_client(f6_client), audiences: [f6_client.aud],
                                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f6_client),
                                       subject: OidcSubject.for(
                                         f6_token.actor_record,
                                         resource_type: "operator",
                                       ), client_id: f6_client.client_id,
              )
              @base_browser_rp_credentials[f6_key] = [f6_access, f6_session.issue_refresh_token!]
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
      end
    get base_org_dashboard_avatar_image_url(ri: "jp"), headers: http_headers_1
    etag = response.headers.fetch("ETag")

    avatarless = switcher.current.fetch(:candidates).find { |candidate| candidate[:avatar].nil? }
    switcher.switch(
      account_public_id: avatarless.fetch(:public_id),
      organization_public_id: avatarless.dig(:organization, :public_id),
      organization_unit_public_id: avatarless.dig(:organization, :unit_public_id),
    )

    assert_nil @token.reload.selected_avatar_public_id

    http_headers_0 =
      begin
        begin
          f7_headers =
            begin
              rp_headers = as_staff_headers(@operator, host: @host, session_public_id: @token.public_id)
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
                  when "edit" then "edit-org"
                  else "#{rp_family}-#{rp_surface}"
                  end
                rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                rp_client = OidcClientRegistry.find!(rp_client_id)
                rp_key = [rp_client.client_id, rp_token.public_id]
                @base_browser_rp_credentials ||= {}
                if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                    !(rp_token.device_session_id && OperatorRpSession.exists?(
                      device_session_id: rp_token.device_session_id,
                      oidc_client_id: rp_client.client_id,
                      revoked_at: nil,
                    ))
                  rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                  rp_now = Time.current
                  rp_session = OperatorRpSession.create!(
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
            end
          f7_host = f7_headers["Host"]
          f7_route =
            begin
              Rails.application.routes.recognize_path("https://#{f7_host}/") if f7_host.present?
            rescue ActionController::RoutingError
              nil
            end
          f7_family, f7_surface = f7_route&.fetch(:controller)&.split("/")
          if %w(base warp core edit).include?(f7_family) && f7_surface == "org"
            f7_client_id =
              case f7_family
              when "base" then "base-#{f7_surface}-ww"
              when "edit" then "edit-org"
              else "#{f7_family}-#{f7_surface}"
              end
            f7_token = OperatorToken.find_by!(public_id: f7_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f7_client = OidcClientRegistry.find!(f7_client_id)
            f7_key = [f7_client.client_id, f7_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f7_key] && f7_token.currently_usable? &&
                !(f7_token.device_session_id && OperatorRpSession.exists?(
                  device_session_id: f7_token.device_session_id,
                  oidc_client_id: f7_client.client_id,
                  revoked_at: nil,
                ))
              f7_token.rotate_refresh_token! unless f7_token.device_session_record.current_refresh_token_id
              f7_now = Time.current
              f7_session = OperatorRpSession.create!(
                operator_token: f7_token, oidc_client_id: f7_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f7_now,
                refresh_token_expires_at: f7_now + 10.minutes,
              )
              f7_access = AuthenticationTokenService.encode(
                f7_token.actor_record, host: f7_host, resource_type: "operator",
                                       session_public_id: f7_token.public_id,
                                       base_session_public_id: f7_token.public_id,
                                       oidc_sid: f7_session.public_id, oidc_jti: f7_session.oidc_jti,
                                       expires_at: f7_now + 10.minutes, scopes: %w(openid profile),
                                       issuer: OidcIssuer.for_client(f7_client), audiences: [f7_client.aud],
                                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f7_client),
                                       subject: OidcSubject.for(
                                         f7_token.actor_record,
                                         resource_type: "operator",
                                       ), client_id: f7_client.client_id,
              )
              @base_browser_rp_credentials[f7_key] = [f7_access, f7_session.issue_refresh_token!]
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
      end
    get base_org_dashboard_url(ri: "jp"), headers: http_headers_0

    assert_not inertia_props.dig("sections", 0, "current_identity").key?("avatar_image")

    get base_org_dashboard_avatar_image_url(ri: "jp"), headers: begin
      begin
        f8_headers =
          begin
            rp_headers = as_staff_headers(@operator, host: @host, session_public_id: @token.public_id)
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
                when "edit" then "edit-org"
                else "#{rp_family}-#{rp_surface}"
                end
              rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              rp_client = OidcClientRegistry.find!(rp_client_id)
              rp_key = [rp_client.client_id, rp_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                  !(rp_token.device_session_id && OperatorRpSession.exists?(
                    device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                  ))
                rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                rp_now = Time.current
                rp_session = OperatorRpSession.create!(
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
          end
        f8_host = f8_headers["Host"]
        f8_route =
          begin
            Rails.application.routes.recognize_path("https://#{f8_host}/") if f8_host.present?
          rescue ActionController::RoutingError
            nil
          end
        f8_family, f8_surface = f8_route&.fetch(:controller)&.split("/")
        if %w(base warp core edit).include?(f8_family) && f8_surface == "org"
          f8_client_id =
            case f8_family
            when "base" then "base-#{f8_surface}-ww"
            when "edit" then "edit-org"
            else "#{f8_family}-#{f8_surface}"
            end
          f8_token = OperatorToken.find_by!(public_id: f8_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          f8_client = OidcClientRegistry.find!(f8_client_id)
          f8_key = [f8_client.client_id, f8_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[f8_key] && f8_token.currently_usable? &&
              !(f8_token.device_session_id && OperatorRpSession.exists?(
                device_session_id: f8_token.device_session_id,
                oidc_client_id: f8_client.client_id,
                revoked_at: nil,
              ))
            f8_token.rotate_refresh_token! unless f8_token.device_session_record.current_refresh_token_id
            f8_now = Time.current
            f8_session = OperatorRpSession.create!(
              operator_token: f8_token, oidc_client_id: f8_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f8_now,
              refresh_token_expires_at: f8_now + 10.minutes,
            )
            f8_access = AuthenticationTokenService.encode(
              f8_token.actor_record, host: f8_host, resource_type: "operator",
                                     session_public_id: f8_token.public_id, base_session_public_id: f8_token.public_id,
                                     oidc_sid: f8_session.public_id, oidc_jti: f8_session.oidc_jti,
                                     expires_at: f8_now + 10.minutes, scopes: %w(openid profile),
                                     issuer: OidcIssuer.for_client(f8_client), audiences: [f8_client.aud],
                                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f8_client),
                                     subject: OidcSubject.for(
                                       f8_token.actor_record,
                                       resource_type: "operator",
                                     ), client_id: f8_client.client_id,
            )
            @base_browser_rp_credentials[f8_key] = [f8_access, f8_session.issue_refresh_token!]
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
    end.merge("If-None-Match" => etag)

    assert_response :not_found
  end

  test "an unauthenticated request receives no image" do
    avatar = provision_avatar!
    avatar.update!(image: png_io)
    select_avatar!(avatar)

    get base_org_dashboard_avatar_image_url(ri: "jp"), headers: host_headers(@host)

    assert_response :unauthorized
    assert_empty response.body
    assert_nil response.location
    assert_not_equal STORED_PNG.b, response.body.b
  end

  test "com exposes no Avatar image route" do
    assert_not Rails.application.routes.named_routes.key?(:base_com_dashboard_avatar_image)
  end

  private

  def provision_avatar!
    AvatarProvisioning::Create.call(
      actor: @operator,
      subject_type: :agent,
      subject: @bootstrap.account,
      avatar_params: { moniker: "Org Avatar" },
      handle_params: { handle: "org-#{SecureRandom.hex(5)}" },
      owner_surface: "org",
      owner_collective_public_id: @bootstrap.collective.public_id,
    ).avatar
  end

  def select_avatar!(avatar)
    candidate =
      BaseSelectorAuthority.new(surface: :org, principal: @operator, session: @token)
        .selectable_candidates.find { |entry| entry.dig(:public, :avatar_public_id) == avatar.public_id }
    BaseSelectorAuthority.select(
      surface: :org, principal: @operator, session: @token,
      params: candidate.fetch(:public),
    )
  end

  def switcher
    BaseSwitcherAuthority.new(surface: :org, principal: @operator, session: @token.reload)
  end

  def png_io
    io = StringIO.new(STORED_PNG.dup)
    io.define_singleton_method(:original_filename) { "avatar.png" }
    io
  end
end
