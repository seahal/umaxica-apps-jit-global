# typed: false
# frozen_string_literal: true

require "test_helper"

# Registration ceremony for attaching a telephone number to an existing app
# client: the two-step OTP flow (new -> create -> edit -> update) together with
# the Turnstile, registration-session, and OTP-failure branches guarding it.
class Base::App::Identity::Telephones::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_telephone_statuses,
           :client_token_kinds, :client_token_statuses, :client_token_binding_methods,
           :client_token_dbsc_statuses

  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    @user = clients(:one)
    @token = ClientToken.create!(
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)
    _verification, raw_verification = ClientVerification.issue_for_token!(token: @token)
    cookies[ClientVerification.cookie_name] = raw_verification
    @token.update!(
      last_step_up_at: Time.current,
      last_step_up_scope: "settings_telephone",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @token.public_id,
      last_step_up_purpose: "step_up",
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

  test "new renders the registration form and leaves no pending registration in the session" do
    get new_base_app_identity_telephones_registration_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
    assert_nil session[:settings_telephone_registration_id]
  end

  test "edit redirects back to new when no registration is in progress" do
    get edit_base_app_identity_telephones_registration_url(ri: "jp", host: @host), headers: @headers

    assert_redirected_to new_base_app_identity_telephones_registration_path(ri: "jp")
  end

  test "create rejects the submission when the stealth Turnstile check fails" do
    TurnstileVerifierStub.challenge_response = { "success" => false }

    assert_no_difference("ClientTelephone.count") do
      post base_app_identity_telephones_registration_url(ri: "jp", host: @host),
           params: { user_telephone: { raw_number: "+15558675311" } },
           headers: @headers
    end

    assert_response :unprocessable_content
    assert_nil session[:settings_telephone_registration_id]
  end

  test "create stores the pending registration and moves the ceremony to the verification step" do
    assert_difference("ClientTelephone.count", 1) do
      post base_app_identity_telephones_registration_url(ri: "jp", host: @host),
           params: { user_telephone: { raw_number: "+15558675312" } },
           headers: @headers
    end

    assert_redirected_to edit_base_app_identity_telephones_registration_path(ri: "jp")
    registered = ClientTelephone.find(session[:settings_telephone_registration_id])

    assert_equal @user.id, registered.user_id
    assert_equal ClientTelephoneStatus::UNVERIFIED, registered.user_telephone_status_id
  end

  test "edit renders the verification step while the registration session is valid" do
    post base_app_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: "+15558675313" } }, headers: @headers

    get edit_base_app_identity_telephones_registration_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
  end

  test "update redirects back to new when the session holds no pending registration" do
    patch base_app_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { user_telephone: { pass_code: "123456" } }, headers: @headers

    assert_redirected_to new_base_app_identity_telephones_registration_path(ri: "jp")
  end

  test "update rejects the verification when the stealth Turnstile check fails" do
    post base_app_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: "+15558675314" } }, headers: @headers
    pending = ClientTelephone.find(session[:settings_telephone_registration_id])
    TurnstileVerifierStub.challenge_response = { "success" => false }

    patch base_app_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { user_telephone: { pass_code: "123456" } }, headers: @headers

    assert_response :unprocessable_content
    assert_equal ClientTelephoneStatus::UNVERIFIED, pending.reload.user_telephone_status_id
  end

  test "update re-renders the verification step when the submitted code is wrong" do
    post base_app_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: "+15558675315" } }, headers: @headers
    pending = ClientTelephone.find(session[:settings_telephone_registration_id])
    otp = pending.get_otp
    wrong_code = ROTP::HOTP.new(otp[:otp_private_key]).at(otp[:otp_counter] + 1).to_s

    patch base_app_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { user_telephone: { pass_code: wrong_code } }, headers: @headers

    assert_response :unprocessable_content
    assert_equal ClientTelephoneStatus::UNVERIFIED, pending.reload.user_telephone_status_id
  end

  test "update verifies the telephone number and returns to the identity page on the correct code" do
    post base_app_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: "+15558675316" } }, headers: @headers
    pending = ClientTelephone.find(session[:settings_telephone_registration_id])
    otp = pending.get_otp
    code = ROTP::HOTP.new(otp[:otp_private_key]).at(otp[:otp_counter]).to_s

    patch base_app_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { user_telephone: { pass_code: code } }, headers: @headers

    assert_response :see_other
    assert_equal ClientTelephoneStatus::VERIFIED, pending.reload.user_telephone_status_id
    assert_nil session[:settings_telephone_registration_id]
  end

  test "update treats an expired one-time passcode as an expired registration session" do
    post base_app_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: "+15558675317" } }, headers: @headers
    ClientTelephone.find(session[:settings_telephone_registration_id]).update!(otp_expires_at: 1.minute.ago)

    patch base_app_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { user_telephone: { pass_code: "123456" } }, headers: @headers

    assert_redirected_to new_base_app_identity_telephones_registration_path(ri: "jp")
  end
end
