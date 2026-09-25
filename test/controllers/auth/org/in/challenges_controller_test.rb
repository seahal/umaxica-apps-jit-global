# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::Sign::In::ChallengesControllerTest < ActionDispatch::IntegrationTest
  test "challenge hub redirects when no authentication challenge is pending" do
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")

    get auth_org_sign_in_challenge_path(ri: "jp")

    assert_response :see_other
    assert_redirected_to auth_org_sign_in_path(ri: "jp")
  end
end
