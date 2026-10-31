# typed: false
# frozen_string_literal: true

require "test_helper"

class Warp::App::Api::V0::Preferences::ThemeControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("PUBLIC_WARP_SERVICE_URL")
  end

  test "GET shows the system theme without creating Preference state" do
    assert_no_difference -> { ClientPreference.count } do
      get warp_app_api_v0_preferences_theme_path, as: :json
    end

    assert_response :ok
    assert_equal "sy", response.parsed_body.fetch("theme")
    assert_nil response.headers["Set-Cookie"]
  end

  test "PATCH cannot write Preference state on the read-only Warp host" do
    assert_no_difference -> { ClientPreference.count } do
      patch warp_app_api_v0_preferences_theme_path, params: { theme: "dark" }, as: :json
    end

    assert_response :forbidden
    assert_nil response.headers["Set-Cookie"]
  end
end
