# frozen_string_literal: true

require "test_helper"

class Auth::App::Sign::In::ChecksAuthorizationTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    host! @host
    begin
      admission_browser = self
      admission_surface = "app"
      admission_intent = "sign_in"
      admission_host = {
        "app" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
        "com" => ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
        "org" => ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
      }.fetch(admission_surface)
      admission_browser.host!(admission_host)
      admission_issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
        surface: admission_surface, intent: admission_intent,
        base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      admission_path = "/sign/#{(admission_intent == "sign_up") ? "up" : "in"}"
      admission_browser.get(
        admission_path,
        params: { entry_ref: admission_issuance.reference, ri: "jp" },
      )
      admission_csrf = admission_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      admission_browser.post(
        "/ceremony_bindings",
        params: { entry_ref: admission_issuance.reference, authenticity_token: admission_csrf, ri: "jp" },
      )

      assert_equal 303, admission_browser.response.status
      admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
        surface: admission_surface, reference: admission_issuance.reference,
      )
      admission_binding.reload.confirm_base!(
        base_token: nil,
        browser_digest: admission_binding.base_browser_digest,
      )
      admission_browser.get(
        admission_path,
        params: { entry_ref: admission_issuance.reference, ri: "jp" },
      )
      admission_csrf = admission_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      admission_browser.post(
        admission_path,
        params: { entry_ref: admission_issuance.reference, authenticity_token: admission_csrf, ri: "jp" },
      )

      assert_equal 303, admission_browser.response.status
    end
    @binding = admission_binding.reload
    @email = @user.client_emails.create!(
      address: "checkpoint-policy-#{SecureRandom.hex(8)}@example.test",
      user_email_status_id: ClientEmailStatus::VERIFIED, confirm_policy: true,
    )
    @email.finalize_binding!
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown { TurnstileVerifierStub.reset! }

  test "the admitted checkpoint authorizes its real actor before handing evidence to Base" do
    perform_enqueued_jobs do
      post auth_app_sign_in_email_path(ri: "jp"), params: {
        user_email: { address: @email.address }, "cf-turnstile-response": "test",
      }
    end

    assert_response :redirect
    code = ActionMailer::Base.deliveries.last.text_part.body.decoded.match(/Pass Code:\s*([0-9]{6})/).captures.fetch(0)
    patch auth_app_sign_in_email_path(ri: "jp"), params: { user_email: { pass_code: code } }

    assert_redirected_to auth_app_sign_in_check_path(ri: "jp")
    before = ClientToken.where(user_id: @user.id).count
    get auth_app_sign_in_check_path(ri: "jp")

    assert_response :see_other
    assert_equal auth_app_sign_handoff_path(ri: "jp"), URI.parse(response.location).request_uri
    assert_equal before, ClientToken.where(user_id: @user.id).count
    assert_predicate @binding.admitted_auth_ceremony_session.reload, :authentication_evidence_recorded?
    assert_nil @binding.sign_in_flow.reload.token_id
  end
end
