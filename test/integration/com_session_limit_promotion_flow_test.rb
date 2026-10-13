# typed: false
# frozen_string_literal: true

require "test_helper"

class ComSessionLimitPromotionFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    reference_now = VisitorSignInFlow.database_now
    VisitorSessionLimitResolutionState::DEFAULTS.each do |id|
      VisitorSessionLimitResolutionState.find_or_create_by!(id: id) do |state|
        state.created_at = reference_now
        state.updated_at = reference_now
      end
    end
    VisitorSignOutFlowKind.ensure_defaults!
    VisitorSignOutFlowStatus.ensure_defaults!
    @host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    @base_host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! @host
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "a visitor at the session limit revokes the existing session and continues sign-in" do
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    VisitorToken.where(visitor_id: visitor.id).delete_all
    address = "com-limit-#{SecureRandom.hex(4)}@example.com"
    email = VisitorEmail.create!(
      visitor_id: visitor.id, address: address,
      address_digest: IdentifierBlindIndex.bidx_for_email(address, realm: :com),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    existing = VisitorToken.create!(
      visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB, skip_session_limit_check: true,
    )
    base = open_session
    base.host!(@base_host)
    base.https!
    base.get(base_com_sign_show_path, params: { ri: "jp" })
    nonce = SecureRandom.urlsafe_base64(SignInCycleLocator::NONCE_BYTES)
    issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
      surface: "com",
      intent: "sign_in",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: nil,
      nonce_digest: VisitorSignInFlow.digest_nonce(nonce),
    )
    SignInCycleLocator.new(base.session, surface: "com").issue!(issuance.transaction, nonce: nonce)
    primary_binding = SignInFlowBindingCodec.encode(
      flow: issuance.transaction, surface: "com", phase: "PRIMARY_PENDING",
    )
    session_key = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
    jar = ActionDispatch::Cookies::CookieJar.build(base.request, base.request.cookies)
    jar.encrypted[session_key] = { value: base.session.to_hash.stringify_keys }
    base.cookies.delete(session_key)
    store_raw_cookies(
      base.cookies,
      "#{session_key}=#{Rack::Utils.escape(jar[session_key])}", URI.parse("https://#{@base_host}/"),
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "com", reference: issuance.reference)
    auth_session, raw_sid = VisitorAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: auth_session, confirmation_ref: SecureRandom.uuid)
    browser_digest = AuthAdmissionBinding.browser_digest(
      surface: "com", entry_ref: binding.entry_ref, nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
    )
    binding.confirm_base!(base_token: nil, browser_digest: browser_digest)
    https!
    store_raw_cookies(
      cookies,
      "auth_sid=#{Rack::Utils.escape(raw_sid)}", URI.parse("https://#{@host}/"),
    )
    get(auth_com_sign_in_path, params: { entry_ref: issuance.reference, ri: "jp" })
    continuation = response.parsed_body.at_css("form")

    assert_not_nil continuation
    continuation_fields = continuation.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    post(continuation["action"], params: continuation_fields)

    assert_response :see_other
    clear_enqueued_jobs
    post auth_com_sign_in_email_url(ri: "jp", fb: primary_binding),
         params: { :user_email => { address: email.address }, "cf-turnstile-response" => "t" }

    assert_response :redirect
    job = enqueued_jobs.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil job
    delivery = ActiveJob::Arguments.deserialize(job.fetch(:args)).last.fetch(:params).symbolize_keys
    code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))
    patch auth_com_sign_in_email_url(ri: "jp", fb: primary_binding),
          params: { "visitor_email" => { "pass_code" => code }, "cf-turnstile-response" => "t" }
    follow_redirect! if response.redirect?
    follow_redirect! if response.redirect?
    post auth_com_sign_handoff_path(ri: "jp"), params: { ri: "jp" }

    assert_response :see_other
    completion = URI.parse(response.location)

    assert_equal @base_host, completion.host
    base.get(completion.request_uri)

    assert_equal 200, base.response.status
    result_form = base.response.parsed_body.at_css("form")

    assert_not_nil result_form
    completion_fields = result_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(
      result_form["action"],
      params: completion_fields,
      headers: { "Origin" => "https://#{@base_host}", "Sec-Fetch-Site" => "same-origin" },
    )
    base.follow_redirect! if base.response.redirect?

    assert_equal 200, base.response.status
    assert_equal "base/com/sign/in/limitations/show", base.inertia_component
    items = base.inertia_props.fetch("sessions")

    assert_equal 1, items.size

    base.patch(base_com_sign_in_limitation_path(ri: "jp"), params: { session_ref: items.first.fetch("session_ref") })

    assert_equal 303, base.response.status
    assert_predicate existing.reload, :revoked?
    cycle = VisitorSignInFlow.where(principal_id: visitor.id).recent_first.first
    resolution = VisitorSessionLimitResolutionTransaction.find_by!(sign_in_flow_id: cycle.id)

    assert_predicate cycle, :sign_in_completed?
    assert_predicate cycle.token_id, :present?
    assert_predicate resolution, :resolved?
  end
end
