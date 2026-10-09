# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "webauthn/fake_client"

module Auth::App::Sign::In::Passkey
  class AuthenticationFlowTest < ActionDispatch::IntegrationTest
    include ActiveSupport::Testing::TimeHelpers

    fixtures :clients, :client_statuses, :client_email_statuses, :client_passkey_statuses,
             :client_totp_credential_statuses

    setup do
      host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      https!
      TurnstileVerifierStub.challenge_enabled = true
      TurnstileVerifierStub.challenge_response = { "success" => true }
      TurnstileVerifierStub.enabled = true
      TurnstileVerifierStub.response = { "success" => true }
      @user = clients(:one)
      ClientEmail.create!(
        user: @user,
        address: "one@example.com",
        user_email_status_id: ClientEmailStatus::VERIFIED,
        otp_attempts_count: 0,
        otp_counter: "0",
        otp_private_key: "secret_credential",
        otp_expires_at: 10.minutes.from_now,
        otp_last_sent_at: 1.hour.ago,
      ).finalize_binding!

      @fake = WebAuthn::FakeClient.new("https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", encoding: :base64url)
      registration = @fake.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
      relying_party = WebAuthn::RelyingParty.new(
        id: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), allowed_origins: [@fake.origin], encoding: :base64url,
      )
      credential = WebAuthn::Credential.from_create(registration, relying_party: relying_party)
      @encoded_credential_id = credential.id
      @passkey = @user.client_passkeys.create!(
        webauthn_id: credential.id, public_key: credential.public_key, sign_count: 10,
        description: "Test Passkey", status_id: ClientPasskeyStatus::ACTIVE,
      )
      nonce = SecureRandom.urlsafe_base64(32)
      admission = BaseAuthAdmissionCoordinator.issue_local_entry!(
        surface: "app", intent: "sign_in", base_browser_nonce: nonce, base_token: nil,
      )
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: admission.reference)
      attached, raw_sid = ClientAuthCeremonySession.issue!
      binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
      binding.confirm_base!(
        base_token: nil,
        browser_digest: AuthAdmissionBinding.browser_digest(
          surface: "app", entry_ref: admission.reference,
          nonce: nonce,
        ),
      )
      BaseAuthAdmissionCoordinator.consume_entry_reference!(
        reference: admission.reference, surface: "app", expected_intent: "sign_in", binding: binding,
        raw_auth_sid: raw_sid,
      )
      admitted, admitted_sid = ClientAuthCeremonySession.rotate_and_admit!(
        admission_purpose: "local_sign_in", previous_raw_sid: raw_sid,
        local_sign_in_flow_ref: admission.transaction.public_id,
      )
      binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
      cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
      cookies.merge(
        "#{cookie_name}=#{Rack::Utils.escape(admitted_sid)}", URI.parse(@fake.origin),
      )
    end

    teardown do
      TurnstileVerifierStub.challenge_enabled = false
      TurnstileVerifierStub.challenge_response = nil
      TurnstileVerifierStub.enabled = false
      TurnstileVerifierStub.response = nil
    end

    test "should generate authentication options and store challenge in session" do
      email = @user.client_emails.first.address
      post auth_app_sign_in_passkey_options_url(ri: "jp"), params: options_params(identifier: email), as: :json

      assert_response :success
      json_response = response.parsed_body
      challenge_id = json_response["challenge_id"]

      assert_not_nil challenge_id

      # Verify session storage
      assert_not_nil session[:passkey_challenges]
      assert_not_nil session[:passkey_challenges][challenge_id]
      assert_equal "authentication", session[:passkey_challenges][challenge_id]["purpose"]
    end

    test "should verify valid credential and log in" do
      # 1. Get options to setup session
      email = @user.client_emails.first.address
      post auth_app_sign_in_passkey_options_url(ri: "jp"), params: options_params(identifier: email), as: :json

      json_response = response.parsed_body
      challenge_id = json_response["challenge_id"]
      session[:passkey_challenges][challenge_id]["challenge"]

      travel 31.seconds do
        assertion = @fake.get(
          challenge: response.parsed_body.fetch("options").fetch("challenge"),
          user_verified: true, sign_count: 11,
        )
        post auth_app_sign_in_passkey_verification_url(ri: "jp"), params: {
          challenge_id: challenge_id, credential: assertion,
        }, as: :json
      end

      assert_response :success
      json_response = response.parsed_body

      assert_equal "ok", json_response["status"]
      assert_nil json_response["access_token"]
      assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]

      # 3. Verify side effects
      # Challenge should be consumed (removed from session)
      # Challenge should be consumed (removed from session) or session reset
      assert_empty session[:passkey_challenges]
      @passkey.reload

      assert_equal 11, @passkey.sign_count # updated
    end

    test "passkey login completes without additional MFA even when MFA is enabled" do
      @user.update!(mfa_level_enabled: true)
      ClientTotpCredential.create!(
        user: @user,
        private_key: ROTP::Base32.random_base32,
        user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
        title: "app",
      )

      email = @user.client_emails.first.address
      post auth_app_sign_in_passkey_options_url(ri: "jp"), params: options_params(identifier: email), as: :json
      challenge_id = response.parsed_body["challenge_id"]

      travel 31.seconds do
        assertion = @fake.get(
          challenge: response.parsed_body.fetch("options").fetch("challenge"),
          user_verified: true, sign_count: 11,
        )
        post auth_app_sign_in_passkey_verification_url(ri: "jp"), params: {
          challenge_id: challenge_id, credential: assertion,
        }, as: :json
      end

      assert_response :success
      assert_equal "ok", response.parsed_body["status"]
      assert_not_equal "mfa_required", response.parsed_body["status"]
    end

    test "should fail verification with invalid challenge" do
      # 1. No options call (no session)

      post auth_app_sign_in_passkey_verification_url(ri: "jp"), params: {
        challenge_id: "invalid-id",
        credential: @fake.get(challenge: SecureRandom.urlsafe_base64(32), user_verified: true, sign_count: 11),
      }, as: :json

      assert_response :bad_request
      json_response = response.parsed_body

      assert_equal I18n.t("errors.webauthn.challenge_invalid"), json_response["error"]
    end

    private

    def options_params(identifier:)
      {
        identifier: identifier,
        "cf-turnstile-response": "test_token",
      }
    end
  end
end
