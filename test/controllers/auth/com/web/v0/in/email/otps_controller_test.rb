# typed: false
# frozen_string_literal: true

require "test_helper"

# The resend endpoint is called from the code-entry page with the opaque state
# that page was rendered with. It answers JSON either way: a state it cannot
# read must not disclose whether the address behind it exists, and a resend
# inside the cooldown must carry the retry window in a header the browser can
# act on.
class Auth::Com::Web::V0::In::Email::OtpsControllerTest < ActionDispatch::IntegrationTest
  # Rate-limit counters are a NullStore by default in test so unrelated tests
  # cannot accumulate them; this file asserts real limiting behavior, so it
  # opts into a deterministic MemoryStore.
  rate_limit_counters!

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")
    host! @host
    admission = OidcTestEntry.issue!(
      surface: "com", intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
    )
    get "/sign/in", params: { entry_ref: admission.reference, ri: "jp" }, headers: { "Host" => @host }
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post "/ceremony_bindings", params: { entry_ref: admission.reference, authenticity_token: csrf, ri: "jp" },
                               headers: { "Host" => @host }

    assert_response :see_other
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "com", reference: admission.reference)
    binding.reload.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get "/sign/in", params: { entry_ref: admission.reference, ri: "jp" }, headers: { "Host" => @host }
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post "/sign/in", params: { entry_ref: admission.reference, authenticity_token: csrf, ri: "jp" },
                     headers: { "Host" => @host }

    assert_response :see_other
    @primary_sign_in_binding = nil
  end

  test "a released Contact cannot mint a new resend state from a stale code entry page" do
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    address = "stale-resend-#{SecureRandom.hex(8)}@example.test"
    owner = Visitor.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: VisitorStatus::ACTIVE,
    )
    contact = owner.visitor_emails.create!(
      address: address, confirm_policy: "1", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    ).tap(&:finalize_binding!)
    post(
      "/sign/in/email", params: {
        :user_email => { address: address },
        "cf-turnstile-response" => "test",
        :fb => @primary_sign_in_binding,
      }, headers: { "Host" => @host },
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
      kind: :email, target: "unadmitted-com-#{SecureRandom.hex(8)}@example.test", surface: :com,
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

  test "resend state from another admitted browser cannot reserve dispatch for its destination" do
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    address = "bound-resend-#{SecureRandom.hex(8)}@example.test"
    post(
      "/sign/in/email", params: {
        :user_email => { address: address }, "cf-turnstile-response" => "test", :fb => @primary_sign_in_binding,
      }, headers: { "Host" => @host },
    )

    assert_response :redirect
    assert_redirected_to %r{/sign/in/email/edit}
    assert_equal address, session[:user_email_authentication_address]
    get(URI.parse(response.location).request_uri, params: { ri: "jp" }, headers: { "Host" => @host })

    assert_response :success
    state = inertia_props.fetch("resend").fetch("state")
    other = open_session
    other.host!(@host)
    admission = OidcTestEntry.issue!(
      surface: "com", intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
    )
    other.get("/sign/in", params: { entry_ref: admission.reference, ri: "jp" })
    csrf = other.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    other.post("/ceremony_bindings", params: { entry_ref: admission.reference, authenticity_token: csrf, ri: "jp" })

    assert_equal 303, other.response.status
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "com", reference: admission.reference)
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

  test "a retained resend state cannot resolve a released destination to another Identity" do
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    address = "released-resend-#{SecureRandom.hex(8)}@example.test"
    owner = Visitor.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: VisitorStatus::ACTIVE,
    )
    original = owner.visitor_emails.create!(
      address: address, confirm_policy: "1", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    ).tap(&:finalize_binding!)
    post(
      "/sign/in/email", params: {
        :user_email => { address: address },
        "cf-turnstile-response" => "test",
        :fb => @primary_sign_in_binding,
      }, headers: { "Host" => @host },
    )

    assert_response :redirect
    get(URI.parse(response.location).request_uri, params: { ri: "jp" }, headers: { "Host" => @host })

    assert_response :success
    state = inertia_props.fetch("resend").fetch("state")
    original.release_binding!
    replacement_owner = Visitor.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: VisitorStatus::ACTIVE,
    )
    replacement = replacement_owner.visitor_emails.create!(
      address: address, confirm_policy: "1", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
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

  test "a state this surface cannot read is answered without disclosing anything about it" do
    post auth_com_web_v0_in_email_otp_url(ri: "jp"),
         params: { state: "not-a-state" },
         headers: { "Host" => @host }

    assert_response :bad_request
    body = response.parsed_body

    assert_includes body.keys, "resendable"
    assert_includes body.keys, "retry_after"
  end

  test "a resend inside the cooldown carries the retry window in a header" do
    address = "cooldown-com-#{SecureRandom.hex(8)}@example.test"
    occurrence = EmailOccurrence.create!(
      body: OccurrenceHmac.digest(kind: :email, body: address),
      status_id: EmailOccurrenceStatus::ACTIVE,
      memo: "purpose=in issued=#{EmailOccurrence.database_now.to_i}",
    )
    cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    ceremony = VisitorAuthCeremonySession.find_active_by_raw_sid(cookies[cookie_name])
    state = SignInOtpResendState.issue(
      kind: :email, target: address, surface: :com, browser_binding: ceremony.sid_digest, contact: nil,
    )
    unchanged = occurrence.attributes
    post auth_com_web_v0_in_email_otp_url(ri: "jp"),
         params: { state: state }, headers: { "Host" => @host }

    assert_response :too_many_requests
    retry_after = response.parsed_body.fetch("retry_after")

    assert_operator retry_after, :>, 0
    assert_operator retry_after, :<=, SignInOtpResender::BASE_SECONDS
    assert_equal retry_after.to_s, response.headers["Retry-After"]
    assert_not response.parsed_body.fetch("resendable")
    assert_equal unchanged.fetch("memo")[/issued=([0-9,]+)/, 1],
                 occurrence.reload.memo[/issued=([0-9,]+)/, 1]
  end
end
