# frozen_string_literal: true

require "test_helper"

# D-135 / D-176: a new sign-up whose contact is still held by an unfinished registration is refused
# with a copy that says nothing about registration state, and nothing is created.
class SignUpContactHoldRefusalTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include SignInFlowCleanup
  include SignUpJourneyCleanup

  self.use_transactional_tests = false
  self.fixture_table_names = []

  setup do
    sign_up_journey_watermarks!
    @previous_challenge = [TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response]
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    https!
  end

  teardown do
    delete_sign_up_journey_rows!
    clear_enqueued_jobs
    TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response = @previous_challenge
  end

  test "APP email sign-up is refused while an unfinished registration holds the address" do
    admit!
    owner = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    held = ClientEmail.create!(
      user: owner, raw_address: "held-app-signup@example.com", confirm_policy: true,
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    held_facts = held.reload.attributes

    assert_no_difference(%w(Client.count ClientEmail.count)) do
      assert_no_enqueued_jobs(only: OtpNotifierEmailDeliveryJob) do
        post auth_app_sign_up_email_url(ri: "jp"),
             params: { client_email: { raw_address: held.address, confirm_policy: "1" },
                       "cf-turnstile-response": "test", },
             headers: headers
      end
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.email.create.contact_held")
    assert_equal held_facts, held.reload.attributes
    assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, owner.reload.status_id
  end

  test "APP email sign-up starts once cleanup has retired the held address" do
    admit!
    owner = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    ClientEmail.create!(
      user: owner, raw_address: "retired-app-signup@example.com", confirm_policy: true,
      user_email_status_id: ClientEmailStatus::DELETED,
    )

    assert_difference(%w(Client.count ClientEmail.count), 1) do
      post auth_app_sign_up_email_url(ri: "jp"),
           params: { client_email: { raw_address: "retired-app-signup@example.com", confirm_policy: "1" },
                     "cf-turnstile-response": "test", },
           headers: headers
    end

    assert_response :redirect
  end

  test "APP telephone sign-up is refused while an unfinished registration holds the number" do
    admit!
    owner = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    held = ClientTelephone.create!(
      user: owner, raw_number: "+819012340001", confirm_policy: true,
      confirm_using_mfa: true,
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
    )

    assert_no_difference(%w(Client.count ClientTelephone.count)) do
      post auth_app_sign_up_telephone_url(ri: "jp"),
           params: { client_telephone: { raw_number: "+819012340001", confirm_policy: "1", confirm_using_mfa: "1" },
                     "cf-turnstile-response": "test", },
           headers: headers
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.telephone.create.contact_held")
    assert_equal ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP, held.reload.user_telephone_status_id
  end

  private

  def admit!
    host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    ClientSignUpFlowStatus.ensure_defaults!
    ClientSignUpFlowCleanupStatus.ensure_defaults!
    cookies["csrf_token"] = csrf_token_value
    issuance = OidcTestEntry.issue!(
      surface: "app", intent: "sign_up", base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    admit_auth_ceremony_entry!(auth_app_sign_up_path(ri: "jp"), reference: issuance.reference)

    assert_response :see_other
  end

  def csrf_token_value = "test-csrf-token"

  def headers
    { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin", "X-CSRF-Token" => csrf_token_value }
  end
end
