# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::DashboardAvatarImagesControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses

  # 1x1 PNG, distinct from the static default image.
  STORED_PNG = Base64.decode64(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
  ).freeze
  DEFAULT_PNG_PATH = Rails.root.join("app/assets/images/base/default_avatar.png")

  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    @user = clients(:one)
    @user.update!(status_id: ClientStatus::ACTIVE)
    @token = ClientToken.create!(authentication_epoch: 0, user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    select_token!(principal: @user, token: @token)
  end

  test "streams the selected Avatar's stored image privately with a revalidated ETag" do
    selected_avatar(@token).update!(image: png_io)
    @token.update!(last_used_at: 10.minutes.ago)
    last_used_at = @token.reload.last_used_at

    http_headers_9 =
      begin
        fx0_user = @user
        fx0_token = @token
        begin
          f0_headers =
            begin
              rp_headers = as_user_headers(
                fx0_user,
                host: @host,
                session_public_id: fx0_token.public_id,
              )
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
                  when "edit" then "edit-org-ww"
                  when "tech" then "tech-org-ww"
                  else "#{rp_family}-#{rp_surface}-jp"
                  end
                rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                rp_client = OidcClientRegistry.find!(rp_client_id)
                rp_key = [rp_client.client_id, rp_token.public_id]
                @base_browser_rp_credentials ||= {}
                if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                    !(rp_token.device_session_id && OpAppGrant.exists?(
                      device_session_id: rp_token.device_session_id,
                      oidc_client_id: rp_client.client_id,
                      revoked_at: nil,
                    ))
                  rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                  rp_now = Time.current
                  rp_session = OpAppGrant.create!(
                    authentication_epoch: 0,
                    client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                    refresh_token_expires_at: rp_now + 10.minutes,
                  )
                  rp_access = AuthenticationTokenService.encode(
                    rp_token.actor_record, host: rp_host, resource_type: "client",
                                           session_public_id: rp_token.public_id,
                                           base_session_public_id: rp_token.public_id,
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
              when "tech" then "tech-org-ww"
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
    get base_app_dashboard_avatar_image_url(ri: "jp"), headers: http_headers_9

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal STORED_PNG.b, response.body.b
    assert_cache_control_private_revalidated
    assert_predicate response.headers["ETag"], :present?
    assert_match(/\Ainline/, response.headers["Content-Disposition"].to_s)
    assert_equal last_used_at, @token.reload.last_used_at
  end

  test "answers a matching If-None-Match with 304 and no body" do
    selected_avatar(@token).update!(image: png_io)
    http_headers_8 =
      begin
        fx1_user = @user
        fx1_token = @token
        begin
          f1_headers =
            begin
              rp_headers = as_user_headers(
                fx1_user,
                host: @host,
                session_public_id: fx1_token.public_id,
              )
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
                  when "edit" then "edit-org-ww"
                  when "tech" then "tech-org-ww"
                  else "#{rp_family}-#{rp_surface}-jp"
                  end
                rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                rp_client = OidcClientRegistry.find!(rp_client_id)
                rp_key = [rp_client.client_id, rp_token.public_id]
                @base_browser_rp_credentials ||= {}
                if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                    !(rp_token.device_session_id && OpAppGrant.exists?(
                      device_session_id: rp_token.device_session_id,
                      oidc_client_id: rp_client.client_id,
                      revoked_at: nil,
                    ))
                  rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                  rp_now = Time.current
                  rp_session = OpAppGrant.create!(
                    authentication_epoch: 0,
                    client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                    refresh_token_expires_at: rp_now + 10.minutes,
                  )
                  rp_access = AuthenticationTokenService.encode(
                    rp_token.actor_record, host: rp_host, resource_type: "client",
                                           session_public_id: rp_token.public_id,
                                           base_session_public_id: rp_token.public_id,
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
              when "tech" then "tech-org-ww"
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
    get base_app_dashboard_avatar_image_url(ri: "jp"), headers: http_headers_8
    etag = response.headers.fetch("ETag")

    get base_app_dashboard_avatar_image_url(ri: "jp"),
        headers: begin
          fx2_user = @user
          fx2_token = @token
          begin
            f2_headers =
              begin
                rp_headers = as_user_headers(
                  fx2_user,
                  host: @host,
                  session_public_id: fx2_token.public_id,
                )
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
                    when "edit" then "edit-org-ww"
                    when "tech" then "tech-org-ww"
                    else "#{rp_family}-#{rp_surface}-jp"
                    end
                  rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  rp_client = OidcClientRegistry.find!(rp_client_id)
                  rp_key = [rp_client.client_id, rp_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                      !(rp_token.device_session_id && OpAppGrant.exists?(
                        device_session_id: rp_token.device_session_id,
                        oidc_client_id: rp_client.client_id,
                        revoked_at: nil,
                      ))
                    rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                    rp_now = Time.current
                    rp_session = OpAppGrant.create!(
                      authentication_epoch: 0,
                      client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                      refresh_token_expires_at: rp_now + 10.minutes,
                    )
                    rp_access = AuthenticationTokenService.encode(
                      rp_token.actor_record, host: rp_host, resource_type: "client",
                                             session_public_id: rp_token.public_id,
                                             base_session_public_id: rp_token.public_id,
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
                when "tech" then "tech-org-ww"
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
          end
        end.merge("If-None-Match" => etag)

    assert_response :not_modified
    assert_empty response.body
    assert_cache_control_private_revalidated
  end

  test "HEAD returns the image headers without the body" do
    selected_avatar(@token).update!(image: png_io)

    head base_app_dashboard_avatar_image_url(ri: "jp"), headers: begin
      fx3_user = @user
      fx3_token = @token
      begin
        f3_headers =
          begin
            rp_headers = as_user_headers(
              fx3_user,
              host: @host,
              session_public_id: fx3_token.public_id,
            )
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
                when "edit" then "edit-org-ww"
                when "tech" then "tech-org-ww"
                else "#{rp_family}-#{rp_surface}-jp"
                end
              rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              rp_client = OidcClientRegistry.find!(rp_client_id)
              rp_key = [rp_client.client_id, rp_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                  !(rp_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                  ))
                rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                rp_now = Time.current
                rp_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                  refresh_token_expires_at: rp_now + 10.minutes,
                )
                rp_access = AuthenticationTokenService.encode(
                  rp_token.actor_record, host: rp_host, resource_type: "client",
                                         session_public_id: rp_token.public_id,
                                         base_session_public_id: rp_token.public_id,
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
            when "edit" then "edit-org-ww"
            when "tech" then "tech-org-ww"
            else "#{f3_family}-#{f3_surface}"
            end
          f3_token = ClientToken.find_by!(public_id: f3_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          f3_client = OidcClientRegistry.find!(f3_client_id)
          f3_key = [f3_client.client_id, f3_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[f3_key] && f3_token.currently_usable? &&
              !(f3_token.device_session_id && OpAppGrant.exists?(
                device_session_id: f3_token.device_session_id,
                oidc_client_id: f3_client.client_id,
                revoked_at: nil,
              ))
            f3_token.rotate_refresh_token! unless f3_token.device_session_record.current_refresh_token_id
            f3_now = Time.current
            f3_session = OpAppGrant.create!(
              authentication_epoch: 0,
              client_token: f3_token, oidc_client_id: f3_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f3_now,
              refresh_token_expires_at: f3_now + 10.minutes,
            )
            f3_access = AuthenticationTokenService.encode(
              f3_token.actor_record, host: f3_host, resource_type: "client",
                                     session_public_id: f3_token.public_id, base_session_public_id: f3_token.public_id,
                                     oidc_sid: f3_session.public_id, oidc_jti: f3_session.oidc_jti,
                                     expires_at: f3_now + 10.minutes, scopes: %w(openid profile),
                                     issuer: OidcIssuer.for_client(f3_client), audiences: [f3_client.aud],
                                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f3_client),
                                     subject: OidcSubject.for(
                                       f3_token.actor_record,
                                       resource_type: "client",
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

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_empty response.body
  end

  test "serves the static default image when the required Avatar has no stored image" do
    assert_nil selected_avatar(@token).image

    http_headers_7 =
      begin
        fx4_user = @user
        fx4_token = @token
        begin
          f4_headers =
            begin
              rp_headers = as_user_headers(
                fx4_user,
                host: @host,
                session_public_id: fx4_token.public_id,
              )
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
                  when "edit" then "edit-org-ww"
                  when "tech" then "tech-org-ww"
                  else "#{rp_family}-#{rp_surface}-jp"
                  end
                rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                rp_client = OidcClientRegistry.find!(rp_client_id)
                rp_key = [rp_client.client_id, rp_token.public_id]
                @base_browser_rp_credentials ||= {}
                if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                    !(rp_token.device_session_id && OpAppGrant.exists?(
                      device_session_id: rp_token.device_session_id,
                      oidc_client_id: rp_client.client_id,
                      revoked_at: nil,
                    ))
                  rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                  rp_now = Time.current
                  rp_session = OpAppGrant.create!(
                    authentication_epoch: 0,
                    client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                    refresh_token_expires_at: rp_now + 10.minutes,
                  )
                  rp_access = AuthenticationTokenService.encode(
                    rp_token.actor_record, host: rp_host, resource_type: "client",
                                           session_public_id: rp_token.public_id,
                                           base_session_public_id: rp_token.public_id,
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
              when "edit" then "edit-org-ww"
              when "tech" then "tech-org-ww"
              else "#{f4_family}-#{f4_surface}"
              end
            f4_token = ClientToken.find_by!(public_id: f4_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f4_client = OidcClientRegistry.find!(f4_client_id)
            f4_key = [f4_client.client_id, f4_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f4_key] && f4_token.currently_usable? &&
                !(f4_token.device_session_id && OpAppGrant.exists?(
                  device_session_id: f4_token.device_session_id,
                  oidc_client_id: f4_client.client_id,
                  revoked_at: nil,
                ))
              f4_token.rotate_refresh_token! unless f4_token.device_session_record.current_refresh_token_id
              f4_now = Time.current
              f4_session = OpAppGrant.create!(
                authentication_epoch: 0,
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
    get base_app_dashboard_avatar_image_url(ri: "jp"), headers: http_headers_7

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal File.binread(DEFAULT_PNG_PATH), response.body.b
    assert_cache_control_private_revalidated
  end

  test "an unauthenticated request receives no image" do
    selected_avatar(@token).update!(image: png_io)

    get base_app_dashboard_avatar_image_url(ri: "jp"), headers: host_headers(@host)

    assert_response :unauthorized
    assert_empty response.body
    assert_nil response.location
    assert_not_equal STORED_PNG.b, response.body.b
  end

  test "request parameters never choose another principal's Avatar" do
    other = clients(:two)
    other.update!(status_id: ClientStatus::ACTIVE)
    other_token = ClientToken.create!(authentication_epoch: 0, user: other, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    select_token!(principal: other, token: other_token)
    other_avatar = selected_avatar(other_token)
    other_avatar.update!(image: png_io)

    http_headers_6 =
      begin
        fx5_user = @user
        fx5_token = @token
        begin
          f5_headers =
            begin
              rp_headers = as_user_headers(
                fx5_user,
                host: @host,
                session_public_id: fx5_token.public_id,
              )
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
                  when "edit" then "edit-org-ww"
                  when "tech" then "tech-org-ww"
                  else "#{rp_family}-#{rp_surface}-jp"
                  end
                rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                rp_client = OidcClientRegistry.find!(rp_client_id)
                rp_key = [rp_client.client_id, rp_token.public_id]
                @base_browser_rp_credentials ||= {}
                if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                    !(rp_token.device_session_id && OpAppGrant.exists?(
                      device_session_id: rp_token.device_session_id,
                      oidc_client_id: rp_client.client_id,
                      revoked_at: nil,
                    ))
                  rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                  rp_now = Time.current
                  rp_session = OpAppGrant.create!(
                    authentication_epoch: 0,
                    client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                    refresh_token_expires_at: rp_now + 10.minutes,
                  )
                  rp_access = AuthenticationTokenService.encode(
                    rp_token.actor_record, host: rp_host, resource_type: "client",
                                           session_public_id: rp_token.public_id,
                                           base_session_public_id: rp_token.public_id,
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
              when "tech" then "tech-org-ww"
              else "#{f5_family}-#{f5_surface}"
              end
            f5_token = ClientToken.find_by!(public_id: f5_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
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
      end
    get base_app_dashboard_avatar_image_url(
      ri: "jp", avatar_public_id: other_avatar.public_id,
      account_public_id: other_token.selected_account_public_id,
    ),
        headers: http_headers_6

    assert_response :success
    assert_equal File.binread(DEFAULT_PNG_PATH), response.body.b
  end

  test "a session selection naming another principal's Avatar is refused, not defaulted" do
    other = clients(:two)
    other.update!(status_id: ClientStatus::ACTIVE)
    other_token = ClientToken.create!(authentication_epoch: 0, user: other, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    select_token!(principal: other, token: other_token)
    selected_avatar(other_token).update!(image: png_io)
    @token.update!(selected_avatar_public_id: other_token.selected_avatar_public_id)

    http_headers_5 =
      begin
        fx6_user = @user
        fx6_token = @token
        begin
          f6_headers =
            begin
              rp_headers = as_user_headers(
                fx6_user,
                host: @host,
                session_public_id: fx6_token.public_id,
              )
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
                  when "edit" then "edit-org-ww"
                  when "tech" then "tech-org-ww"
                  else "#{rp_family}-#{rp_surface}-jp"
                  end
                rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                rp_client = OidcClientRegistry.find!(rp_client_id)
                rp_key = [rp_client.client_id, rp_token.public_id]
                @base_browser_rp_credentials ||= {}
                if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                    !(rp_token.device_session_id && OpAppGrant.exists?(
                      device_session_id: rp_token.device_session_id,
                      oidc_client_id: rp_client.client_id,
                      revoked_at: nil,
                    ))
                  rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                  rp_now = Time.current
                  rp_session = OpAppGrant.create!(
                    authentication_epoch: 0,
                    client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                    refresh_token_expires_at: rp_now + 10.minutes,
                  )
                  rp_access = AuthenticationTokenService.encode(
                    rp_token.actor_record, host: rp_host, resource_type: "client",
                                           session_public_id: rp_token.public_id,
                                           base_session_public_id: rp_token.public_id,
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
              when "tech" then "tech-org-ww"
              else "#{f6_family}-#{f6_surface}"
              end
            f6_token = ClientToken.find_by!(public_id: f6_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
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
    get base_app_dashboard_avatar_image_url(ri: "jp"), headers: http_headers_5

    assert_response :not_found
    assert_not_equal STORED_PNG.b, response.body.b
  end

  test "a storage failure surfaces as an error instead of the default image" do
    avatar = selected_avatar(@token)
    avatar.update!(image: png_io)
    avatar.image.delete

    http_headers_4 =
      begin
        fx7_user = @user
        fx7_token = @token
        begin
          f7_headers =
            begin
              rp_headers = as_user_headers(
                fx7_user,
                host: @host,
                session_public_id: fx7_token.public_id,
              )
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
                  when "edit" then "edit-org-ww"
                  when "tech" then "tech-org-ww"
                  else "#{rp_family}-#{rp_surface}-jp"
                  end
                rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                rp_client = OidcClientRegistry.find!(rp_client_id)
                rp_key = [rp_client.client_id, rp_token.public_id]
                @base_browser_rp_credentials ||= {}
                if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                    !(rp_token.device_session_id && OpAppGrant.exists?(
                      device_session_id: rp_token.device_session_id,
                      oidc_client_id: rp_client.client_id,
                      revoked_at: nil,
                    ))
                  rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                  rp_now = Time.current
                  rp_session = OpAppGrant.create!(
                    authentication_epoch: 0,
                    client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                    refresh_token_expires_at: rp_now + 10.minutes,
                  )
                  rp_access = AuthenticationTokenService.encode(
                    rp_token.actor_record, host: rp_host, resource_type: "client",
                                           session_public_id: rp_token.public_id,
                                           base_session_public_id: rp_token.public_id,
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
              when "tech" then "tech-org-ww"
              else "#{f7_family}-#{f7_surface}"
              end
            f7_token = ClientToken.find_by!(public_id: f7_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
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
    assert_raises(Shrine::FileNotFound, Errno::ENOENT, KeyError) do
      get base_app_dashboard_avatar_image_url(ri: "jp"), headers: http_headers_4
    end
  end

  test "the image cache key changes with the Avatar, so another Persona's image is never reused" do
    other = clients(:two)
    other.update!(status_id: ClientStatus::ACTIVE)
    other_token = ClientToken.create!(authentication_epoch: 0, user: other, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    select_token!(principal: other, token: other_token)
    mine = selected_avatar(@token)
    theirs = selected_avatar(other_token)
    mine.update!(image: png_io)
    theirs.update!(image: png_io)

    http_headers_3 =
      begin
        fx8_user = @user
        fx8_token = @token
        begin
          f8_headers =
            begin
              rp_headers = as_user_headers(
                fx8_user,
                host: @host,
                session_public_id: fx8_token.public_id,
              )
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
                  when "edit" then "edit-org-ww"
                  when "tech" then "tech-org-ww"
                  else "#{rp_family}-#{rp_surface}-jp"
                  end
                rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                rp_client = OidcClientRegistry.find!(rp_client_id)
                rp_key = [rp_client.client_id, rp_token.public_id]
                @base_browser_rp_credentials ||= {}
                if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                    !(rp_token.device_session_id && OpAppGrant.exists?(
                      device_session_id: rp_token.device_session_id,
                      oidc_client_id: rp_client.client_id,
                      revoked_at: nil,
                    ))
                  rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                  rp_now = Time.current
                  rp_session = OpAppGrant.create!(
                    authentication_epoch: 0,
                    client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                    refresh_token_expires_at: rp_now + 10.minutes,
                  )
                  rp_access = AuthenticationTokenService.encode(
                    rp_token.actor_record, host: rp_host, resource_type: "client",
                                           session_public_id: rp_token.public_id,
                                           base_session_public_id: rp_token.public_id,
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
          f8_host = f8_headers["Host"]
          f8_route =
            begin
              Rails.application.routes.recognize_path("https://#{f8_host}/") if f8_host.present?
            rescue ActionController::RoutingError
              nil
            end
          f8_family, f8_surface = f8_route&.fetch(:controller)&.split("/")
          if %w(base warp core edit).include?(f8_family) && f8_surface == "app"
            f8_client_id =
              case f8_family
              when "base" then "base-#{f8_surface}-ww"
              when "edit" then "edit-org-ww"
              when "tech" then "tech-org-ww"
              else "#{f8_family}-#{f8_surface}"
              end
            f8_token = ClientToken.find_by!(public_id: f8_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f8_client = OidcClientRegistry.find!(f8_client_id)
            f8_key = [f8_client.client_id, f8_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f8_key] && f8_token.currently_usable? &&
                !(f8_token.device_session_id && OpAppGrant.exists?(
                  device_session_id: f8_token.device_session_id,
                  oidc_client_id: f8_client.client_id,
                  revoked_at: nil,
                ))
              f8_token.rotate_refresh_token! unless f8_token.device_session_record.current_refresh_token_id
              f8_now = Time.current
              f8_session = OpAppGrant.create!(
                authentication_epoch: 0,
                client_token: f8_token, oidc_client_id: f8_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f8_now,
                refresh_token_expires_at: f8_now + 10.minutes,
              )
              f8_access = AuthenticationTokenService.encode(
                f8_token.actor_record, host: f8_host, resource_type: "client",
                                       session_public_id: f8_token.public_id,
                                       base_session_public_id: f8_token.public_id,
                                       oidc_sid: f8_session.public_id, oidc_jti: f8_session.oidc_jti,
                                       expires_at: f8_now + 10.minutes, scopes: %w(openid profile),
                                       issuer: OidcIssuer.for_client(f8_client), audiences: [f8_client.aud],
                                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f8_client),
                                       subject: OidcSubject.for(
                                         f8_token.actor_record,
                                         resource_type: "client",
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
      end
    get base_app_dashboard_url(ri: "jp"), headers: http_headers_3
    my_src = inertia_props.dig("sections", 0, "current_identity", "avatar_image", "src")
    http_headers_2 =
      begin
        fx9_user = other
        fx9_token = other_token
        begin
          f9_headers =
            begin
              rp_headers = as_user_headers(
                fx9_user,
                host: @host,
                session_public_id: fx9_token.public_id,
              )
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
                  when "edit" then "edit-org-ww"
                  when "tech" then "tech-org-ww"
                  else "#{rp_family}-#{rp_surface}-jp"
                  end
                rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                rp_client = OidcClientRegistry.find!(rp_client_id)
                rp_key = [rp_client.client_id, rp_token.public_id]
                @base_browser_rp_credentials ||= {}
                if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                    !(rp_token.device_session_id && OpAppGrant.exists?(
                      device_session_id: rp_token.device_session_id,
                      oidc_client_id: rp_client.client_id,
                      revoked_at: nil,
                    ))
                  rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                  rp_now = Time.current
                  rp_session = OpAppGrant.create!(
                    authentication_epoch: 0,
                    client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                    refresh_token_expires_at: rp_now + 10.minutes,
                  )
                  rp_access = AuthenticationTokenService.encode(
                    rp_token.actor_record, host: rp_host, resource_type: "client",
                                           session_public_id: rp_token.public_id,
                                           base_session_public_id: rp_token.public_id,
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
          f9_host = f9_headers["Host"]
          f9_route =
            begin
              Rails.application.routes.recognize_path("https://#{f9_host}/") if f9_host.present?
            rescue ActionController::RoutingError
              nil
            end
          f9_family, f9_surface = f9_route&.fetch(:controller)&.split("/")
          if %w(base warp core edit).include?(f9_family) && f9_surface == "app"
            f9_client_id =
              case f9_family
              when "base" then "base-#{f9_surface}-ww"
              when "edit" then "edit-org-ww"
              when "tech" then "tech-org-ww"
              else "#{f9_family}-#{f9_surface}"
              end
            f9_token = ClientToken.find_by!(public_id: f9_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f9_client = OidcClientRegistry.find!(f9_client_id)
            f9_key = [f9_client.client_id, f9_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f9_key] && f9_token.currently_usable? &&
                !(f9_token.device_session_id && OpAppGrant.exists?(
                  device_session_id: f9_token.device_session_id,
                  oidc_client_id: f9_client.client_id,
                  revoked_at: nil,
                ))
              f9_token.rotate_refresh_token! unless f9_token.device_session_record.current_refresh_token_id
              f9_now = Time.current
              f9_session = OpAppGrant.create!(
                authentication_epoch: 0,
                client_token: f9_token, oidc_client_id: f9_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f9_now,
                refresh_token_expires_at: f9_now + 10.minutes,
              )
              f9_access = AuthenticationTokenService.encode(
                f9_token.actor_record, host: f9_host, resource_type: "client",
                                       session_public_id: f9_token.public_id,
                                       base_session_public_id: f9_token.public_id,
                                       oidc_sid: f9_session.public_id, oidc_jti: f9_session.oidc_jti,
                                       expires_at: f9_now + 10.minutes, scopes: %w(openid profile),
                                       issuer: OidcIssuer.for_client(f9_client), audiences: [f9_client.aud],
                                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f9_client),
                                       subject: OidcSubject.for(
                                         f9_token.actor_record,
                                         resource_type: "client",
                                       ), client_id: f9_client.client_id,
              )
              @base_browser_rp_credentials[f9_key] = [f9_access, f9_session.issue_refresh_token!]
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
      end
    get base_app_dashboard_url(ri: "jp"), headers: http_headers_2
    their_src = inertia_props.dig("sections", 0, "current_identity", "avatar_image", "src")

    assert_equal base_app_dashboard_avatar_image_path(v: mine.image_cache_key), my_src
    assert_equal base_app_dashboard_avatar_image_path(v: theirs.image_cache_key), their_src
    assert_not_equal my_src, their_src

    http_headers_1 =
      begin
        fx10_user = @user
        fx10_token = @token
        begin
          f10_headers =
            begin
              rp_headers = as_user_headers(
                fx10_user,
                host: @host,
                session_public_id: fx10_token.public_id,
              )
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
                  when "edit" then "edit-org-ww"
                  when "tech" then "tech-org-ww"
                  else "#{rp_family}-#{rp_surface}-jp"
                  end
                rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                rp_client = OidcClientRegistry.find!(rp_client_id)
                rp_key = [rp_client.client_id, rp_token.public_id]
                @base_browser_rp_credentials ||= {}
                if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                    !(rp_token.device_session_id && OpAppGrant.exists?(
                      device_session_id: rp_token.device_session_id,
                      oidc_client_id: rp_client.client_id,
                      revoked_at: nil,
                    ))
                  rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                  rp_now = Time.current
                  rp_session = OpAppGrant.create!(
                    authentication_epoch: 0,
                    client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                    refresh_token_expires_at: rp_now + 10.minutes,
                  )
                  rp_access = AuthenticationTokenService.encode(
                    rp_token.actor_record, host: rp_host, resource_type: "client",
                                           session_public_id: rp_token.public_id,
                                           base_session_public_id: rp_token.public_id,
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
          f10_host = f10_headers["Host"]
          f10_route =
            begin
              Rails.application.routes.recognize_path("https://#{f10_host}/") if f10_host.present?
            rescue ActionController::RoutingError
              nil
            end
          f10_family, f10_surface = f10_route&.fetch(:controller)&.split("/")
          if %w(base warp core edit).include?(f10_family) && f10_surface == "app"
            f10_client_id =
              case f10_family
              when "base" then "base-#{f10_surface}-ww"
              when "edit" then "edit-org-ww"
              when "tech" then "tech-org-ww"
              else "#{f10_family}-#{f10_surface}"
              end
            f10_token = ClientToken.find_by!(public_id: f10_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f10_client = OidcClientRegistry.find!(f10_client_id)
            f10_key = [f10_client.client_id, f10_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f10_key] && f10_token.currently_usable? &&
                !(f10_token.device_session_id && OpAppGrant.exists?(
                  device_session_id: f10_token.device_session_id,
                  oidc_client_id: f10_client.client_id,
                  revoked_at: nil,
                ))
              f10_token.rotate_refresh_token! unless f10_token.device_session_record.current_refresh_token_id
              f10_now = Time.current
              f10_session = OpAppGrant.create!(
                authentication_epoch: 0,
                client_token: f10_token, oidc_client_id: f10_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f10_now,
                refresh_token_expires_at: f10_now + 10.minutes,
              )
              f10_access = AuthenticationTokenService.encode(
                f10_token.actor_record, host: f10_host, resource_type: "client",
                                        session_public_id: f10_token.public_id,
                                        base_session_public_id: f10_token.public_id,
                                        oidc_sid: f10_session.public_id, oidc_jti: f10_session.oidc_jti,
                                        expires_at: f10_now + 10.minutes, scopes: %w(openid profile),
                                        issuer: OidcIssuer.for_client(f10_client), audiences: [f10_client.aud],
                                        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f10_client),
                                        subject: OidcSubject.for(
                                          f10_token.actor_record,
                                          resource_type: "client",
                                        ), client_id: f10_client.client_id,
              )
              @base_browser_rp_credentials[f10_key] = [f10_access, f10_session.issue_refresh_token!]
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
      end
    get base_app_dashboard_avatar_image_url(ri: "jp"), headers: http_headers_1
    my_etag = response.headers.fetch("ETag")
    get base_app_dashboard_avatar_image_url(ri: "jp"),
        headers: begin
          fx11_user = other
          fx11_token = other_token
          begin
            f11_headers =
              begin
                rp_headers = as_user_headers(
                  fx11_user,
                  host: @host,
                  session_public_id: fx11_token.public_id,
                )
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
                    when "edit" then "edit-org-ww"
                    when "tech" then "tech-org-ww"
                    else "#{rp_family}-#{rp_surface}-jp"
                    end
                  rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  rp_client = OidcClientRegistry.find!(rp_client_id)
                  rp_key = [rp_client.client_id, rp_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                      !(rp_token.device_session_id && OpAppGrant.exists?(
                        device_session_id: rp_token.device_session_id,
                        oidc_client_id: rp_client.client_id,
                        revoked_at: nil,
                      ))
                    rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                    rp_now = Time.current
                    rp_session = OpAppGrant.create!(
                      authentication_epoch: 0,
                      client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                      refresh_token_expires_at: rp_now + 10.minutes,
                    )
                    rp_access = AuthenticationTokenService.encode(
                      rp_token.actor_record, host: rp_host, resource_type: "client",
                                             session_public_id: rp_token.public_id,
                                             base_session_public_id: rp_token.public_id,
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
            f11_host = f11_headers["Host"]
            f11_route =
              begin
                Rails.application.routes.recognize_path("https://#{f11_host}/") if f11_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f11_family, f11_surface = f11_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f11_family) && f11_surface == "app"
              f11_client_id =
                case f11_family
                when "base" then "base-#{f11_surface}-ww"
                when "edit" then "edit-org-ww"
                when "tech" then "tech-org-ww"
                else "#{f11_family}-#{f11_surface}"
                end
              f11_token = ClientToken.find_by!(public_id: f11_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f11_client = OidcClientRegistry.find!(f11_client_id)
              f11_key = [f11_client.client_id, f11_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f11_key] && f11_token.currently_usable? &&
                  !(f11_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f11_token.device_session_id,
                    oidc_client_id: f11_client.client_id,
                    revoked_at: nil,
                  ))
                f11_token.rotate_refresh_token! unless f11_token.device_session_record.current_refresh_token_id
                f11_now = Time.current
                f11_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f11_token, oidc_client_id: f11_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f11_now,
                  refresh_token_expires_at: f11_now + 10.minutes,
                )
                f11_access = AuthenticationTokenService.encode(
                  f11_token.actor_record, host: f11_host, resource_type: "client",
                                          session_public_id: f11_token.public_id,
                                          base_session_public_id: f11_token.public_id,
                                          oidc_sid: f11_session.public_id, oidc_jti: f11_session.oidc_jti,
                                          expires_at: f11_now + 10.minutes, scopes: %w(openid profile),
                                          issuer: OidcIssuer.for_client(f11_client), audiences: [f11_client.aud],
                                          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f11_client),
                                          subject: OidcSubject.for(
                                            f11_token.actor_record,
                                            resource_type: "client",
                                          ), client_id: f11_client.client_id,
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
        end.merge("If-None-Match" => my_etag)

    assert_response :success
    assert_equal STORED_PNG.b, response.body.b
  end

  test "the dashboard points a stored-image-less Avatar at the default version" do
    http_headers_0 =
      begin
        fx12_user = @user
        fx12_token = @token
        begin
          f12_headers =
            begin
              rp_headers = as_user_headers(
                fx12_user,
                host: @host,
                session_public_id: fx12_token.public_id,
              )
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
                  when "edit" then "edit-org-ww"
                  when "tech" then "tech-org-ww"
                  else "#{rp_family}-#{rp_surface}-jp"
                  end
                rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                rp_client = OidcClientRegistry.find!(rp_client_id)
                rp_key = [rp_client.client_id, rp_token.public_id]
                @base_browser_rp_credentials ||= {}
                if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                    !(rp_token.device_session_id && OpAppGrant.exists?(
                      device_session_id: rp_token.device_session_id,
                      oidc_client_id: rp_client.client_id,
                      revoked_at: nil,
                    ))
                  rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                  rp_now = Time.current
                  rp_session = OpAppGrant.create!(
                    authentication_epoch: 0,
                    client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                    refresh_token_expires_at: rp_now + 10.minutes,
                  )
                  rp_access = AuthenticationTokenService.encode(
                    rp_token.actor_record, host: rp_host, resource_type: "client",
                                           session_public_id: rp_token.public_id,
                                           base_session_public_id: rp_token.public_id,
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
          f12_host = f12_headers["Host"]
          f12_route =
            begin
              Rails.application.routes.recognize_path("https://#{f12_host}/") if f12_host.present?
            rescue ActionController::RoutingError
              nil
            end
          f12_family, f12_surface = f12_route&.fetch(:controller)&.split("/")
          if %w(base warp core edit).include?(f12_family) && f12_surface == "app"
            f12_client_id =
              case f12_family
              when "base" then "base-#{f12_surface}-ww"
              when "edit" then "edit-org-ww"
              when "tech" then "tech-org-ww"
              else "#{f12_family}-#{f12_surface}"
              end
            f12_token = ClientToken.find_by!(public_id: f12_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f12_client = OidcClientRegistry.find!(f12_client_id)
            f12_key = [f12_client.client_id, f12_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f12_key] && f12_token.currently_usable? &&
                !(f12_token.device_session_id && OpAppGrant.exists?(
                  device_session_id: f12_token.device_session_id,
                  oidc_client_id: f12_client.client_id,
                  revoked_at: nil,
                ))
              f12_token.rotate_refresh_token! unless f12_token.device_session_record.current_refresh_token_id
              f12_now = Time.current
              f12_session = OpAppGrant.create!(
                authentication_epoch: 0,
                client_token: f12_token, oidc_client_id: f12_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f12_now,
                refresh_token_expires_at: f12_now + 10.minutes,
              )
              f12_access = AuthenticationTokenService.encode(
                f12_token.actor_record, host: f12_host, resource_type: "client",
                                        session_public_id: f12_token.public_id,
                                        base_session_public_id: f12_token.public_id,
                                        oidc_sid: f12_session.public_id, oidc_jti: f12_session.oidc_jti,
                                        expires_at: f12_now + 10.minutes, scopes: %w(openid profile),
                                        issuer: OidcIssuer.for_client(f12_client), audiences: [f12_client.aud],
                                        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f12_client),
                                        subject: OidcSubject.for(
                                          f12_token.actor_record,
                                          resource_type: "client",
                                        ), client_id: f12_client.client_id,
              )
              @base_browser_rp_credentials[f12_key] = [f12_access, f12_session.issue_refresh_token!]
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
      end
    get base_app_dashboard_url(ri: "jp"), headers: http_headers_0

    assert_response :success
    assert_equal(
      { "src" => base_app_dashboard_avatar_image_path(v: "default") },
      inertia_props.dig("sections", 0, "current_identity", "avatar_image"),
    )
  end

  private

  def png_io
    io = StringIO.new(STORED_PNG.dup)
    io.define_singleton_method(:original_filename) { "avatar.png" }
    io
  end

  def assert_cache_control_private_revalidated
    cache_control = response.headers["Cache-Control"].to_s

    assert_includes cache_control, "private"
    assert_includes cache_control, "max-age=0"
    assert_includes cache_control, "must-revalidate"
    assert_not_includes cache_control, "public"
  end

  def select_token!(principal:, token:)
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: principal)
    BaseSelectorAuthority.prepare(surface: :app, principal: principal, session: token)
  end

  def selected_avatar(token)
    Avatar.find_by!(public_id: token.reload.selected_avatar_public_id)
  end
end
