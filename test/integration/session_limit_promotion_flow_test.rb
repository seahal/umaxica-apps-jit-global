# typed: false
# frozen_string_literal: true

require "test_helper"

class SessionLimitPromotionFlowTest < ActionDispatch::IntegrationTest
  include AuthCeremonyEntryHelper

  fixtures :clients, :client_statuses, :client_email_statuses

  setup do
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    @base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    ClientToken.where(user_id: clients(:one).id).delete_all
    host! @host
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "revoking one active session at the limit issues the new session and continues sign-in" do
    user = clients(:one)
    Array.new(ClientToken::MAX_SESSIONS_PER_USER) do
      ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    end
    email = user.client_emails.create!(address: "limit_#{SecureRandom.hex(4)}@example.com")
    email.finalize_binding!
    base = complete_email_sign_in_for_session_limit!(email)

    assert_equal 200, base.response.status
    assert_equal "base/app/sign/in/limitations/show", base.inertia_component
    items = base.inertia_props.fetch("sessions")

    assert_equal ClientToken::MAX_SESSIONS_PER_USER, items.size
    cycle = ClientSignInFlow.where(principal_id: user.id).recent_first.first
    resolution = ClientSessionLimitResolutionTransaction.find_by!(sign_in_flow_id: cycle.id)

    assert_predicate cycle, :sign_in_session_issuance_pending?
    assert_predicate resolution, :open?

    selected = SessionLimitResolutionTokenRef.find_client_token(items.first.fetch("session_ref"))
    base.patch(base_app_sign_in_limitation_path(ri: "jp"), params: { session_ref: items.first.fetch("session_ref") })

    assert_equal 303, base.response.status
    assert_not_equal base_app_sign_in_limitation_path(ri: "jp"), base.response.location
    assert_predicate selected.reload, :revoked?

    cycle.reload

    assert_predicate cycle, :sign_in_completed?
    assert_predicate cycle.token_id, :present?
    assert_predicate base.cookies[AuthenticationBase::ACCESS_COOKIE_KEY].to_s, :present?
  end

  test "submitting the session limit form without a selection keeps the limit and explains why" do
    user = clients(:one)
    ClientToken::MAX_SESSIONS_PER_USER.times do
      ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    end
    email = user.client_emails.create!(address: "limit_#{SecureRandom.hex(4)}@example.com")
    email.finalize_binding!
    base = complete_email_sign_in_for_session_limit!(email)

    base.patch(base_app_sign_in_limitation_path(ri: "jp"), params: { session_ref: "" })

    assert_equal 422, base.response.status
    assert_predicate ClientSessionLimitResolutionTransaction.order(:id).last, :open?
    assert_predicate ClientSignInFlow.where(principal_id: user.id).recent_first.first,
                     :sign_in_session_issuance_pending?
  end

  test "cancelling at the session limit fails the sign-in without issuing a session" do
    user = clients(:one)
    existing =
      Array.new(ClientToken::MAX_SESSIONS_PER_USER) do
        ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
      end
    email = user.client_emails.create!(address: "limit_#{SecureRandom.hex(4)}@example.com")
    email.finalize_binding!
    base = complete_email_sign_in_for_session_limit!(email)
    cycle = ClientSignInFlow.where(principal_id: user.id).recent_first.first
    resolution = ClientSessionLimitResolutionTransaction.find_by!(sign_in_flow_id: cycle.id)

    base.delete(base_app_sign_in_limitation_path(ri: "jp"))

    assert_equal 303, base.response.status
    assert_predicate cycle.reload, :sign_in_cancelled?
    assert_predicate resolution.reload, :cancelled?
    assert(existing.all? { |token| token.reload.currently_usable? })
    assert_predicate base.cookies[AuthenticationBase::ACCESS_COOKIE_KEY].to_s, :empty?
  end

  private

  def complete_email_sign_in_for_session_limit!(email)
    base = open_session
    auth = open_session
    base.host!(@base_host)
    base.https!
    base.get("/sign", params: { ri: "jp" })
    nonce = SecureRandom.urlsafe_base64(SignInCycleLocator::NONCE_BYTES)
    issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
      surface: "app", intent: "sign_in", base_browser_nonce: "test-browser-nonce", base_token: nil,
      nonce_digest: ClientSignInFlow.digest_nonce(nonce),
    )
    SignInCycleLocator.new(base.session, surface: "app").issue!(issuance.transaction, nonce: nonce)
    session_key = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
    session_cookie_jar = ActionDispatch::Cookies::CookieJar.build(base.request, base.request.cookies)
    session_hash = base.session.to_hash.stringify_keys
    session_cookie_jar.encrypted[session_key] = { value: session_hash }
    encoded_session = session_cookie_jar[session_key]
    base.cookies.delete(session_key)
    base.cookies.merge( # rubocop:disable Lint/Void
      "#{session_key}=#{Rack::Utils.escape(encoded_session)}",
      URI.parse("https://#{@base_host}/"),
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    _auth_session, raw_sid = prepare_admission_binding_for_consumption!(binding, base_token: nil)
    auth.host!(@host)
    auth.https!
    auth_headers = {
      "Host" => @host, "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin",
    }
    auth.cookies.merge( # rubocop:disable Lint/Void
      "auth_sid=#{Rack::Utils.escape(raw_sid)}", URI.parse("https://#{@host}/"),
    )
    auth.get(auth_app_sign_in_path(ri: "jp"), params: { entry_ref: issuance.reference }, headers: auth_headers)
    continuation = Nokogiri::HTML(auth.response.body).at_css("form")
    continuation_params =
      continuation.css("input[type='hidden']").to_h do |input|
        [input["name"], input["value"]]
      end
    continuation_csrf = continuation.at_css('input[name="authenticity_token"]')["value"]
    auth.post(
      continuation["action"], params: continuation_params.merge("authenticity_token" => continuation_csrf),
                              headers: auth_headers,
    )
    auth.post(
      auth_app_sign_in_email_path(ri: "jp"),
      params: { :user_email => { address: email.address }, "cf-turnstile-response" => "t" },
      headers: auth_headers,
    )
    key = ROTP::Base32.random_base32
    email.reload.store_otp(key, 7, 12.minutes.from_now.to_i)
    auth.patch(
      auth_app_sign_in_email_path(ri: "jp"),
      params: { :user_email => { pass_code: ROTP::HOTP.new(key).at(7).to_s },
                "cf-turnstile-response" => "t", },
      headers: auth_headers,
    )
    auth.follow_redirect! if auth.response.redirect?
    auth.follow_redirect! if auth.response.redirect?
    handoff_form = Nokogiri::HTML(auth.response.body).at_css("form")
    handoff_csrf = handoff_form.at_css('input[name="authenticity_token"]')["value"]
    auth.post(
      auth_app_sign_handoff_path(ri: "jp"),
      params: { authenticity_token: handoff_csrf, ri: "jp" }, headers: auth_headers,
    )

    assert_equal 303, auth.response.status
    completion_uri = URI.parse(auth.response.location)
    base.host!(@base_host)
    base.https!
    base_headers = {
      "Host" => @base_host,
      "Origin" => "https://#{@base_host}",
      "Sec-Fetch-Site" => "same-site",
    }
    base.get(completion_uri.request_uri, headers: base_headers)

    assert_equal 200, base.response.status
    form = Nokogiri::HTML(base.response.body).at_css("form")
    params = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(form["action"], params: params, headers: base_headers)
    base.follow_redirect! if base.response.redirect?
    base
  end
end
