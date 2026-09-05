# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::Org::HealthsControllerTest < ActionDispatch::IntegrationTest
  test "GET /health returns the text/plain aggregate" do
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")

    get auth_org_health_url(ri: "jp")

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_not_equal "text/html", response.media_type
    assert_match(/\Astatus: \w+\nstartup: \w+\nliveness: \w+\nreadiness: \w+\n\z/, response.body)
  end
end
