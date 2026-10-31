# frozen_string_literal: true

require "test_helper"

class SocialSignupMissingFlowTest < ActionDispatch::IntegrationTest
  NAVIGATION_HEADERS = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }.freeze

  %w(google apple).each do |provider|
    test "#{provider} signup callback cannot replace its missing entry Flow" do
      prior_test_mode = OmniAuth.config.test_mode
      prior_mock = OmniAuth.config.mock_auth[provider.to_sym]
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[provider.to_sym] = OmniAuth::AuthHash.new(
        provider: provider, uid: "missing-flow-#{SecureRandom.hex(8)}", info: { name: "Fixture" },
        credentials: { token: "fixture", expires_at: 1.hour.from_now.to_i },
      )
      host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
      https!
      client = OidcClientRegistry.find!("core-app-jp")
      transaction = OidcAuthorizationTransactionCoordinator.issue!(
        surface: "app", intent: "sign_up", params: {
          response_type: "code",
          client_id: client.client_id,
          redirect_uri: client.redirect_uris.first,
          code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
          code_challenge_method: "S256",
          state: SecureRandom.urlsafe_base64(16),
          nonce: SecureRandom.urlsafe_base64(16),
          scope: "openid profile",
          prompt: "create",
        },
      ).transaction
      handoff = BaseAuthAdmissionCoordinator.issue_handoff!(
        transaction: transaction, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
      )
      get(auth_app_sign_up_path, params: { entry_ref: handoff.reference, ri: "jp" }, headers: NAVIGATION_HEADERS)
      get(response.location, headers: NAVIGATION_HEADERS)
      binding = ClientAuthAdmissionBinding.find_by!(entry_ref: handoff.reference)
      binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
      get(auth_app_sign_up_path, params: { entry_ref: handoff.reference, ri: "jp" }, headers: NAVIGATION_HEADERS)

      assert_response :see_other
      get(response.location, headers: NAVIGATION_HEADERS)

      assert_response :success
      start_path =
        (provider == "google") ? auth_app_social_google_registration_path : auth_app_social_apple_registration_path
      callback_path =
        (provider == "google") ? auth_app_social_google_callback_path : auth_app_social_apple_callback_path
      assert_difference("ClientSignUpFlow.count", 1) { post(start_path, params: { ri: "jp" }) }
      assert_response :temporary_redirect
      state = session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
      flow = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))
      flow.destroy!

      assert_no_difference(
        [
          "ClientSignUpFlow.count", "Client.count", "ClientToken.count",
          "ClientGoogleIdentity.count", "ClientAppleIdentity.count",
        ],
      ) do
        get(
          callback_path, params: { state: state, ri: "jp" }, headers: {
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-origin",
          },
        )
      end

      assert_response :bad_request
    ensure
      OmniAuth.config.mock_auth[provider.to_sym] = prior_mock
      OmniAuth.config.test_mode = prior_test_mode
    end
  end
end
