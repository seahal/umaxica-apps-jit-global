# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::Sign::In::Challenge::PasskeysControllerTest < ActionDispatch::IntegrationTest
  test "challenge passkey page redirects when no MFA session is pending" do
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")

    get new_auth_org_sign_in_challenge_passkey_path(ri: "jp")

    assert_response :see_other
    assert_redirected_to auth_org_sign_in_path(ri: "jp")
  end

  test "challenge passkey POST redirects without a pending MFA session" do
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")

    post auth_org_sign_in_challenge_passkey_path(ri: "jp"), params: { mfa_passkey_form: { challenge_id: "unused" } }

    assert_response :see_other
    assert_redirected_to auth_org_sign_in_path(ri: "jp")
  end
end
