# typed: false
# frozen_string_literal: true

require "test_helper"

# Telephone OTP is accepted only for sign-up and telephone registration. It is
# never a sign-in proof, so the sign-in OTP web API must expose email only.
# This test fails if the telephone namespace is restored.
class TelephoneSignInAbsenceTest < ActionDispatch::IntegrationTest
  AUTH_HOSTS = [
    ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
  ].freeze

  test "sign-in telephone otp endpoint is not routable on the app auth surface" do
    AUTH_HOSTS.each do |host|
      assert_raises(ActionController::RoutingError, "telephone sign-in OTP is routable on #{host}") do
        Rails.application.routes.recognize_path(
          "http://#{host}/web/v0/in/telephone/otp",
          method: :post,
        )
      end
    end
  end

  test "sign-in email otp endpoint stays routable on the app auth surface" do
    AUTH_HOSTS.each do |host|
      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/web/v0/in/email/otp",
        method: :post,
      )

      assert_equal "create", recognized[:action]
      assert_equal "auth/app/web/v0/in/email/otps", recognized[:controller]
    end
  end

  test "no telephone path helper exists for the sign-in otp web api" do
    helpers = Rails.application.routes.url_helpers.methods.map(&:to_s)

    assert_empty helpers.grep(/web_v0_in_telephone/)
    assert_not_empty helpers.grep(/web_v0_in_email_otp/)
  end
end
