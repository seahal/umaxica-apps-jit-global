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

  test "app passkey options sign-in hits explicit rails rate limit" do
    host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    https!
    client = OidcClientRegistry.find!("core-app-jp")
    parent = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in",
      params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        code_challenge: SecureRandom.urlsafe_base64(32),
        code_challenge_method: "S256",
        scope: "openid",
        state: SecureRandom.urlsafe_base64(24),
        nonce: SecureRandom.urlsafe_base64(24),
      },
    ).transaction
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: parent, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" })
    get(response.location)
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" })
    get(response.location)

    assert_response :success
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    5.times do
      post(
        auth_app_sign_in_passkey_options_path(ri: "jp"),
        params: { :identifier => "", "cf-turnstile-response" => "test" }, as: :json,
      )

      assert_response :unprocessable_content
    end
    post(
      auth_app_sign_in_passkey_options_path(ri: "jp"),
      params: { :identifier => "", "cf-turnstile-response" => "test" }, as: :json,
    )

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
  ensure
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "app Secret requires admission before limiting while com and org Secret routes remain absent" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    post "/sign/in/secret", params: { secret: "" }

    assert_response :bad_request

    host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    post "/sign/in/secret", params: { secret_credential_login_form: { identifier: "", secret_credential_value: "" } }

    assert_response :not_found

    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    post "/sign/in/secret", params: { secret_credential_login_form: { identifier: "", secret_credential_value: "" } }

    assert_response :not_found
  end
end
