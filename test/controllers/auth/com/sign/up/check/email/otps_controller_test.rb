# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Com::Sign::Up::Check::Email::OtpsControllerTest < ActionDispatch::IntegrationTest
  counts_rate_limits!
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")
    host! @host
    cookies["csrf_token"] = csrf_token_value
    Rails.configuration.x.rate_limit.fetch(:store).clear
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  test "patch with a valid otp advances to the birthdate checkpoint" do
    visitor_email = start_email_signup!("com-email-valid@example.com")
    cycle = current_sign_up_cycle

    assert_equal VisitorSignUpFlowStatus::CONTACT_PENDING, cycle.status_id
    assert_equal 0, cycle.checkpoint_version

    patch auth_com_sign_up_check_email_otp_url(ri: "jp"),
          params: { visitor_email: { pass_code: otp_code_for(visitor_email) } },
          headers: default_headers

    assert_response :redirect
    assert_redirected_to auth_com_sign_up_check_email_birthdate_url(ri: "jp")
    assert_equal VisitorEmailStatus::VERIFIED_WITH_SIGN_UP, visitor_email.reload.visitor_email_status_id
    assert_equal VisitorSignUpFlowStatus::CHECKPOINT_PENDING, cycle.reload.status_id
    assert_equal "checkpoint", cycle.step
    assert cycle.completed_requirements.dig("otp", "cleared")
    assert_predicate cycle.completed_requirements.dig("otp", "cleared_at"), :present?
  end

  test "clearing the otp requirement increments the checkpoint version" do
    visitor_email = start_email_signup!("com-email-version@example.com")
    cycle = current_sign_up_cycle

    patch auth_com_sign_up_check_email_otp_url(ri: "jp"),
          params: { visitor_email: { pass_code: otp_code_for(visitor_email) } },
          headers: default_headers

    # The requirement is cleared through the state machine rather than by
    # writing completed_requirements directly, so the stale-checkpoint guard
    # for every later step becomes effective from here on.
    assert_equal 1, cycle.reload.checkpoint_version
  end

  test "patch with a blank otp returns a validation error" do
    start_email_signup!("com-email-blank@example.com")

    patch auth_com_sign_up_check_email_otp_url(ri: "jp"),
          params: { visitor_email: { pass_code: "" } },
          headers: default_headers

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.email.update.code_required")
  end

  test "patch with an invalid otp leaves the ticket at contact pending" do
    start_email_signup!("com-email-wrong@example.com")
    cycle = current_sign_up_cycle

    patch auth_com_sign_up_check_email_otp_url(ri: "jp"),
          params: { visitor_email: { pass_code: "000000" } },
          headers: default_headers

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.email.update.invalid_code")
    assert_equal VisitorSignUpFlowStatus::CONTACT_PENDING, cycle.reload.status_id
    assert_nil cycle.completed_requirements["otp"]
    assert_equal 0, cycle.checkpoint_version
  end

  test "patch with repeated invalid otp attempts locks the flow" do
    visitor_email = start_email_signup!("com-email-lock@example.com")
    cycle = current_sign_up_cycle

    Email::MAX_OTP_ATTEMPTS.times do
      patch auth_com_sign_up_check_email_otp_url(ri: "jp"),
            params: { visitor_email: { pass_code: "000000" } },
            headers: default_headers
    end

    assert_response :too_many_requests
    assert_includes response.body, I18n.t("sign.app.registration.email.update.attempts_exceeded")
    assert_predicate visitor_email.reload, :locked?
    assert_nil cycle.reload.completed_requirements["otp"]
  end

  test "patch for an already registered address does not advance any ticket" do
    existing = create_verified_visitor_email!("com-email-existing@example.com")

    start_email_signup!("com-email-existing@example.com")

    assert_nil current_sign_up_cycle

    patch auth_com_sign_up_check_email_otp_url(ri: "jp"),
          params: { visitor_email: { pass_code: "000000" } },
          headers: default_headers

    # The decoy path must be indistinguishable from an ordinary wrong code.
    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.email.update.invalid_code")
    assert_equal VisitorEmailStatus::VERIFIED, existing.reload.visitor_email_status_id
    assert_empty VisitorSignUpFlow.where.not(status_id: VisitorSignUpFlowStatus::STARTED)
  end

  private

  def start_email_signup!(address)
    post(
      auth_com_sign_up_email_url(ri: "jp"),
      params: {
        visitor_email: { raw_address: address, confirm_policy: "1" },
        "cf-turnstile-response": "test",
      },
      headers: default_headers,
    )

    assert_response :redirect
    VisitorEmail.where(address_digest: IdentifierBlindIndex.bidx_for_email(address))
      .order(:created_at).last
  end

  def create_verified_visitor_email!(address)
    VisitorStatus.find_or_create_by!(id: VisitorStatus::ACTIVE)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    VisitorEmail.create!(
      visitor_id: visitor.id,
      address: address,
      address_digest: IdentifierBlindIndex.bidx_for_email(address),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
  end

  def current_sign_up_cycle
    public_id = session.dig(:com_sign_up_flow_locator, "public_id")
    return if public_id.blank?

    VisitorSignUpFlow.find_by(public_id: public_id)
  end

  def otp_code_for(visitor_email)
    otp_data = visitor_email.get_otp
    ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s
  end

  def default_headers
    { "Host" => @host, "HTTPS" => "on", "X-CSRF-Token" => csrf_token_value }
  end

  def csrf_token_value
    "test-csrf-token"
  end
end
