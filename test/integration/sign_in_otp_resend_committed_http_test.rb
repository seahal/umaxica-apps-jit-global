# frozen_string_literal: true

require "test_helper"

class SignInOtpResendCommittedHttpTest < ActionDispatch::IntegrationTest
  NAVIGATION_HEADERS = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }.freeze

  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "social sign-in starts with a freshly committed admission" do
    feature = FeatureFlags::REGISTRY.fetch(:sign_in_available_app).name
    enabled = Flipper.enabled?(feature)
    Flipper.enable(feature)
    host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    https!
    admission = OidcTestEntry.issue!(
      surface: "app", intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
    )
    get("/sign/in", params: { entry_ref: admission.reference, ri: "jp" }, headers: NAVIGATION_HEADERS)

    assert_response :see_other
    get(response.location, headers: NAVIGATION_HEADERS)

    assert_response :see_other
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: admission.reference)
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get("/sign/in", params: { entry_ref: admission.reference, ri: "jp" }, headers: NAVIGATION_HEADERS)

    assert_response :see_other

    post(auth_app_social_google_session_path(ri: "jp"))

    assert_response :temporary_redirect
  ensure
    if admission
      bindings = ClientAuthAdmissionBinding.where(authorization_transaction_id: admission.transaction.id)
      session_ids = bindings.pluck(:auth_ceremony_session_id, :admitted_auth_ceremony_session_id).flatten.compact.uniq
      bindings.delete_all
      ClientAuthCeremonySession.where(id: session_ids).delete_all
      admission.transaction.delete
    end
    if feature
      enabled ? Flipper.enable(feature) : Flipper.disable(feature)
    end
  end

  test "initial sign in preserves its challenge when the email queue refuses it and can resend" do
    feature = FeatureFlags::REGISTRY.fetch(:sign_in_available_app).name
    enabled = Flipper.enabled?(feature)
    Flipper.enable(feature)
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    https!
    address = "initial-queue-refused-#{SecureRandom.hex(8)}@example.test"
    candidate_body = OccurrenceHmac.digest(kind: :email, body: address)

    assert_not EmailOccurrence.exists?(body: candidate_body)
    occurrence_body = candidate_body
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    contact = owner.client_emails.create!(address:, confirm_policy: "1").tap(&:finalize_binding!)
    admission = OidcTestEntry.issue!(
      surface: "app", intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
    )
    get("/sign/in", params: { entry_ref: admission.reference, ri: "jp" }, headers: NAVIGATION_HEADERS)

    assert_response :see_other
    get(response.location, headers: NAVIGATION_HEADERS)

    assert_response :see_other
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: admission.reference)
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get("/sign/in", params: { entry_ref: admission.reference, ri: "jp" }, headers: NAVIGATION_HEADERS)

    assert_response :see_other
    sid_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[sid_name])
    previous = ceremony.email_otp_context.deep_dup
    refused_job = Minitest::Mock.new
    refused_job.expect(:perform_later, false) { |*_, **_| true }

    OtpNotifierEmailDeliveryJob.stub(:set, refused_job) do
      post(
        auth_app_sign_in_email_path(ri: "jp"),
        params: { :user_email => { address: }, "cf-turnstile-response" => "test" },
        headers: { "X-Inertia" => "true", "X-Requested-With" => "XMLHttpRequest" },
      )
    end

    assert_response :service_unavailable
    assert_withheld { previous != ceremony.reload.email_otp_context }
    assert_equal contact.id, SignAppInEmailAuthenticationState.load(session).id
    props = response.parsed_body.fetch("props")

    assert_equal I18n.t("sign.app.authentication.email.edit.delivery_unavailable"), props.fetch("description")
    resend = props.fetch("otp_resend")

    assert_equal auth_app_web_v0_in_email_otp_path, URI.parse(resend.fetch("endpoint")).path
    assert_predicate resend.fetch("state"), :present?
    generation = ceremony.reload.email_otp_context.fetch("generation")
    post(resend.fetch("endpoint"), params: { state: resend.fetch("state") }, as: :json)

    assert_response :success
    assert response.parsed_body.fetch("resendable")
    assert_withheld { generation != ceremony.reload.email_otp_context.fetch("generation") }
    refused_job.verify
  ensure
    EmailOccurrence.where(body: occurrence_body).delete_all if occurrence_body
    if admission
      bindings = ClientAuthAdmissionBinding.where(authorization_transaction_id: admission.transaction.id)
      session_ids = bindings.pluck(:auth_ceremony_session_id, :admitted_auth_ceremony_session_id).flatten.compact.uniq
      bindings.delete_all
      ClientAuthCeremonySession.where(id: session_ids).delete_all
      admission.transaction.delete
    end
    contact&.delete
    owner&.delete
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
    if feature
      enabled ? Flipper.enable(feature) : Flipper.disable(feature)
    end
  end

  test "org admission reads its newly committed authorization parent from the writer" do
    feature = FeatureFlags::REGISTRY.fetch(:sign_in_available_org).name
    enabled = Flipper.enabled?(feature)
    Flipper.enable(feature)
    host!(ENV.fetch("PUBLIC_AUTH_STAFF_URL"))
    https!
    admission = OidcTestEntry.issue!(
      surface: "org", intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
    )

    get("/sign/in", params: { entry_ref: admission.reference, ri: "jp" }, headers: NAVIGATION_HEADERS)

    assert_response :see_other
    assert_equal "/ceremony_bindings", URI.parse(response.location).path
    get(response.location, headers: NAVIGATION_HEADERS)

    assert_response :see_other
    binding = OperatorAuthAdmissionBinding.find_by!(entry_ref: admission.reference)

    assert_predicate binding, :attached?
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get("/sign/in", params: { entry_ref: admission.reference, ri: "jp" }, headers: NAVIGATION_HEADERS)

    assert_response :see_other
    get(response.location, headers: NAVIGATION_HEADERS)

    assert_response :success
  ensure
    if admission
      binding ||= OperatorAuthAdmissionBinding.find_by(authorization_transaction_id: admission.transaction.id)
      session_id = binding&.auth_ceremony_session_id
      OperatorAuthAdmissionBinding.where(authorization_transaction_id: admission.transaction.id).delete_all
      OperatorAuthCeremonySession.where(id: session_id).delete_all if session_id
      admission.transaction.delete
    end
    if feature
      enabled ? Flipper.enable(feature) : Flipper.disable(feature)
    end
  end

  %i(real fake).each do |mode|
    test "#{mode} sign-in resend succeeds through HTTP with committed Auth and occurrence transactions" do
      feature = FeatureFlags::REGISTRY.fetch(:sign_in_available_app).name
      enabled = Flipper.enabled?(feature)
      Flipper.enable(feature)
      host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
      https!
      address = "resend-committed-#{SecureRandom.hex(8)}@example.test"
      candidate_body = OccurrenceHmac.digest(kind: :email, body: address)

      assert_not EmailOccurrence.exists?(body: candidate_body)
      body = candidate_body
      if mode == :real
        owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
        contact = owner.client_emails.create!(address:, confirm_policy: "1").tap(&:finalize_binding!)
      end
      admission = OidcTestEntry.issue!(
        surface: "app", intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      get("/sign/in", params: { entry_ref: admission.reference, ri: "jp" }, headers: NAVIGATION_HEADERS)

      assert_response :see_other
      assert_equal "/ceremony_bindings", URI.parse(response.location).path
      binding = ClientAuthAdmissionBinding.find_by!(entry_ref: admission.reference)

      assert_predicate binding, :live?
      get(response.location, headers: NAVIGATION_HEADERS)

      assert_response :see_other
      binding.reload
      binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
      get("/sign/in", params: { entry_ref: admission.reference, ri: "jp" }, headers: NAVIGATION_HEADERS)

      assert_response :see_other
      sid_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
      ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[sid_name])
      ceremony.issue_email_otp!(contact:, destination: address)
      original_generation = ceremony.reload.email_otp_context.fetch("generation")
      state = SignInOtpResendState.issue(
        kind: :email, target: address, surface: :app, browser_binding: ceremony.sid_digest, contact:,
      )
      adapter = Minitest::Mock.new
      adapter.expect(:deliver, nil) { |**| true } if contact

      OtpAdapter.stub(:for, adapter) do
        post(auth_app_web_v0_in_email_otp_path, params: { state: }, as: :json)
      end

      assert_response :ok
      assert_equal({ "resendable" => true, "retry_after" => 0 }, response.parsed_body)
      assert_not_equal original_generation, ceremony.reload.email_otp_context.fetch("generation")
      assert EmailOccurrence.exists?(body:)
      adapter.verify
    ensure
      EmailOccurrence.where(body:).delete_all if body
      if admission
        ClientAuthAdmissionBinding.where(authorization_transaction_id: admission.transaction.id).delete_all
      end
      ceremony&.delete
      admission&.transaction&.delete
      contact&.delete
      owner&.delete
      if feature
        enabled ? Flipper.enable(feature) : Flipper.disable(feature)
      end
    end
  end
end
