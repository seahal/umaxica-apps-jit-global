# typed: false
# frozen_string_literal: true

require "test_helper"

# Registration ceremony for attaching a telephone number to a visitor on the
# corporate surface: the two-step OTP flow plus the Turnstile, missing-code,
# wrong-code, lock-out, and expired-session branches guarding it.
class Base::Com::Identity::Telephones::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :visitors, :visitor_statuses, :visitor_telephone_statuses,
           :visitor_token_kinds, :visitor_token_statuses, :visitor_token_binding_methods,
           :visitor_token_dbsc_statuses

  setup do
    @host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! @host
    @visitor = visitors(:reserved_visitor)
    @token = VisitorToken.create!(
      visitor: @visitor,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :com, principal: @visitor)
    BaseSelectorAuthority.prepare(surface: :com, principal: @visitor, session: @token)
    _verification, raw_verification = VisitorVerification.issue_for_token!(token: @token)
    cookies[VisitorVerification.cookie_name] = raw_verification
    @token.update!(
      last_step_up_at: Time.current,
      last_step_up_scope: "settings_telephone",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:com",
    )
    access_token = AuthenticationToken.encode(
      @visitor, host: @host, session_public_id: @token.public_id,
                resource_type: "visitor", jwt_issuer_id: "surface:BASE_COM",
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
    get new_base_com_identity_telephones_registration_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
    assert_nil session[:settings_telephone_registration_id]
  end

  test "edit redirects back to new when no registration is in progress" do
    get edit_base_com_identity_telephones_registration_url(ri: "jp", host: @host), headers: @headers

    assert_redirected_to new_base_com_identity_telephones_registration_path(ri: "jp")
  end

  test "create rejects the submission when the stealth Turnstile check fails" do
    TurnstileVerifierStub.challenge_response = { "success" => false }

    assert_no_difference("VisitorTelephone.count") do
      post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
           params: { user_telephone: { raw_number: "+15558675331" } }, headers: @headers
    end

    assert_response :unprocessable_content
    assert_nil session[:settings_telephone_registration_id]
  end

  test "create rejects a number that cannot be normalized to E.164" do
    assert_no_difference("VisitorTelephone.count") do
      post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
           params: { user_telephone: { raw_number: "not-a-number" } }, headers: @headers
    end

    assert_response :unprocessable_content
    assert_nil session[:settings_telephone_registration_id]
  end

  test "create stores the pending registration and moves the ceremony to the verification step" do
    assert_difference("VisitorTelephone.count", 1) do
      post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
           params: { user_telephone: { raw_number: "+15558675332" } }, headers: @headers
    end

    assert_redirected_to edit_base_com_identity_telephones_registration_path(ri: "jp")
    registered = VisitorTelephone.find(session[:settings_telephone_registration_id])

    assert_equal @visitor.id, registered.visitor_id
    assert_equal VisitorTelephoneStatus::UNVERIFIED, registered.visitor_telephone_status_id
  end

  test "edit renders the verification step while the registration session is valid" do
    post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: "+15558675333" } }, headers: @headers

    get edit_base_com_identity_telephones_registration_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
  end

  test "update redirects back to new when the session holds no pending registration" do
    patch base_com_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { user_telephone: { pass_code: "123456" } }, headers: @headers

    assert_redirected_to new_base_com_identity_telephones_registration_path(ri: "jp")
  end

  test "update rejects the verification when the stealth Turnstile check fails" do
    post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: "+15558675334" } }, headers: @headers
    pending = VisitorTelephone.find(session[:settings_telephone_registration_id])
    TurnstileVerifierStub.challenge_response = { "success" => false }

    patch base_com_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { user_telephone: { pass_code: "123456" } }, headers: @headers

    assert_response :unprocessable_content
    assert_equal VisitorTelephoneStatus::UNVERIFIED, pending.reload.visitor_telephone_status_id
  end

  test "update rejects a blank verification code before consuming an OTP attempt" do
    post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: "+15558675335" } }, headers: @headers
    pending = VisitorTelephone.find(session[:settings_telephone_registration_id])
    attempts_before = pending.otp_attempts_count

    patch base_com_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { user_telephone: { pass_code: "" } }, headers: @headers

    assert_response :unprocessable_content
    assert_equal attempts_before, pending.reload.otp_attempts_count
  end

  test "update re-renders the verification step when the submitted code is wrong" do
    post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: "+15558675336" } }, headers: @headers
    pending = VisitorTelephone.find(session[:settings_telephone_registration_id])
    otp = pending.get_otp
    wrong_code = ROTP::HOTP.new(otp[:otp_private_key]).at(otp[:otp_counter] + 1).to_s

    patch base_com_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { user_telephone: { pass_code: wrong_code } }, headers: @headers

    assert_response :unprocessable_content
    assert_equal VisitorTelephoneStatus::UNVERIFIED, pending.reload.visitor_telephone_status_id
  end

  test "update discards the pending registration once the attempt limit locks it" do
    post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: "+15558675337" } }, headers: @headers
    pending_id = session[:settings_telephone_registration_id]
    pending = VisitorTelephone.find(pending_id)
    otp = pending.get_otp
    wrong_code = ROTP::HOTP.new(otp[:otp_private_key]).at(otp[:otp_counter] + 1).to_s

    OtpLockable::MAX_OTP_ATTEMPTS.times do
      patch base_com_identity_telephones_registration_url(ri: "jp", host: @host),
            params: { user_telephone: { pass_code: wrong_code } }, headers: @headers
    end

    assert_redirected_to new_base_com_identity_telephones_registration_path(ri: "jp")
    assert_nil VisitorTelephone.find_by(id: pending_id)
  end

  test "update verifies the telephone number and returns to the identity page on the correct code" do
    post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: "+15558675338" } }, headers: @headers
    pending = VisitorTelephone.find(session[:settings_telephone_registration_id])
    otp = pending.get_otp
    code = ROTP::HOTP.new(otp[:otp_private_key]).at(otp[:otp_counter]).to_s

    patch base_com_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { user_telephone: { pass_code: code } }, headers: @headers

    assert_redirected_to base_com_identity_telephones_url(ri: "jp", host: @host)
    assert_nil session[:settings_telephone_registration_id]
  end

  test "update treats an expired one-time passcode as an expired registration session" do
    post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: "+15558675339" } }, headers: @headers
    VisitorTelephone.find(session[:settings_telephone_registration_id]).update!(otp_expires_at: 1.minute.ago)

    patch base_com_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { user_telephone: { pass_code: "123456" } }, headers: @headers

    assert_redirected_to new_base_com_identity_telephones_registration_path(ri: "jp")
  end
end
