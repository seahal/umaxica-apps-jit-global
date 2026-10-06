# frozen_string_literal: true

require "test_helper"

class StepUpCeremonyObservabilityTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  fixtures :client_statuses, :client_token_kinds, :client_token_statuses

  setup do
    @original_logger = Rails.logger
    @log = StringIO.new
    Rails.logger = ActiveSupport::Logger.new(@log)
  end

  teardown do
    Rails.logger = @original_logger
  end

  test "admission, acceptance and cancellation of one ceremony share a keyed reference and log no identifier" do
    actor, token = totp_actor_and_root_token
    base, auth, transaction = start_totp_step_up_from_base!(actor: actor, token: token)
    transaction_id = transaction.transaction_id
    auth_csrf = totp_form_csrf(auth)

    cancellation = cancel_on_auth_and_open_base_confirmation!(base, auth, csrf: auth_csrf)

    assert_equal "pending", transaction.reload.status
    post_base_cancellation!(base, cancellation)

    assert_equal 303, base.response.status
    assert_equal "canceled", transaction.reload.status

    events = @log.string.lines.filter_map { |line| JSON.parse(line) if line.start_with?('{"event":"auth.step_up.') }
    accepted = events.find { |event| event.fetch("event") == "auth.step_up.ceremony_accepted" }.fetch("data")
    canceled = events.find { |event| event.fetch("event") == "auth.step_up.canceled" }.fetch("data")
    expected_reference = StepUpObservabilityDigest.ceremony_ref(transaction_id)

    assert_equal expected_reference, accepted.fetch("ceremony_ref")
    assert_equal expected_reference, canceled.fetch("ceremony_ref")
    assert_equal StepUpObservabilityDigest.session_ref(token.public_id), canceled.fetch("browser_session_digest")
    assert_equal "step_up", canceled.fetch("purpose")
    assert_equal "settings_birthdate", canceled.fetch("scope")
    assert_equal "base_cancellation", canceled.fetch("stage")
    assert_equal "pending", canceled.fetch("state_before")
    assert_equal "canceled", canceled.fetch("state_after")
    assert_predicate canceled.fetch("request_id"), :present?
    assert_match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z\z/, canceled.fetch("occurred_at"))

    step_up_log = events.to_json

    assert_not_includes step_up_log, transaction_id
    assert_not_includes step_up_log, token.public_id
    assert_not_includes step_up_log, actor.public_id
    assert_not_includes step_up_log, auth_csrf
    assert_not_includes step_up_log, cancellation.fetch(:params).fetch("cancellation_handoff")
    assert_not_includes step_up_log, cancellation.fetch(:params).fetch("cancellation_ref")
  end

  test "an Auth ceremony page opened without admission is refused generically and logged as invalid_admission" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    get new_auth_app_verification_totp_path(ri: "jp")

    assert_response :bad_request
    assert_equal I18n.t("errors.messages.invalid_request"), response.body
    assert_nil response.headers["Location"]
    refusal = @log.string.lines.filter_map { |line|
      JSON.parse(line) if line.start_with?('{"event":"auth.step_up.refused"')
    }.sole.fetch("data")

    assert_equal "invalid_admission", refusal.fetch("error_code")
    assert_equal "auth_ceremony_context", refusal.fetch("stage")
    assert_equal "refused", refusal.fetch("outcome")
    assert_not refusal.key?("ceremony_ref")
    assert_not_includes response.body, "invalid_admission"
  end

  test "an exact Base cancellation retry answers the same redirect and changes nothing" do
    actor, token = totp_actor_and_root_token
    base, auth, transaction = start_totp_step_up_from_base!(actor: actor, token: token)
    cancellation = cancel_on_auth_and_open_base_confirmation!(base, auth, csrf: totp_form_csrf(auth))
    post_base_cancellation!(base, cancellation)
    destination = base.response.location
    canceled_at = transaction.reload.canceled_at

    post_base_cancellation!(base, cancellation)

    assert_equal 303, base.response.status
    assert_equal destination, base.response.location
    assert_equal "canceled", transaction.reload.status
    assert_equal canceled_at, transaction.canceled_at
  end

  test "a second cancellation after the ceremony ended is refused and logged without changing the terminal state" do
    actor, token = totp_actor_and_root_token
    base, auth, transaction = start_totp_step_up_from_base!(actor: actor, token: token)
    auth_csrf = totp_form_csrf(auth)
    post_base_cancellation!(base, cancel_on_auth_and_open_base_confirmation!(base, auth, csrf: auth_csrf))
    canceled_at = transaction.reload.canceled_at

    auth.post(
      auth_app_verification_cancellation_path(ri: "jp"), params: { authenticity_token: auth_csrf },
                                                         headers: { "Origin" => "https://#{auth.host}" },
    )

    assert_equal 400, auth.response.status
    assert_equal I18n.t("errors.messages.invalid_request"), auth.response.body
    assert_equal "canceled", transaction.reload.status
    assert_equal canceled_at, transaction.canceled_at
    refusals =
      @log.string.lines.filter_map { |line|
        JSON.parse(line) if line.start_with?('{"event":"auth.step_up.refused"')
      }

    assert_equal ["invalid_admission"], refusals.map { |event| event.fetch("data").fetch("error_code") }
  end

  test "reading an expired ceremony is refused without rewriting its stored status" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    token = ClientToken.create!(user: actor)
    issuance = issue_base_step_up_admission!(
      actor: actor, token: token,
      requirement: totp_step_up_requirement(actor: actor, token: token), return_to: "/identity/birthdate",
      base_browser_nonce: "test-browser-nonce", base_token: token,
    )
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    redeem_auth_ceremony_entry!(
      auth_app_verification_path, reference: issuance.reference, params: { ri: "jp" }, base_token: token,
    )
    # Moves the deadline into the past; no public API shortens a live transaction.
    issuance.transaction.update_columns(expires_at: ClientStepUpCeremonyTransaction.database_now - 1.second)
    updated_at = issuance.transaction.reload.updated_at

    [auth_app_verification_path(ri: "jp"), new_auth_app_verification_totp_path(ri: "jp"),
     auth_app_verification_handoff_path(ri: "jp"),].each do |path|
      get path

      assert_response :bad_request, path
      assert_equal I18n.t("errors.messages.invalid_request"), response.body
    end
    issuance.transaction.reload

    assert_equal "pending", issuance.transaction.status
    assert_equal updated_at, issuance.transaction.updated_at
    refusals =
      @log.string.lines.filter_map { |line|
        JSON.parse(line) if line.start_with?('{"event":"auth.step_up.refused"')
      }

    assert_equal ["transaction_expired"] * 3, refusals.map { |event| event.fetch("data").fetch("error_code") }
    assert_equal [StepUpObservabilityDigest.ceremony_ref(issuance.transaction.transaction_id)] * 3,
                 refusals.map { |event| event.fetch("data").fetch("ceremony_ref") }
  end

  test "an unauthenticated Base page request records which credentials the browser presented" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    get base_app_identity_path(ri: "jp"), headers: { "Sec-Fetch-Site" => "cross-site" }

    assert_response :redirect
    required = @log.string.lines.filter_map { |line|
      JSON.parse(line) if line.start_with?('{"event":"auth.session.authentication_required"')
    }.sole.fetch("data")

    assert_equal "Base::App::IdentitiesController", required.fetch("controller")
    assert_equal "access_credential_missing", required.fetch("failure_reason")
    assert_not required.fetch("access_credential_presented")
    assert_not required.fetch("refresh_credential_presented")
    assert_equal "cross-site", required.fetch("fetch_site")
    assert_predicate required.fetch("occurred_at"), :present?
  end

  test "a Base page request with an unusable access credential is recorded as presented and invalid" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = "not-a-token"
    get base_app_identity_path(ri: "jp")

    assert_response :redirect
    required = @log.string.lines.filter_map { |line|
      JSON.parse(line) if line.start_with?('{"event":"auth.session.authentication_required"')
    }.sole.fetch("data")

    assert_equal "access_credential_invalid", required.fetch("failure_reason")
    assert required.fetch("access_credential_presented")
    assert_not required.fetch("refresh_credential_presented")
    assert_not_includes @log.string, "not-a-token"
  end

  # Sentinels of the header: empty, and a value outside the fetch-metadata vocabulary. An absent
  # header is not reachable here: the integration client supplies "same-origin" when none is given.
  test "the authentication-required record omits an empty or unknown fetch-site value" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    [{ "Sec-Fetch-Site" => "" }, { "Sec-Fetch-Site" => "https://evil.example/\u0000" }].each do |headers|
      get base_app_identity_path(ri: "jp"), headers: headers

      assert_response :redirect
    end
    records =
      @log.string.lines.filter_map { |line|
        JSON.parse(line) if line.start_with?('{"event":"auth.session.authentication_required"')
      }

    assert_equal [nil, nil], records.map { |record| record.fetch("data")["fetch_site"] }
    assert_not_includes @log.string, "evil.example"
  end

  test "a Base completion without the browser transaction marker is refused as return_binding_mismatch" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(
      user: actor, user_token_kind_id: ClientTokenKind::BROWSER_WEB, user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    # Base authenticates only the Browser RP access cookie, so the request carries a real self-RP
    # chain. Both references are well-formed; only the browser marker is absent.
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    rp_session = ClientRpSession.create!(
      client_token: token, oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_auth_time: 1.minute.ago, refresh_token_expires_at: 10.minutes.from_now,
    )
    access_token = AuthenticationTokenService.encode(
      actor,
      host: OidcIssuer.host_for_resource_type("client"), resource_type: "client",
      session_public_id: token.public_id, base_session_public_id: token.public_id,
      oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti, expires_at: 10.minutes.from_now,
      scopes: %w(openid profile), issuer: OidcIssuer.for_client(oidc_client), audiences: [oidc_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(oidc_client),
      subject: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
    )
    result_reference = "5f0c1b1e-0000-4000-8000-000000000002"

    host! host
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token
    post base_app_verification_completion_path(ri: "jp"),
         params: { transaction_ref: "5f0c1b1e-0000-4000-8000-000000000001", result_ref: result_reference }

    assert_response :bad_request
    assert_equal I18n.t("errors.messages.invalid_request"), response.body
    refusal = @log.string.lines.filter_map { |line|
      JSON.parse(line) if line.start_with?('{"event":"auth.step_up.refused"')
    }.sole.fetch("data")

    assert_equal "return_binding_mismatch", refusal.fetch("error_code")
    assert_equal "base_completion", refusal.fetch("stage")
    assert_equal StepUpObservabilityDigest.session_ref(token.public_id), refusal.fetch("browser_session_digest")
    assert_not_includes @log.string.lines.grep(/auth\.step_up\./).join, result_reference
    assert_not_includes @log.string.lines.grep(/auth\.step_up\./).join, access_token
    assert_nil token.reload.last_step_up_at
  end
  private

  def totp_actor_and_root_token
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    [actor, ClientToken.create!(user: actor)]
  end

  def totp_form_csrf(auth)
    page = Nokogiri::HTML(auth.response.body).at_css("script[data-page='app']")
    JSON.parse(page.text).fetch("props").fetch("form").fetch("csrf_token")
  end

  # Auth only issues the handoff; the returned form is Base's confirmation page, not yet submitted.
  def cancel_on_auth_and_open_base_confirmation!(base, auth, csrf:)
    auth.post(
      auth_app_verification_cancellation_path(ri: "jp"), params: { authenticity_token: csrf },
                                                         headers: { "Origin" => "https://#{auth.host}" },
    )

    assert_equal 303, auth.response.status
    base.get(URI.parse(auth.response.location).request_uri)

    assert_equal 200, base.response.status
    form = Nokogiri::HTML(base.response.body).at_css("form")
    hidden = form.css("input[type='hidden']").to_h { |input| [input["name"], input["value"]] }
    { action: form["action"], params: hidden }
  end

  def post_base_cancellation!(base, cancellation)
    base.post(
      cancellation.fetch(:action), params: cancellation.fetch(:params),
                                   headers: { "Origin" => "https://#{base.host}", "Sec-Fetch-Site" => "same-origin" },
    )
  end

  # A Base browser holding the self-RP credentials for page requests and the root session cookie
  # for Base's authority endpoints.
  def signed_in_base_browser(actor:, token:, base_host:)
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
    BaseSelectorAuthority.prepare(surface: :app, principal: actor, session: token)
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    rp_session = ClientRpSession.create!(
      client_token: token, oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    access_token = AuthenticationTokenService.encode(
      actor,
      host: base_host, resource_type: "client", session_public_id: token.public_id,
      base_session_public_id: token.public_id, oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
      expires_at: 10.minutes.from_now, scopes: %w(openid profile), issuer: OidcIssuer.for_client(oidc_client),
      audiences: [oidc_client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(oidc_client),
      subject: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
    )
    base = open_session
    base.host!(base_host)
    base.https!
    base.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token
    base.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = rp_session.issue_refresh_token!
    # Base's authority endpoints (binding confirmation, cancellation, completion) authenticate the
    # root session and never accept the RP cookies above.
    base.cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = AuthenticationToken.encode(
      actor, host: base_host, session_public_id: token.public_id, resource_type: "client",
             jwt_issuer_id: "surface:BASE_APP",
    )
    base
  end

  # Starts a TOTP Step-Up the way a browser does: the Base intent POST creates the transaction and
  # its browser marker, Jump carries the entry to Auth, and Base confirms the admission binding.
  # Returns the Base browser, the Auth browser on the TOTP page, and the transaction.
  def start_totp_step_up_from_base!(actor:, token:)
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    base = signed_in_base_browser(actor: actor, token: token, base_host: base_host)
    base.get(base_app_identity_birthdate_path(ri: "jp"))
    base.follow_redirect!
    page = Nokogiri::HTML(base.response.body)
    intent = JSON.parse(page.at_css("script[data-page='app']").text).fetch("props").fetch("form")
    base.post(
      intent.fetch("action"),
      params: { scope: intent.fetch("scope"), pt: intent.fetch("pt") },
      headers: { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" },
    )
    # An unsafe Base request rotates the RP credentials; carry all three cookies forward.
    sync_response_cookie!(base, "session")
    sync_response_cookie!(base, OidcRpBrowserCredentialContract::ACCESS_COOKIE)
    sync_response_cookie!(base, OidcRpBrowserCredentialContract::REFRESH_COOKIE)
    rt = Rack::Utils.parse_query(URI.parse(base.response.location).query).fetch("rt")
    # The Jump token is read only for its destination; its signature is the gateway's concern.
    target = URI.parse(JWT.decode(rt, nil, false).first.fetch("url"))
    reference = Rack::Utils.parse_query(target.query).fetch("entry_ref")
    auth = open_session
    auth.host!(auth_host)
    auth.https!
    redeem_auth_ceremony_session!(
      auth, target.path,
      reference: reference, params: { ri: "jp" }, confirm_via_http: true, base_browser: base,
      headers: { "Host" => auth_host, "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" },
    )
    auth.get(new_auth_app_verification_totp_path(ri: "jp"))
    [base, auth, ClientStepUpCeremonyTransaction.find_by!(session_ref: token.public_id)]
  end

  def totp_step_up_requirement(actor:, token:)
    StepUpRequirement.new(
      step_up_required: true, scope: "settings_birthdate", allowed_methods: [:totp],
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: StepUpRequirement::DEFAULT_TTL,
      purpose: "step_up", audience: "step_up:app", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true,
      actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
    )
  end
end
