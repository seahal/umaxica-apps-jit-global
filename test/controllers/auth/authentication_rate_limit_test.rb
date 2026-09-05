# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthAuthenticationRateLimitTest < ActionDispatch::IntegrationTest
  counts_rate_limits!
  self.fixture_table_names = []

  setup do
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  teardown do
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  test "app secret credential sign-in hits explicit rails rate limit" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")

    5.times do
      post auth_app_sign_in_secret_url(ri: "jp"),
           params: { secret_credential_login_form: { identifier: "", secret_credential_value: "" } }
    end

    post auth_app_sign_in_secret_url(ri: "jp"),
         params: { secret_credential_login_form: { identifier: "", secret_credential_value: "" } }

    assert_sign_rate_limited
  end

  test "com secret credential sign-in hits explicit rails rate limit" do
    host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")

    5.times do
      post auth_com_sign_in_secret_url(ri: "jp"),
           params: { secret_credential_login_form: { identifier: "", secret_credential_value: "" } }
    end

    post auth_com_sign_in_secret_url(ri: "jp"),
         params: { secret_credential_login_form: { identifier: "", secret_credential_value: "" } }

    assert_sign_rate_limited
  end

  test "org secret credential sign-in hits explicit rails rate limit" do
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")

    5.times do
      post auth_org_sign_in_secret_url(ri: "jp"),
           params: { secret_credential_login_form: { identifier: "", secret_credential_value: "" } }
    end

    post auth_org_sign_in_secret_url(ri: "jp"),
         params: { secret_credential_login_form: { identifier: "", secret_credential_value: "" } }

    assert_sign_rate_limited
  end

  test "app passkey options sign-in hits explicit rails rate limit" do
    host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"))
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }

    5.times do
      post(auth_app_sign_in_passkey_options_url(ri: "jp"), params: { identifier: "" }, as: :json)
    end

    post(auth_app_sign_in_passkey_options_url(ri: "jp"), params: { identifier: "" }, as: :json)

    assert_sign_rate_limited
  ensure
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  private

  # The rule that fired is deliberately absent from the response: naming it tells a caller how to
  # reshape traffic to evade the limit. It is asserted through the `rate_limit.action_controller`
  # notification instead (see test/controllers/concerns/rate_limit_test.rb).
  def assert_sign_rate_limited
    assert_response :too_many_requests
    assert_equal "60", response.headers["Retry-After"]
    assert_nil response.headers["X-RateLimit-Rule"]
    assert_nil response.headers["X-RateLimit-Layer"]

    if response.media_type == "application/problem+json"
      body = response.parsed_body

      assert_equal "urn:umaxica:problem:rate-limited", body.fetch("type")
      assert_equal 429, body.fetch("status")
      assert_equal I18n.t("errors.rate_limit.exceeded"), body.fetch("detail")
    else
      assert_equal "text/plain", response.media_type
      assert_equal I18n.t("errors.rate_limit.exceeded"), response.body
    end
  end
end
