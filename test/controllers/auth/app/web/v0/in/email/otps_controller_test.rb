# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::App::Web::V0::In::Email::OtpsControllerTest < ActionDispatch::IntegrationTest
  # Rate-limit counters are a NullStore by default in test so unrelated tests
  # cannot accumulate them; this file asserts real limiting behavior, so it
  # opts into a deterministic MemoryStore.
  rate_limit_counters!

  include ActiveJob::TestHelper

  setup do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    admission = BaseAuthAdmissionCoordinator.issue_local_entry!(
      surface: "app", intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
    )
    get "/sign/in", params: { entry_ref: admission.reference, ri: "jp" }, headers: { "Host" => @host }
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post "/ceremony_bindings", params: { entry_ref: admission.reference, authenticity_token: csrf, ri: "jp" },
                               headers: { "Host" => @host }

    assert_response :see_other
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: admission.reference)
    binding.reload.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get "/sign/in", params: { entry_ref: admission.reference, ri: "jp" }, headers: { "Host" => @host }
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post "/sign/in", params: { entry_ref: admission.reference, authenticity_token: csrf, ri: "jp" },
                     headers: { "Host" => @host }

    assert_response :see_other
    @primary_sign_in_binding = SignInFlowBindingCodec.encode(
      flow: ClientSignInFlow.find_by!(
        public_id: admitted_auth_ceremony_session_for_test(binding.reload).local_sign_in_flow_ref,
      ),
      surface: "app", phase: "PRIMARY_PENDING",
    )
    ActionMailer::Base.deliveries.clear
  end

  test "a released Contact cannot mint a new resend state from a stale code entry page" do
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    address = "stale-resend-#{SecureRandom.hex(8)}@example.test"
    owner = Client.create!(
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE,
    )
    contact = owner.client_emails.create!(
      address: address, confirm_policy: "1", user_email_status_id: ClientEmailStatus::VERIFIED,
    ).tap(&:finalize_binding!)
    post(
      "/sign/in/email", params: { :user_email => { address: address },
                                  "cf-turnstile-response" => "test",
                                  :fb => @primary_sign_in_binding, },
                        headers: { "Host" => @host },
    )

    assert_response :redirect
    entry_url = URI.parse(response.location).request_uri
    contact.release_binding!
    get(entry_url, params: { ri: "jp" }, headers: { "Host" => @host })

    assert_response :redirect
    assert_redirected_to %r{/sign/in/email/new}
    assert_predicate contact.reload, :binding_released?
  ensure
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "a signed resend state cannot authorize a browser without confirmed admission" do
    state = SignInOtpResendState.issue(
      kind: :email, target: "unadmitted-app-#{SecureRandom.hex(8)}@example.test", surface: :app,
      browser_binding: "b" * 64,
      contact: nil,
    )
    browser = open_session
    browser.host!(@host)
    assert_no_difference "EmailOccurrence.count" do
      browser.post("/web/v0/in/email/otp", params: { state: state }, headers: { "Host" => @host }, as: :json)
    end

    assert_equal 400, browser.response.status
  end

  test "recent issued returns 429 with retry_after and header" do
    email = "retry_#{SecureRandom.hex(4)}@example.com"
    hmac = OccurrenceHmac.digest(kind: :email, body: email)
    EmailOccurrence.where(body: hmac).delete_all
    EmailOccurrence.create!(
      body: hmac,
      status_id: EmailOccurrenceStatus::ACTIVE,
      memo: "purpose=in issued=#{Time.current.to_i}",
    )

    post auth_app_web_v0_in_email_otp_path,
         params: { state: state_for(email) },
         headers: { "Host" => @host },
         as: :json

    assert_response :too_many_requests
    assert_not response.parsed_body["resendable"]
    assert_operator response.parsed_body["retry_after"], :>, 0
    assert_equal response.parsed_body["retry_after"].to_s, response.headers["Retry-After"]
  end

  test "resend state from another admitted browser cannot reserve dispatch for its destination" do
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    address = "bound-resend-#{SecureRandom.hex(8)}@example.test"
    post(
      "/sign/in/email", params: {
        :user_email => { address: address },
        "cf-turnstile-response" => "test",
        :fb => @primary_sign_in_binding,
      }, headers: { "Host" => @host },
    )

    assert_response :redirect
    assert_redirected_to %r{/sign/in/email/edit}
    assert_not_nil SignAppInEmailAuthenticationState.load(session)
    get(URI.parse(response.location).request_uri, params: { ri: "jp" }, headers: { "Host" => @host })

    assert_response :success
    state = inertia_props.fetch("otp_resend").fetch("state")
    other = open_session
    other.host!(@host)
    admission = BaseAuthAdmissionCoordinator.issue_local_entry!(
      surface: "app", intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
    )
    other.get("/sign/in", params: { entry_ref: admission.reference, ri: "jp" })
    csrf = other.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    other.post("/ceremony_bindings", params: { entry_ref: admission.reference, authenticity_token: csrf, ri: "jp" })

    assert_equal 303, other.response.status
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: admission.reference)
    binding.reload.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    other.get("/sign/in", params: { entry_ref: admission.reference, ri: "jp" })
    csrf = other.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    other.post("/sign/in", params: { entry_ref: admission.reference, authenticity_token: csrf, ri: "jp" })

    assert_equal 303, other.response.status
    assert_no_difference "EmailOccurrence.count" do
      other.post("/web/v0/in/email/otp", params: { state: state }, as: :json)
    end

    assert_equal 400, other.response.status
  ensure
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "after cooldown returns 200 and logs issued occurrence" do
    user = clients(:one)
    email = "ok_#{SecureRandom.hex(4)}@example.com"
    user.client_emails.create!(address: email, user_email_status_id: ClientEmailStatus::VERIFIED).finalize_binding!

    hmac = OccurrenceHmac.digest(kind: :email, body: email)
    EmailOccurrence.where(body: hmac).delete_all
    EmailOccurrence.create!(
      body: hmac,
      status_id: EmailOccurrenceStatus::ACTIVE,
      memo: "purpose=in issued=#{31.seconds.ago.to_i}",
    )

    assert_difference -> { ActionMailer::Base.deliveries.count }, 1 do
      perform_enqueued_jobs do
        post auth_app_web_v0_in_email_otp_path,
             params: { state: state_for(email) },
             headers: { "Host" => @host },
             as: :json
      end
    end

    assert_response :ok
    assert response.parsed_body["resendable"]
    assert_equal 0, response.parsed_body["retry_after"]

    occurrence = EmailOccurrence.find_by(body: hmac)

    assert_not_nil occurrence
    assert_equal EmailOccurrenceStatus::ACTIVE, occurrence.status_id
    assert_includes occurrence.memo, "purpose=in"
    assert_match(/issued=[0-9,]+/, occurrence.memo)
  end

  test "a retained resend state cannot resolve a released destination to another Identity" do
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    address = "released-resend-#{SecureRandom.hex(8)}@example.test"
    owner = Client.create!(id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE)
    original = owner.client_emails.create!(
      address: address, confirm_policy: "1", user_email_status_id: ClientEmailStatus::VERIFIED,
    ).tap(&:finalize_binding!)
    post(
      "/sign/in/email", params: { :user_email => { address: address },
                                  "cf-turnstile-response" => "test",
                                  :fb => @primary_sign_in_binding, },
                        headers: { "Host" => @host },
    )

    assert_response :redirect
    get(URI.parse(response.location).request_uri, params: { ri: "jp" }, headers: { "Host" => @host })

    assert_response :success
    state = inertia_props.fetch("otp_resend").fetch("state")
    original.release_binding!
    replacement_owner = Client.create!(
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE,
    )
    replacement = replacement_owner.client_emails.create!(
      address: address, confirm_policy: "1", user_email_status_id: ClientEmailStatus::VERIFIED,
    ).tap(&:finalize_binding!)
    unchanged = replacement.reload.attributes
    post("/web/v0/in/email/otp", params: { state: state }, headers: { "Host" => @host }, as: :json)

    assert_response :bad_request
    assert_equal unchanged, replacement.reload.attributes
    assert_predicate original.reload, :binding_released?
  ensure
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "success replaces its Ticket OTP generation while retaining Source OTP" do
    user = clients(:one)
    email_record = user.client_emails.create!(
      address: "rotate_#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    ).tap(&:finalize_binding!)

    state = state_for(email_record.address)
    cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[cookie_name])
    original = ceremony.reload.email_otp_context
    source = email_record.reload.attributes

    perform_enqueued_jobs do
      post auth_app_web_v0_in_email_otp_path,
           params: { state: state }, headers: { "Host" => @host }, as: :json
    end

    assert_response :ok

    assert_equal source, email_record.reload.attributes
    assert_not_equal original.fetch("generation"), ceremony.reload.email_otp_context.fetch("generation")
    # Boolean assertions keep proof digests out of failure output.
    proof_rotated = original.fetch("code_digest") != ceremony.email_otp_context.fetch("code_digest")

    assert proof_rotated,
           "generation binding invalidates the old stored proof even when six-digit values coincide"
    code = ActionMailer::Base.deliveries.last.text_part.body.decoded.match(/Pass Code:\s*([0-9]{6})/)[1]

    assert_predicate ceremony.verify_email_otp!(code: code), :success?
  end

  private

  def state_for(email)
    cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[cookie_name])
    contact = ClientEmail.effective_binding.with_address(email).take
    ceremony.issue_email_otp!(contact: contact, destination: email)
    SignInOtpResendState.issue(
      kind: :email, target: email, surface: :app, browser_binding: ceremony.sid_digest, contact: contact,
    )
  end
end
