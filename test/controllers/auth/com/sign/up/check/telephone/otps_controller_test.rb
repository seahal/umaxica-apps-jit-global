# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Com::Sign::Up::Check::Telephone::OtpsControllerTest < ActionDispatch::IntegrationTest
  counts_rate_limits!
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")
    host! @host
    cookies["csrf_token"] = csrf_token_value
    Rails.configuration.x.rate_limit.fetch(:store).clear
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }

    Prosopite.pause do
      [VisitorStatus::NOTHING, VisitorStatus::ACTIVE].each { |id| VisitorStatus.find_or_create_by!(id: id) }
      VisitorVisibility::DEFAULTS.each { |id| VisitorVisibility.find_or_create_by!(id: id) }
      [
        VisitorTelephoneStatus::UNVERIFIED,
        VisitorTelephoneStatus::VERIFIED,
        VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
        VisitorTelephoneStatus::VERIFIED_WITH_SIGN_UP,
      ].each { |id| VisitorTelephoneStatus.find_or_create_by!(id: id) }
      VisitorTokenDbscStatus.ensure_defaults!
      VisitorTokenStatus::DEFAULTS.each { |id| VisitorTokenStatus.find_or_create_by!(id: id) }
    end
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  test "show renders the OTP code entry page for a valid telephone session" do
    start_telephone_signup!("+819011110001")

    get auth_com_sign_up_check_telephone_otp_url(ri: "jp"), headers: default_headers

    assert_response :success
    assert_equal "auth/com/sign/up/telephones/edit", inertia_component
    assert_equal I18n.t("sign.app.registration.telephone.edit.page_title"), inertia_props.fetch("title")
  end

  test "show returns to the start when there is no sign-up flow at all" do
    get auth_com_sign_up_check_telephone_otp_url(ri: "jp"), headers: default_headers

    assert_redirected_to auth_com_sign_up_url(ri: "jp")
  end

  test "show renders session expired when the OTP has expired" do
    telephone = start_telephone_signup!("+819011110002")
    telephone.update!(otp_expires_at: 1.minute.ago)

    get auth_com_sign_up_check_telephone_otp_url(ri: "jp"), headers: default_headers

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.com.registration.telephone.edit.session_expired")
  end

  test "create resends an OTP and redirects back to the OTP page" do
    start_telephone_signup!("+819011110003")

    assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
      post auth_com_sign_up_check_telephone_otp_url(ri: "jp"), headers: default_headers
    end

    assert_redirected_to auth_com_sign_up_check_telephone_otp_url(ri: "jp")
    assert_predicate session[:visitor_telephone_otp_last_sent_at], :present?
  end

  test "create is rate limited when resending too soon" do
    start_telephone_signup!("+819011110004")

    post auth_com_sign_up_check_telephone_otp_url(ri: "jp"), headers: default_headers

    assert_response :redirect

    assert_enqueued_jobs 0, only: Outbound::SmsDeliveryJob do
      post auth_com_sign_up_check_telephone_otp_url(ri: "jp"), headers: default_headers
    end

    assert_response :too_many_requests
    assert_includes response.body, I18n.t("sign.app.registration.email.create.otp_resend_too_soon")
  end

  test "update with a valid OTP advances to the guard page" do
    telephone = start_telephone_signup!("+819011110005")

    patch auth_com_sign_up_check_telephone_otp_url(ri: "jp"),
          params: { visitor_telephone: { pass_code: otp_code_for(telephone) } },
          headers: default_headers

    assert_redirected_to auth_com_sign_up_guard_telephone_url(ri: "jp")

    cycle = current_sign_up_flow

    assert_equal VisitorSignUpFlowStatus::CHECKPOINT_PENDING, cycle.status_id
    assert cycle.requirement_cleared?(:otp)
    assert_predicate session[:visitor_telephone_registration]["otp_verified"], :present?
  end

  test "update with a blank OTP returns a validation error" do
    start_telephone_signup!("+819011110006")

    patch auth_com_sign_up_check_telephone_otp_url(ri: "jp"),
          params: { visitor_telephone: { pass_code: "" } },
          headers: default_headers

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.telephone.update.code_required")
  end

  test "update with an invalid OTP keeps the ticket at contact pending" do
    start_telephone_signup!("+819011110007")

    patch auth_com_sign_up_check_telephone_otp_url(ri: "jp"),
          params: { visitor_telephone: { pass_code: "000000" } },
          headers: default_headers

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.telephone.update.invalid_code")

    cycle = current_sign_up_flow

    assert_equal VisitorSignUpFlowStatus::CONTACT_PENDING, cycle.status_id
    assert_not cycle.requirement_cleared?(:otp)
  end

  test "update with repeated invalid OTP attempts locks the flow" do
    telephone = start_telephone_signup!("+819011110008")
    cycle = current_sign_up_flow

    Telephone::MAX_OTP_ATTEMPTS.times do
      patch auth_com_sign_up_check_telephone_otp_url(ri: "jp"),
            params: { visitor_telephone: { pass_code: "000000" } },
            headers: default_headers
    end

    assert_response :too_many_requests
    assert_includes response.body, I18n.t("sign.app.registration.telephone.update.attempts_exceeded")
    assert_predicate telephone.reload, :locked?
    assert_nil session[:visitor_telephone_registration]
    assert_nil cycle.reload.completed_requirements["otp"]
  end

  test "destroy cancels the sign-up flow and returns to the start" do
    start_telephone_signup!("+819011110009")
    cycle = current_sign_up_flow

    # Cancellation terminates and discards the cycle; SignUpTermination schedules
    # the physical purge later, so the row is still present right after the request.
    assert_no_difference("VisitorSignUpFlow.count") do
      delete auth_com_sign_up_check_telephone_otp_url(ri: "jp"), headers: default_headers
    end

    assert_redirected_to auth_com_sign_up_url(ri: "jp")
    assert_equal VisitorSignUpFlowStatus::CANCELLED, cycle.reload.status_id
    assert_operator cycle.discarded_at, :<=, Time.current
    assert_nil session[:com_sign_up_flow_locator]
  end

  private

  def start_telephone_signup!(raw_number)
    post(
      auth_com_sign_up_telephone_url(ri: "jp"),
      params: {
        visitor_telephone: {
          raw_number: raw_number,
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      },
      headers: default_headers,
    )

    assert_response :redirect
    VisitorTelephone.order(:created_at).last
  end

  def current_sign_up_flow
    public_id = session.dig(:com_sign_up_flow_locator, "public_id")
    return if public_id.blank?

    VisitorSignUpFlow.find_by(public_id: public_id)
  end

  def otp_code_for(telephone)
    otp_data = telephone.get_otp
    ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s
  end

  def default_headers
    { "Host" => @host, "HTTPS" => "on", "X-CSRF-Token" => csrf_token_value }
  end

  def csrf_token_value
    "test-csrf-token"
  end
end
