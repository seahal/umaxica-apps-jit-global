# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::App::HealthsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
  end

  test "GET /health returns the text/plain aggregate" do
    get auth_app_health_url(ri: "jp")

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_not_equal "text/html", response.media_type
    expected = %r{
      \A
      title:\ Health\ status\n
      namespace:\ \w+/\w+\n
      status:\ \w+\n
      startup:\ \w+\n
      liveness:\ \w+\n
      readiness:\ \w+\n
      timestamp:\ [^\n]+Z\n
      \z
    }x

    assert_match(expected, response.body.to_s.force_encoding(Encoding::UTF_8))
  end

  test "GET /health/readiness returns text/plain regardless of Accept" do
    get "/health/readiness?ri=jp", headers: { "Accept" => "text/html" }

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_not_equal "application/json", response.media_type
    assert_equal "ok\n", response.body
  end
end
