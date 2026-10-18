# typed: false
# frozen_string_literal: true

require "test_helper"

# Org sign-in completes only through the normal or emergency passkey ceremony, and both establish
# the session with `auth_method: "passkey"`, which bypasses the second factor
# (AuthenticationBase#mfa_bypassed_for_auth_method?). Every `log_in` caller passes
# `require_totp_check: false`. No org state therefore reaches MFA_PENDING, so the org surface serves
# no second-factor challenge at all; this is not the emergency passkey ceremony, which stays routed.
class Auth::Org::Sign::In::MfaChallengeAbsenceTest < ActionDispatch::IntegrationTest
  ORG_HOST = ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")

  [
    ["/sign/in/challenge", :get],
    ["/sign/in/challenge", :delete],
    ["/sign/in/challenge/passkey/new", :get],
    ["/sign/in/challenge/passkey", :post],
  ].each do |path, verb|
    test "org host does not route #{verb.upcase} #{path}" do
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{ORG_HOST}#{path}", method: verb)
      end
    end
  end

  test "org emergency passkey sign-in stays routed" do
    route = Rails.application.routes.recognize_path("http://#{ORG_HOST}/sign/in/emergency/passkey/new", method: :get)

    assert_equal "auth/org/sign/in/emergency/passkeys", route[:controller]
  end
end
