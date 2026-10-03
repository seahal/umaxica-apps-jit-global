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
    headers = as_user_headers(user, host: host)
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
        client_preference.reload.user_preference_theme.option_id
      end

    assert_equal ClientPreferenceThemeOption::DARK, theme
  end
end
