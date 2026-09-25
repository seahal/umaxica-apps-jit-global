# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Com::Sign::Up::Check::Email::BirthdatesControllerTest < ActionDispatch::IntegrationTest
  # Rate-limit counters are a NullStore by default in test so unrelated tests
  # cannot accumulate them; this file asserts real limiting behavior, so it
  # opts into a deterministic MemoryStore.
  rate_limit_counters!

  include ActiveSupport::Testing::TimeHelpers

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")
    host! @host
    VisitorSecretCredentialKind.ensure_defaults!
    VisitorSecretCredentialStatus.ensure_defaults!
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

  # Regression: com sign-up must reach finalization. The com finalizer and the
  # com recovery-passcode reveal URL are only exercised from here.
  test "clearing the birthdate completes the com sign-up" do
    advance_to_birthdate_checkpoint!("com-birthdate-finalize@example.com")
    flow = VisitorSignUpFlow.order(:created_at).last

    assert_equal VisitorSignUpFlowStatus::CHECKPOINT_PENDING, flow.status_id
    assert_predicate flow.principal_id, :present?

    patch auth_com_sign_up_check_email_birthdate_url(ri: "jp"),
          params: {
            requirement: "birthdate",
            checkpoint_version: flow.checkpoint_version,
            birthdate_year: "1990",
            birthdate_month: "01",
            birthdate_day: "15",
          },
          headers: default_headers

    assert_response :redirect
    assert_equal VisitorSignUpFlowStatus::COMPLETED, flow.reload.status_id
    assert flow.requirement_cleared?(:birthdate)
  end

  test "an underage birthdate terminalizes the com sign-up" do
    travel_to Time.zone.local(2026, 6, 25, 12, 0, 0) do
      advance_to_birthdate_checkpoint!("com-birthdate-underage@example.com")
      flow = VisitorSignUpFlow.order(:created_at).last

      patch auth_com_sign_up_check_email_birthdate_url(ri: "jp"),
            params: {
              requirement: "birthdate",
              checkpoint_version: flow.checkpoint_version,
              birthdate: "2024-06-26",
            },
            headers: default_headers

      assert_response :success
      assert_includes response.body, I18n.t("sign.com.registration.checkpoint.age_restricted")
      assert_equal VisitorSignUpFlowStatus::FAILED, flow.reload.status_id
      assert_not flow.requirement_cleared?(:birthdate)
    end
  end

  private

  def advance_to_birthdate_checkpoint!(address)
    post(
      auth_com_sign_up_email_url(ri: "jp"),
      params: {
        visitor_email: { raw_address: address, confirm_policy: "1" },
        "cf-turnstile-response": "test",
      },
      headers: default_headers,
    )

    assert_response :redirect

    visitor_email = VisitorEmail.where(address_digest: IdentifierBlindIndex.bidx_for_email(address))
      .order(:created_at).last

    patch(
      auth_com_sign_up_check_email_otp_url(ri: "jp"),
      params: { visitor_email: { pass_code: otp_code_for(visitor_email) } },
      headers: default_headers,
    )

    assert_response :redirect

    visitor_email
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
