# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::App::Sign::In::ChallengesControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_passkey_statuses,
           :client_email_statuses, :client_totp_credential_statuses

  setup do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    @user = Client.create!(mfa_level_enabled: true)
    @email = "challenge_hub_#{SecureRandom.hex(4)}@example.com".freeze
    @email_record = @user.client_emails.create!(address: @email, user_email_status_id: ClientEmailStatus::VERIFIED)
    ClientTotpCredential.create!(
      user: @user,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      title: "totp",
    )
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "show requires pending_mfa and redirects to sign in" do
    get auth_app_sign_in_challenge_path(ri: "jp")

    assert_response :see_other
    assert_redirected_to auth_app_sign_in_path(ri: "jp")
  end

  test "show renders for pending_mfa user with MFA enabled" do
    establish_pending_mfa_via_email!

    follow_redirect!

    assert_response :success
    # Check for translation key in body - translation may be missing or present
    # assert response.body.include?(I18n.t("sign.app.in.mfa.title")) || response.body.include?("translation missing")
    # Check that TOTP method link is present
    assert_equal "auth/app/sign/in/challenges/show", inertia_component
    assert_includes inertia_props.fetch("methods").map { |method| method.fetch("key") }, "totp"
  end

  test "show does not display totp method when disabled" do
    @user.client_totp_credentials.delete_all

    establish_pending_mfa_via_email!

    follow_redirect!

    assert_response :success
    assert_not_includes inertia_props.fetch("methods").map { |method| method.fetch("label") },
                        I18n.t("sign.app.in.mfa.methods.totp")
  end

  test "show does not display passkey method when disabled" do
    @user.client_passkeys.delete_all

    establish_pending_mfa_via_email!

    follow_redirect!

    assert_response :success
    assert_not_includes inertia_props.fetch("methods").map { |method| method.fetch("label") },
                        I18n.t("sign.app.in.mfa.methods.passkey")
  end

  private

  def establish_pending_mfa_via_email!
    post(
      auth_app_sign_in_email_path(ri: "jp"), params: {
        user_email: { address: @email },
        "cf-turnstile-response": "test_token",
      },
    )

    assert_response :found

    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 55_555
    pass_code = ROTP::HOTP.new(otp_private_key).at(otp_counter).to_s
    @email_record.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)

    patch(
      auth_app_sign_in_email_path(ri: "jp"), params: {
        user_email: { pass_code: pass_code },
      },
    )

    assert_response :found
    assert_redirected_to auth_app_sign_in_challenge_path(ri: "jp")
  end
end
