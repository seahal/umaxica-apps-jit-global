# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthAuthenticationRateLimitTest < ActionDispatch::IntegrationTest
  # Rate-limit counters are a NullStore by default in test so unrelated tests
  # cannot accumulate them; this file asserts real limiting behavior, so it
  # opts into a deterministic MemoryStore.
  rate_limit_counters!

  self.fixture_table_names = []

  setup do
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  teardown do
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  test "app Secret requires admission before limiting while com and org Secret routes remain absent" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    post "/sign/in/secret", params: { secret: "" }

    assert_response :bad_request

    host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")
    post "/sign/in/secret", params: { secret_credential_login_form: { identifier: "", secret_credential_value: "" } }

    assert_response :not_found

    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
    post "/sign/in/secret", params: { secret_credential_login_form: { identifier: "", secret_credential_value: "" } }

    assert_response :not_found
  end

  test "app passkey options sign-in hits explicit rails rate limit" do
    host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"))
    admission = BaseAuthAdmissionCoordinator.issue_local_entry!(
      surface: "app", intent: "sign_in", base_browser_nonce: "test-browser-nonce", base_token: nil,
    )
    redeem_auth_ceremony_entry!(
      auth_app_sign_in_path, reference: admission.reference, params: { ri: "jp" },
    )

    assert_response :see_other
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
