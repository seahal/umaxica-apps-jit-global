# typed: false
# frozen_string_literal: true

require "test_helper"

class Warp::App::Api::V0::Preferences::CookieControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("PUBLIC_WARP_SERVICE_URL", "warp.app.localhost")
  end

  test "GET shows the consent banner without preference state" do
    get warp_app_api_v0_preferences_cookie_path, as: :json

    assert_response :ok
    assert response.parsed_body.fetch("show_banner")
  end

  test "PATCH stores anonymous consent in the consent buffer without issuing preference credentials" do
    assert_no_difference -> { ClientPreference.count } do
      patch warp_app_api_v0_preferences_cookie_path, params: { consented: true }, as: :json
    end

    assert_response :no_content
    set_cookie = response.headers["Set-Cookie"].to_s

    assert_includes set_cookie, "preference_consented=1"
    assert_not_includes set_cookie, "#{PreferenceCookieName.access(surface: :app)}="
    assert_not_includes set_cookie, "#{AuthenticationBase::ACCESS_COOKIE_KEY}="
  end
end
