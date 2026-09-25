# typed: false
# frozen_string_literal: true

require "test_helper"

# The resend and cancel endpoints on the sign-up checkpoints. Every checkpoint
# controller routes DELETE to `cancel_from_explicit_step`, and the OTP
# checkpoints additionally route POST to a resend; neither is reachable from the
# happy path, so they are asserted here for the app and corporate surfaces.
class AuthSignUpCheckpointCancellationTest < ActionDispatch::IntegrationTest
  setup do
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    Prosopite.pause do
      [1, 2, 3].each { |id| VisitorStatus.find_or_create_by!(id: id) }
      [0, 1, 2, 3].each { |id| VisitorVisibility.find_or_create_by!(id: id) }
      VisitorEmailStatus::DEFAULTS.each { |id| VisitorEmailStatus.find_or_create_by!(id: id) }
    end
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "app email OTP checkpoint reissues the passcode on resend" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    cookies["csrf_token"] = "test-csrf-token"
    headers = { "Host" => host, "X-CSRF-Token" => "test-csrf-token" }
    post auth_app_sign_up_email_url(ri: "jp", host: host),
         params: {
           user_email: { raw_address: "checkpoint_resend_app@example.com", confirm_policy: "1" },
           "cf-turnstile-response": "test",
         }, headers: headers
    registered = ClientEmail.order(:created_at).last
    first_sent_at = registered.otp_last_sent_at

    decision_time = ClientEmail.database_now + 5.minutes
    ClientEmail.stub(:database_now, decision_time) do
      travel 5.minutes do
        post auth_app_sign_up_check_email_otp_url(ri: "jp", host: host), headers: headers
      end
    end

    assert_response :redirect
    assert_not_equal first_sent_at, registered.reload.otp_last_sent_at
  end

  test "app email OTP checkpoint cancels the sign-up ceremony on delete" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    cookies["csrf_token"] = "test-csrf-token"
    headers = { "Host" => host, "X-CSRF-Token" => "test-csrf-token" }
    post auth_app_sign_up_email_url(ri: "jp", host: host),
         params: {
           user_email: { raw_address: "checkpoint_cancel_app@example.com", confirm_policy: "1" },
           "cf-turnstile-response": "test",
         }, headers: headers

    delete auth_app_sign_up_check_email_otp_url(ri: "jp", host: host), headers: headers

    assert_response :redirect
    assert_nil session[:auth_app_up_sequence_id]
  end

  test "com email OTP checkpoint cancels the sign-up ceremony on delete" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    host! host
    cookies["csrf_token"] = "test-csrf-token"
    headers = { "Host" => host, "X-CSRF-Token" => "test-csrf-token" }
    post auth_com_sign_up_email_url(ri: "jp", host: host),
         params: {
           visitor_email: { raw_address: "checkpoint_cancel_com@example.com", confirm_policy: "1" },
           "cf-turnstile-response": "test",
         }, headers: headers

    delete auth_com_sign_up_check_email_otp_url(ri: "jp", host: host), headers: headers

    assert_response :redirect
    assert_nil session[:auth_com_up_sequence_id]
  end

  test "com email OTP checkpoint reissues the passcode on resend" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    host! host
    cookies["csrf_token"] = "test-csrf-token"
    headers = { "Host" => host, "X-CSRF-Token" => "test-csrf-token" }
    post auth_com_sign_up_email_url(ri: "jp", host: host),
         params: {
           visitor_email: { raw_address: "checkpoint_resend_com@example.com", confirm_policy: "1" },
           "cf-turnstile-response": "test",
         }, headers: headers
    registered = VisitorEmail.order(:created_at).last
    first_sent_at = registered.otp_last_sent_at

    decision_time = VisitorEmail.database_now + 5.minutes
    VisitorEmail.stub(:database_now, decision_time) do
      travel 5.minutes do
        post auth_com_sign_up_check_email_otp_url(ri: "jp", host: host), headers: headers
      end
    end

    assert_response :redirect
    assert_not_equal first_sent_at, registered.reload.otp_last_sent_at
  end

  test "app telephone OTP checkpoint cancels the sign-up ceremony on delete" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    cookies["csrf_token"] = "test-csrf-token"
    headers = { "Host" => host, "X-CSRF-Token" => "test-csrf-token" }
    post auth_app_sign_up_telephone_url(ri: "jp", host: host),
         params: {
           user_telephone: { raw_number: "+819012340101", confirm_policy: "1", confirm_using_mfa: "1" },
           "cf-turnstile-response": "test",
         }, headers: headers

    delete auth_app_sign_up_check_telephone_otp_url(ri: "jp", host: host), headers: headers

    assert_response :redirect
    assert_nil session[:auth_app_up_sequence_id]
  end

  test "com telephone passkey checkpoint cancels the sign-up ceremony on delete" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    host! host
    cookies["csrf_token"] = "test-csrf-token"
    headers = { "Host" => host, "X-CSRF-Token" => "test-csrf-token" }
    post auth_com_sign_up_telephone_url(ri: "jp", host: host),
         params: {
           visitor_telephone: { raw_number: "+819012340102", confirm_policy: "1", confirm_using_mfa: "1" },
           "cf-turnstile-response": "test",
         }, headers: headers
    telephone = VisitorTelephone.order(:created_at).last
    otp = telephone.get_otp
    patch auth_com_sign_up_check_telephone_otp_url(ri: "jp", host: host),
          params: {
            visitor_telephone: { pass_code: ROTP::HOTP.new(otp[:otp_private_key]).at(otp[:otp_counter]) },
          }, headers: headers
    get auth_com_sign_up_guard_telephone_url(ri: "jp", host: host), headers: headers

    delete auth_com_sign_up_check_telephone_passkey_url(ri: "jp", host: host), headers: headers

    assert_response :redirect
    assert_nil session[:auth_com_up_sequence_id]
  end

  test "app telephone passkey checkpoint cancels the sign-up ceremony on delete" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    cookies["csrf_token"] = "test-csrf-token"
    headers = { "Host" => host, "X-CSRF-Token" => "test-csrf-token" }
    post auth_app_sign_up_telephone_url(ri: "jp", host: host),
         params: {
           user_telephone: { raw_number: "+819012340111", confirm_policy: "1", confirm_using_mfa: "1" },
           "cf-turnstile-response": "test",
         }, headers: headers
    registration = session[:user_telephone_registration] || {}
    telephone = ClientTelephone.find_by!(public_id: registration[:public_id] || registration["public_id"])
    otp = telephone.get_otp
    patch auth_app_sign_up_check_telephone_otp_url(ri: "jp", host: host),
          params: {
            user_telephone: { pass_code: ROTP::HOTP.new(otp[:otp_private_key]).at(otp[:otp_counter]) },
          }, headers: headers
    get auth_app_sign_up_guard_telephone_url(ri: "jp", host: host), headers: headers

    delete auth_app_sign_up_check_telephone_passkey_url(ri: "jp", host: host), headers: headers

    assert_response :redirect
    assert_nil session[:auth_app_up_sequence_id]
  end
end
