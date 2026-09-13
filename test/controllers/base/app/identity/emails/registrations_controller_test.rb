# typed: false
# frozen_string_literal: true

require "test_helper"

# Registration ceremony for attaching an email address to an existing app
# client: the two-step OTP flow, the redelivery endpoint, and the Turnstile,
# missing-code, wrong-code and lock-out branches that guard them.
class Base::App::Identity::Emails::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_email_statuses,
           :client_token_kinds, :client_token_statuses, :client_token_binding_methods,
           :client_token_dbsc_statuses, :client_chronicle_events, :client_chronicle_levels

  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    @user = clients(:one)
    @token = ClientToken.create!(
      user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discarded_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)
    _verification, raw_verification = ClientVerification.issue_for_token!(token: @token)
    cookies[ClientVerification.cookie_name] = raw_verification
    @token.update!(
      last_step_up_at: Time.current, last_step_up_scope: "settings_email",
      last_step_up_aal: "aal2", last_step_up_method: "passkey",
      last_step_up_session_public_id: @token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app",
    )
    access_token = AuthenticationToken.encode(
      @user, host: @host, session_public_id: @token.public_id,
             resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    @headers = {
      "Authorization" => "Bearer #{access_token}",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => @host,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }.freeze

    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "new renders the registration form" do
    get new_base_app_identity_emails_registration_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
    assert_nil session[:email_registration_public_id]
  end

  test "new links back to the public preference page" do
    get new_base_app_identity_emails_registration_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
    assert_equal base_app_preference_url(ri: "jp", host: @host, protocol: request.protocol),
                 inertia_props.dig("back_link", "href")
  end

  test "edit redirects back to new when no registration is in progress" do
    get edit_base_app_identity_emails_registration_url(ri: "jp", host: @host), headers: @headers

    assert_response :redirect
    assert_match %r{/identity/emails/registration/new}, response.location
  end

  test "create rejects an address that fails model validation" do
    assert_no_difference("ClientEmail.count") do
      post base_app_identity_emails_registration_url(ri: "jp", host: @host),
           params: { user_email: { raw_address: "not-an-email" } }, headers: @headers
    end

    assert_response :unprocessable_content
  end

  test "create stores the pending registration and moves the ceremony to the verification step" do
    assert_difference("ClientEmail.count", 1) do
      post base_app_identity_emails_registration_url(ri: "jp", host: @host),
           params: { user_email: { raw_address: "app_email_reg_created@example.com" } }, headers: @headers
    end

    assert_response :redirect
    assert_match %r{/identity/emails/registration/edit}, response.location
    registered = ClientEmail.find_by!(public_id: session[:email_registration_public_id])

    assert_equal @user.id, registered.user_id
    assert_equal ClientEmailStatus::UNVERIFIED, registered.user_email_status_id
  end

  test "edit renders the verification step while the registration session is valid" do
    post base_app_identity_emails_registration_url(ri: "jp", host: @host),
         params: { user_email: { raw_address: "app_email_reg_edit@example.com" } }, headers: @headers

    get edit_base_app_identity_emails_registration_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
  end

  test "update rejects the verification when the stealth Turnstile check fails" do
    post base_app_identity_emails_registration_url(ri: "jp", host: @host),
         params: { user_email: { raw_address: "app_email_reg_turnstile@example.com" } }, headers: @headers
    pending = ClientEmail.find_by!(public_id: session[:email_registration_public_id])
    TurnstileVerifierStub.challenge_response = { "success" => false }

    patch base_app_identity_emails_registration_url(ri: "jp", host: @host),
          params: { user_email: { pass_code: "123456" } }, headers: @headers

    assert_response :unprocessable_content
    assert_equal ClientEmailStatus::UNVERIFIED, pending.reload.user_email_status_id
  end

  test "update rejects a blank verification code before consuming an OTP attempt" do
    post base_app_identity_emails_registration_url(ri: "jp", host: @host),
         params: { user_email: { raw_address: "app_email_reg_blank@example.com" } }, headers: @headers
    pending = ClientEmail.find_by!(public_id: session[:email_registration_public_id])
    attempts_before = pending.otp_attempts_count

    patch base_app_identity_emails_registration_url(ri: "jp", host: @host),
          params: { user_email: { pass_code: "" } }, headers: @headers

    assert_response :unprocessable_content
    assert_equal attempts_before, pending.reload.otp_attempts_count
  end

  test "update re-renders the verification step when the submitted code is wrong" do
    post base_app_identity_emails_registration_url(ri: "jp", host: @host),
         params: { user_email: { raw_address: "app_email_reg_wrong@example.com" } }, headers: @headers
    pending = ClientEmail.find_by!(public_id: session[:email_registration_public_id])
    otp = pending.get_otp
    wrong_code = ROTP::HOTP.new(otp[:otp_private_key]).at(otp[:otp_counter] + 1).to_s

    patch base_app_identity_emails_registration_url(ri: "jp", host: @host),
          params: { user_email: { pass_code: wrong_code } }, headers: @headers

    assert_response :unprocessable_content
    assert_equal ClientEmailStatus::UNVERIFIED, pending.reload.user_email_status_id
  end

  test "update abandons the registration once the attempt limit is exceeded" do
    post base_app_identity_emails_registration_url(ri: "jp", host: @host),
         params: { user_email: { raw_address: "app_email_reg_locked@example.com" } }, headers: @headers
    pending = ClientEmail.find_by!(public_id: session[:email_registration_public_id])
    otp = pending.get_otp
    wrong_code = ROTP::HOTP.new(otp[:otp_private_key]).at(otp[:otp_counter] + 1).to_s

    OtpLockable::MAX_OTP_ATTEMPTS.times do
      patch base_app_identity_emails_registration_url(ri: "jp", host: @host),
            params: { user_email: { pass_code: wrong_code } }, headers: @headers
    end

    assert_response :redirect
    assert_match %r{/identity/emails/registration/new}, response.location
    assert_nil session[:email_registration_public_id]
  end

  test "update verifies the address and returns to the identity page on the correct code" do
    post base_app_identity_emails_registration_url(ri: "jp", host: @host),
         params: { user_email: { raw_address: "app_email_reg_verified@example.com" } }, headers: @headers
    pending = ClientEmail.find_by!(public_id: session[:email_registration_public_id])
    otp = pending.get_otp
    code = ROTP::HOTP.new(otp[:otp_private_key]).at(otp[:otp_counter]).to_s

    patch base_app_identity_emails_registration_url(ri: "jp", host: @host),
          params: { user_email: { pass_code: code } }, headers: @headers

    assert_response :redirect
    assert_equal ClientEmailStatus::VERIFIED, pending.reload.user_email_status_id
    assert_nil session[:email_registration_public_id]
  end

  test "redelivery issues a new passcode for the pending registration" do
    post base_app_identity_emails_registration_url(ri: "jp", host: @host),
         params: { user_email: { raw_address: "app_email_reg_resend@example.com" } }, headers: @headers
    pending = ClientEmail.find_by!(public_id: session[:email_registration_public_id])
    first_counter = pending.otp_counter

    travel 5.minutes do
      post base_app_identity_emails_registration_redelivery_url(ri: "jp", host: @host), headers: @headers
    end

    assert_response :redirect
    assert_not_equal first_counter, pending.reload.otp_counter
  end

  test "redelivery inside the cooldown window does not reissue the passcode" do
    post base_app_identity_emails_registration_url(ri: "jp", host: @host),
         params: { user_email: { raw_address: "app_email_reg_cooldown@example.com" } }, headers: @headers
    pending = ClientEmail.find_by!(public_id: session[:email_registration_public_id])
    first_counter = pending.otp_counter

    post base_app_identity_emails_registration_redelivery_url(ri: "jp", host: @host), headers: @headers

    assert_response :redirect
    assert_equal first_counter, pending.reload.otp_counter
  end

  test "redelivery without a pending registration returns to the registration form" do
    post base_app_identity_emails_registration_redelivery_url(ri: "jp", host: @host), headers: @headers

    assert_response :redirect
    assert_match %r{/identity/emails/registration/new}, response.location
  end
end
