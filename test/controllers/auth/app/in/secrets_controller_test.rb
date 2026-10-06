# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::Sign::In::SecretsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @client = Client.create!(status_id: ClientStatus::ACTIVE)
    @identifier = "secret-bound-#{SecureRandom.hex(4)}@example.com"
    @client.client_emails.create!(
      address: @identifier, user_email_status_id: ClientEmailStatus::VERIFIED,
    ).finalize_binding!
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  [
    ["missing", :missing], ["null", nil], ["empty", ""], ["numeric zero", 0],
    ["array", []], ["object", {}], ["31 characters", "a" * 31], ["33 characters", "a" * 33],
    ["invalid Base58", "0" * 32], ["embedded NUL", ("a" * 31) + "\0"],
    ["exact case mismatch", "A" * 32], ["unknown 32-character value", "z" * 32],
  ].each_with_index do |(label, value), index|
    test "admitted HTTP Secret rejects #{label} without credential or session mutation" do
      host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      host! host
      https!
      # Distinct real request addresses keep independent input cases within the
      # existing online limits; rate-limit behavior is not stubbed or disabled.
      headers = {
        "REMOTE_ADDR" => "192.0.2.#{index + 10}",
        "Origin" => "https://#{host}",
        "Sec-Fetch-Site" => "same-origin",
      }
      admission = BaseAuthAdmissionCoordinator.issue_local_entry!(
        surface: "app", intent: "sign_in", base_browser_nonce: "test-browser-nonce", base_token: nil,
      )
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: admission.reference)
      _auth_session, raw_auth_sid = prepare_admission_binding_for_consumption!(
        binding, base_token: nil, base_browser_nonce: "test-browser-nonce",
      )
      cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
      cookies[cookie_name] = raw_auth_sid
      get auth_app_sign_in_path(ri: "jp"), params: { entry_ref: admission.reference }, headers: headers
      csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      post auth_app_sign_in_path(ri: "jp"), params: {
        entry_ref: admission.reference, authenticity_token: csrf,
      }, headers: headers

      assert_response :see_other
      get new_auth_app_sign_in_secret_path(ri: "jp"), headers: headers
      page = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text)
      payload = { "identifier" => @identifier, "cf-turnstile-response" => "synthetic" }
      payload[:secret] = value unless value == :missing
      before = ClientSecretCredential.order(:id).pluck(:id, :claimed_at, :consumed_at, :revoked_at, :discard_at)
      token_count = ClientToken.count
      outbox_count = ClientSecretAuditOutbox.count
      post(
        auth_app_sign_in_secret_path(ri: "jp"),
        params: payload,
        as: :json,
        headers: headers.merge("X-CSRF-Token" => page.fetch("props").fetch("authenticity_token")),
      )

      assert_response :unprocessable_content
      assert_equal before,
                   ClientSecretCredential.order(:id).pluck(:id, :claimed_at, :consumed_at, :revoked_at, :discard_at)
      assert_equal token_count, ClientToken.count
      assert_equal outbox_count, ClientSecretAuditOutbox.count
      flow = admission.transaction.reload

      assert_nil flow.principal_id
      assert_nil flow.token_id
    end
  end

  test "legacy Secret GET remains absent while canonical actions require browser admission" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host

    get "/sign/in/secret"

    assert_response :not_found

    assert_no_difference("ClientSecretCredential.count") do
      get new_auth_app_sign_in_secret_path(ri: "jp")

      assert_response :bad_request
    end
    assert_no_difference -> { ClientSecretCredential.where.not(claimed_at: nil).count } do
      assert_no_difference("ClientToken.count") do
        post auth_app_sign_in_secret_path(ri: "jp"), params: { secret: "a" * 32 }

        assert_response :bad_request
      end
    end
  end
end
