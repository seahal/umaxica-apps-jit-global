# typed: false
# frozen_string_literal: true

require "test_helper"

# A signed-in principal whose browser preference access token has lapsed rotates the refresh token on
# the next write. The rotated browser preference is then copied onto the principal's own preference
# so the two stay aligned (PreferenceAdoption#adopt_rotated_preference!).
class PreferenceRotationAdoptionTest < ActionDispatch::IntegrationTest
  fixtures :clients

  test "a rotated browser preference copies its theme onto the signed-in client's preference" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    user = clients(:none_user)
    client_preference =
      AppZenithRecord.connected_to(role: :writing) do
        ClientPreference.where(user_id: user.id).delete_all
        pref = ClientPreference.create!(user_id: user.id)
        ClientPreferenceTheme.create!(preference_id: pref.id, option_id: ClientPreferenceThemeOption::SYSTEM)
        pref
      end

    patch base_app_preference_theme_path(ri: "jp"),
          params: { preference_theme: { option_id: AppPreferenceThemeOption::DARK } }

    assert_response :redirect
    assert_predicate cookies[PreferenceCookieName.refresh(surface: :app)], :present?

    refresh_name = PreferenceCookieName.refresh(surface: :app)
    refresh_cookie = "#{refresh_name}=#{cookies[refresh_name]}"
    headers =
      begin
        rp_headers = as_user_headers(user, host: host)
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
    # The authentication harness replaces the Cookie header, so the preference refresh cookie is
    # carried alongside the access cookie explicitly. No preference access cookie is sent.
    headers["Cookie"] = "#{headers["Cookie"]}; #{refresh_cookie}"
    headers["HTTP_COOKIE"] = headers["Cookie"]
    patch base_app_preference_timezone_path(ri: "jp"),
          params: { preference_timezone: { option_id: AppPreferenceTimezoneOption::ETC_UTC } },
          headers: headers

    assert_response :redirect
    theme =
      AppZenithRecord.connected_to(role: :writing) do
        ClientPreferenceTheme.find_by!(preference_id: client_preference.id).option_id
      end

    assert_equal ClientPreferenceThemeOption::DARK, theme
  end
end
