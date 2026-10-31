# typed: false
# frozen_string_literal: true

require "test_helper"

class Warp::Org::Api::V0::Preferences::PreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("PUBLIC_WARP_STAFF_URL", "warp.org.localhost")
  end

  test "GET theme without preference state returns the system default" do
    get warp_org_api_v0_preferences_theme_path, as: :json

    assert_response :ok
    assert_equal "sy", response.parsed_body.fetch("theme")
  end

  test "PATCH theme is refused on the read-only Warp host" do
    assert_no_difference -> { OperatorPreference.count } do
      patch warp_org_api_v0_preferences_theme_path, params: { theme: "dark" }, as: :json
    end

    assert_response :forbidden
    assert_nil response.headers["Set-Cookie"]
  end

  test "GET cookie reports the anonymous consent banner" do
    get warp_org_api_v0_preferences_cookie_path, as: :json

    assert_response :ok
    assert response.parsed_body.fetch("show_banner")
  end

  test "PATCH cookie is refused on the read-only Warp host" do
    assert_no_difference -> { OperatorPreference.count } do
      patch warp_org_api_v0_preferences_cookie_path, params: { consented: true }, as: :json
    end

    assert_response :forbidden
    assert_nil response.headers["Set-Cookie"]
  end
end
