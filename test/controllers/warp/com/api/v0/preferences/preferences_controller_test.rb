# typed: false
# frozen_string_literal: true

require "test_helper"

class Warp::Com::Api::V0::Preferences::PreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("PUBLIC_WARP_CORPORATE_URL", "warp.com.localhost")
  end

  test "GET theme without preference state returns the system default" do
    get warp_com_api_v0_preferences_theme_path, as: :json

    assert_response :ok
    assert_equal "sy", response.parsed_body.fetch("theme")
  end

  test "PATCH theme writes the public theme cookie" do
    patch warp_com_api_v0_preferences_theme_path, params: { theme: "dark" }, as: :json

    assert_response :ok
    assert_equal "dr", response.parsed_body.fetch("theme")
    assert_includes response.headers["Set-Cookie"].to_s, "#{PreferenceIoKeys::Cookies::THEME}=dr"
  end

  test "GET cookie reports the anonymous consent banner" do
    get warp_com_api_v0_preferences_cookie_path, as: :json

    assert_response :ok
    assert response.parsed_body.fetch("show_banner")
  end

  test "PATCH cookie stores anonymous consent without issuing preference credentials" do
    assert_no_difference -> { ComPreference.count } do
      patch warp_com_api_v0_preferences_cookie_path, params: { consented: true }, as: :json
    end

    assert_response :no_content
    set_cookie = response.headers["Set-Cookie"].to_s

    assert_includes set_cookie, "preference_consented=1"
    assert_not_includes set_cookie, "#{PreferenceCookieName.access(surface: :com)}="
    assert_not_includes set_cookie, "#{AuthenticationBase::ACCESS_COOKIE_KEY}="
  end
end
