# typed: false
# frozen_string_literal: true

require "test_helper"

class Warp::App::Api::V0::Preferences::CookieControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("PUBLIC_WARP_SERVICE_URL")
  end

  test "GET shows the default consent banner without creating Preference state" do
    assert_no_difference -> { ClientPreference.count } do
      get warp_app_api_v0_preferences_cookie_path, as: :json
    end

    assert_response :ok
    assert response.parsed_body.fetch("show_banner")
    assert_nil response.headers["Set-Cookie"]
  end

  test "PATCH cannot write consent on the read-only Warp host" do
    assert_no_difference -> { ClientPreference.count } do
      patch warp_app_api_v0_preferences_cookie_path, params: { consented: true }, as: :json
    end

    assert_response :forbidden
    assert_nil response.headers["Set-Cookie"]
  end
end
