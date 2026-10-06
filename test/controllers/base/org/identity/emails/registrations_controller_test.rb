# typed: false
# frozen_string_literal: true

require "test_helper"

# Registration ceremony for attaching an email address to an operator on the
# staff surface: the two-step OTP flow plus the Turnstile, invalid-address,
# missing-code, wrong-code, lock-out, and expired-session branches guarding it.
class Base::Org::Identity::Emails::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses, :operator_email_statuses,
           :operator_token_kinds, :operator_token_statuses, :operator_token_binding_methods,
           :operator_token_dbsc_statuses, :operator_passkeys

  setup do
    https!
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! @host
    @operator = operators(:one)
    @token = OperatorToken.create!(
      staff: @operator,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: @token)
    install_base_browser_rp_credentials!(surface: "org", host: @host, actor: @operator, token: @token)
    passkey = @operator.operator_passkeys.first!
    passkey.update!(uv_verified_at: Time.current)
    _verification, raw_verification = OperatorVerification.issue_for_token!(token: @token)
    cookies[OperatorVerification.cookie_name] = raw_verification
    @token.update!(
      last_step_up_at: Time.current,
      last_step_up_scope: "settings_email",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
      last_step_up_credential_ref: passkey.external_id,
      last_step_up_phishing_resistant: true,
      last_step_up_user_verified: true,
      last_step_up_full_reauthentication: false,
    )
    access_token = AuthenticationToken.encode(
      @operator, host: @host, session_public_id: @token.public_id,
                 resource_type: "operator", jwt_issuer_id: "surface:BASE_ORG",
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

  test "new renders the registration form and leaves no pending registration in the session" do
    get new_base_org_identity_emails_registration_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
    assert_nil session[:staff_email_registration_public_id]
  end

  test "edit redirects back to new when no registration is in progress" do
    get edit_base_org_identity_emails_registration_url(ri: "jp", host: @host), headers: @headers

    assert_redirected_to new_base_org_identity_emails_registration_path(ri: "jp")
  end

  test "create rejects the submission when the stealth Turnstile check fails" do
    TurnstileVerifierStub.challenge_response = { "success" => false }

    assert_no_difference("OperatorEmail.count") do
      post base_org_identity_emails_registration_url(ri: "jp", host: @host),
           params: { staff_email: { raw_address: "org_reg_turnstile@example.com" } }, headers: @headers
    end

    assert_response :unprocessable_content
    assert_nil session[:staff_email_registration_public_id]
  end

  test "create rejects an address that fails model validation" do
    assert_no_difference("OperatorEmail.count") do
      post base_org_identity_emails_registration_url(ri: "jp", host: @host),
           params: { staff_email: { raw_address: "not-an-email" } }, headers: @headers
    end

    assert_response :unprocessable_content
    assert_nil session[:staff_email_registration_public_id]
  end

  test "create stores the pending registration and moves the ceremony to the verification step" do
    assert_difference("OperatorEmail.count", 1) do
      post base_org_identity_emails_registration_url(ri: "jp", host: @host),
           params: { staff_email: { raw_address: "org_reg_created@example.com", notifiable: "1" } },
           headers: @headers
    end

    assert_redirected_to edit_base_org_identity_emails_registration_path(ri: "jp")
    registered = OperatorEmail.find_by!(public_id: session[:staff_email_registration_public_id])

    assert_equal @operator.id, registered.staff_id
    assert_equal OperatorEmailStatus::UNVERIFIED, registered.staff_email_status_id
  end

  test "edit renders the verification step while the registration session is valid" do
    post base_org_identity_emails_registration_url(ri: "jp", host: @host),
         params: { staff_email: { raw_address: "org_reg_edit@example.com" } }, headers: @headers

    get edit_base_org_identity_emails_registration_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
  end

  test "update redirects back to new when the session holds no pending registration" do
    patch base_org_identity_emails_registration_url(ri: "jp", host: @host),
          params: { staff_email: { pass_code: "123456" } }, headers: @headers

    assert_redirected_to new_base_org_identity_emails_registration_path(ri: "jp")
  end

  test "update rejects the verification when the stealth Turnstile check fails" do
    post base_org_identity_emails_registration_url(ri: "jp", host: @host),
         params: { staff_email: { raw_address: "org_reg_update_turnstile@example.com" } }, headers: @headers
    pending = OperatorEmail.find_by!(public_id: session[:staff_email_registration_public_id])
    TurnstileVerifierStub.challenge_response = { "success" => false }

    patch base_org_identity_emails_registration_url(ri: "jp", host: @host),
          params: { staff_email: { pass_code: "123456" } }, headers: @headers

    assert_response :unprocessable_content
    assert_equal OperatorEmailStatus::UNVERIFIED, pending.reload.staff_email_status_id
  end

  test "update rejects a blank verification code before consuming an OTP attempt" do
    post base_org_identity_emails_registration_url(ri: "jp", host: @host),
         params: { staff_email: { raw_address: "org_reg_blank_code@example.com" } }, headers: @headers
    pending = OperatorEmail.find_by!(public_id: session[:staff_email_registration_public_id])
    attempts_before = pending.otp_attempts_count

    patch base_org_identity_emails_registration_url(ri: "jp", host: @host),
          params: { staff_email: { pass_code: "" } }, headers: @headers

    assert_response :unprocessable_content
    assert_equal attempts_before, pending.reload.otp_attempts_count
  end

  test "update re-renders the verification step when the submitted code is wrong" do
    post base_org_identity_emails_registration_url(ri: "jp", host: @host),
         params: { staff_email: { raw_address: "org_reg_wrong_code@example.com" } }, headers: @headers
    pending = OperatorEmail.find_by!(public_id: session[:staff_email_registration_public_id])
    otp = pending.get_otp
    wrong_code = ROTP::HOTP.new(otp[:otp_private_key]).at(otp[:otp_counter] + 1).to_s

    patch base_org_identity_emails_registration_url(ri: "jp", host: @host),
          params: { staff_email: { pass_code: wrong_code } }, headers: @headers

    assert_response :unprocessable_content
    assert_equal OperatorEmailStatus::UNVERIFIED, pending.reload.staff_email_status_id
  end

  test "update discards the pending registration once the attempt limit locks it" do
    post base_org_identity_emails_registration_url(ri: "jp", host: @host),
         params: { staff_email: { raw_address: "org_reg_locked@example.com" } }, headers: @headers
    pending_public_id = session[:staff_email_registration_public_id]
    pending = OperatorEmail.find_by!(public_id: pending_public_id)
    otp = pending.get_otp
    wrong_code = ROTP::HOTP.new(otp[:otp_private_key]).at(otp[:otp_counter] + 1).to_s

    OtpLockable::MAX_OTP_ATTEMPTS.times do
      patch base_org_identity_emails_registration_url(ri: "jp", host: @host),
            params: { staff_email: { pass_code: wrong_code } }, headers: @headers
    end

    assert_redirected_to new_base_org_identity_emails_registration_path(ri: "jp")
    assert_nil OperatorEmail.find_by(public_id: pending_public_id)
  end

  test "update verifies the address and returns to the identity page on the correct code" do
    post base_org_identity_emails_registration_url(ri: "jp", host: @host),
         params: { staff_email: { raw_address: "org_reg_verified@example.com" } }, headers: @headers
    pending = OperatorEmail.find_by!(public_id: session[:staff_email_registration_public_id])
    otp = pending.get_otp
    code = ROTP::HOTP.new(otp[:otp_private_key]).at(otp[:otp_counter]).to_s

    patch base_org_identity_emails_registration_url(ri: "jp", host: @host),
          params: { staff_email: { pass_code: code } }, headers: @headers

    assert_redirected_to base_org_identity_emails_url(ri: "jp", host: @host)
    assert_nil session[:staff_email_registration_public_id]
  end

  test "update treats an expired one-time passcode as an expired registration session" do
    post base_org_identity_emails_registration_url(ri: "jp", host: @host),
         params: { staff_email: { raw_address: "org_reg_expired@example.com" } }, headers: @headers
    OperatorEmail.find_by!(public_id: session[:staff_email_registration_public_id])
      .update!(otp_expires_at: 1.minute.ago)

    patch base_org_identity_emails_registration_url(ri: "jp", host: @host),
          params: { staff_email: { pass_code: "123456" } }, headers: @headers

    assert_redirected_to new_base_org_identity_emails_registration_path(ri: "jp")
  end
end
