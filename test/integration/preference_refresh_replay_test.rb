# typed: false
# frozen_string_literal: true

require "test_helper"

# A preference refresh token is single-use: each write without a live access token rotates it.
# Presenting an already rotated token again is a replay and must fail closed.
class PreferenceRefreshReplayTest < ActionDispatch::IntegrationTest
  test "replaying a rotated preference refresh token is refused with 401 and clears the preference cookies" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    refresh_name = PreferenceCookieName.refresh(surface: :app)
    access_name = PreferenceCookieName.access(surface: :app)

    patch base_app_preference_theme_path(ri: "jp"),
          params: { preference_theme: { option_id: AppPreferenceThemeOption::DARK } }

    assert_response :redirect
    first_refresh = cookies[refresh_name]

    cookies.delete(access_name)
    patch base_app_preference_theme_path(ri: "jp"),
          params: { preference_theme: { option_id: AppPreferenceThemeOption::LIGHT } }

    assert_response :redirect
    assert_not_equal first_refresh, cookies[refresh_name], "the second write must rotate the refresh token"

    cookies.delete(access_name)
    cookies[refresh_name] = first_refresh
    patch base_app_preference_theme_path(ri: "jp"),
          params: { preference_theme: { option_id: AppPreferenceThemeOption::SYSTEM } }

    assert_response :unauthorized
    assert_predicate cookies[refresh_name].to_s, :empty?
    assert_predicate cookies[access_name].to_s, :empty?
  end

  test "an unknown preference refresh token is refused with 401" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    patch base_app_preference_theme_path(ri: "jp"),
          params: { preference_theme: { option_id: AppPreferenceThemeOption::DARK } }
    refresh_name = PreferenceCookieName.refresh(surface: :app)
    forged = "#{cookies[refresh_name].to_s.split(".").first}.#{SecureRandom.urlsafe_base64(32)}"

    cookies.delete(PreferenceCookieName.access(surface: :app))
    cookies[refresh_name] = forged
    patch base_app_preference_theme_path(ri: "jp"),
          params: { preference_theme: { option_id: AppPreferenceThemeOption::LIGHT } }

    assert_response :unauthorized
    assert_predicate cookies[refresh_name].to_s, :empty?
  end
end
