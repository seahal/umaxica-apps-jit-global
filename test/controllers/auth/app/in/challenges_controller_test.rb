# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::App::Sign::In::ChallengesControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_passkey_statuses,
           :client_email_statuses, :client_totp_credential_statuses

  setup do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    https!
    ClientSignInFlowState.ensure_defaults!
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    @user = Client.create!(mfa_level_enabled: true)
    @email = "challenge_hub_#{SecureRandom.hex(4)}@example.com".freeze
    @email_record = @user.client_emails.create!(address: @email, user_email_status_id: ClientEmailStatus::VERIFIED)
    @email_record.finalize_binding!
    ClientTotpCredential.create!(
      user: @user,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      title: "totp",
    )
    admission = BaseAuthAdmissionCoordinator.issue_local_entry!(
      surface: "app", intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
    )
    get auth_app_sign_in_path, params: { entry_ref: admission.reference, ri: "jp" }
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post "/ceremony_bindings", params: { entry_ref: admission.reference, authenticity_token: csrf, ri: "jp" }

    assert_response :see_other
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: admission.reference)
    binding.reload.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get auth_app_sign_in_path, params: { entry_ref: admission.reference, ri: "jp" }
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_sign_in_path, params: { entry_ref: admission.reference, authenticity_token: csrf, ri: "jp" }

    assert_response :see_other
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

  # ===================================================================
  # MFA cancellation (DELETE /sign/in/challenge)
  # ===================================================================

  test "destroy ends the pending MFA ceremony and returns to the sign-in entry point" do
    establish_pending_mfa_via_email!
    cycle = ClientSignInFlow.where(principal_id: @user.id).order(:id).last

    assert_predicate cycle, :sign_in_mfa_pending?

    assert_no_difference -> { ClientToken.where(user_id: @user.id).count } do
      delete auth_app_sign_in_challenge_path(ri: "jp")
    end

    assert_response :see_other
    assert_redirected_to auth_app_sign_in_path(ri: "jp")
    assert_predicate cycle.reload, :sign_in_halted?
    assert_nil session[:pending_mfa]
    assert_nil session[:mfa_user_id]
    assert_nil session[:pending_login_user_id]
    assert_nil session[:app_sign_in_flow_locator]
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY].presence
  end

  test "a cancelled MFA challenge cannot be resumed or answered" do
    establish_pending_mfa_via_email!
    delete auth_app_sign_in_challenge_path(ri: "jp")

    get new_auth_app_sign_in_challenge_totp_path(ri: "jp")

    assert_response :see_other
    assert_redirected_to auth_app_sign_in_path(ri: "jp")

    assert_no_difference -> { ClientToken.where(user_id: @user.id).count } do
      post auth_app_sign_in_challenge_totp_path(ri: "jp"),
           params: { totp_challenge_form: { token: "123456" }, "cf-turnstile-response": "test_token" }
    end

    assert_response :see_other
    assert_redirected_to auth_app_sign_in_path(ri: "jp")
  end

  test "destroy without a pending MFA ceremony changes nothing and returns to sign-in" do
    assert_no_difference -> { ClientToken.count } do
      delete auth_app_sign_in_challenge_path(ri: "jp")
    end

    assert_response :see_other
    assert_redirected_to auth_app_sign_in_path(ri: "jp")
  end

  test "the method selection page offers cancellation and no back link" do
    establish_pending_mfa_via_email!
    follow_redirect!

    assert_equal(
      { "label" => I18n.t("actions.cancel"),
        "action" => auth_app_sign_in_challenge_path(ri: "jp"),
        "method" => "delete", },
      inertia_props.fetch("cancel"),
    )
    assert_not inertia_props.key?("back_link")
  end

  test "with no usable method the page keeps cancellation as the only exit" do
    @user.client_totp_credentials.delete_all
    @user.client_passkeys.delete_all
    establish_pending_mfa_via_email!
    follow_redirect!

    assert_empty inertia_props.fetch("methods")
    assert_predicate inertia_props.fetch("no_methods_notice"), :present?
    assert_not inertia_props.key?("back_link")
    assert_equal "delete", inertia_props.fetch("cancel").fetch("method")
  end

  test "the TOTP challenge keeps back to method selection separate from cancellation" do
    establish_pending_mfa_via_email!

    get new_auth_app_sign_in_challenge_totp_path(ri: "jp")

    assert_response :success
    assert_equal auth_app_sign_in_challenge_path(ri: "jp"), inertia_props.fetch("back_link").fetch("href")
    assert_equal "delete", inertia_props.fetch("cancel").fetch("method")
    assert_equal auth_app_sign_in_challenge_path(ri: "jp"), inertia_props.fetch("cancel").fetch("action")

    # Following Back is a GET and leaves the ceremony running.
    get auth_app_sign_in_challenge_path(ri: "jp")

    assert_response :success
    assert_predicate session[:pending_mfa], :present?
  end

  test "cancelling on the com host leaves the app ceremony untouched" do
    establish_pending_mfa_via_email!

    host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")
    delete auth_com_sign_in_challenge_path(ri: "jp")

    assert_response :see_other

    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    get auth_app_sign_in_challenge_path(ri: "jp")

    assert_response :success
    assert_predicate ClientSignInFlow.where(principal_id: @user.id).order(:id).last, :sign_in_mfa_pending?
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

    delivery_class = OtpEmailNotifierRollout.enabled?(:app) ? OtpNotifierEmailDeliveryJob : OtpMailDeliveryJob
    delivery =
      ActiveJob::Base.queue_adapter.enqueued_jobs.reverse.find do |entry|
        entry.fetch(:job) == delivery_class
      end
    payload = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last.fetch(:params)
    ceremony = ClientAuthCeremonySession.find(payload.fetch(:auth_ceremony_session_ref))

    assert_equal @email_record.public_id, ceremony.email_otp_context.fetch("contact_ref")
    assert_equal payload.fetch(:auth_email_otp_generation), ceremony.email_otp_context.fetch("generation")
    pass_code = OutboundSensitivePayload.decrypt_email_otp(payload.fetch(:encrypted_hotp_token))

    patch(
      auth_app_sign_in_email_path(ri: "jp"), params: {
        user_email: { pass_code: pass_code },
      },
    )

    assert_response :found
    assert_redirected_to auth_app_sign_in_challenge_path(ri: "jp")
  end
end
