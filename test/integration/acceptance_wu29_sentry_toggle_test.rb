# typed: false
# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class AcceptanceWu29SentryToggleTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  SURFACES = [
    ["app", "PUBLIC_AUTH_SERVICE_URL"],
    ["com", "PUBLIC_AUTH_CORPORATE_URL"],
    ["org", "PUBLIC_AUTH_STAFF_URL"],
  ].freeze

  FLOWS = %w(sign_in sign_up).freeze

  setup do
    @previous_flags = SURFACES.flat_map do |surface, _host_env|
      FLOWS.map do |flow|
        feature = FeatureFlags::REGISTRY.fetch(:"#{flow}_available_#{surface}").name
        [feature, Flipper.enabled?(feature)]
      end
    end.to_h
  end

  teardown do
    @previous_flags.each do |feature, enabled|
      enabled ? Flipper.enable(feature) : Flipper.disable(feature)
    end
  end

  test "A29-7: each surface and flow reads availability again on the next request" do
    SURFACES.each do |surface, host_env|
      FLOWS.each do |flow|
        feature = FeatureFlags::REGISTRY.fetch(:"#{flow}_available_#{surface}").name
        path = (flow == "sign_in") ? "/sign/in/sentry" : "/sign/up/sentry"
        host = ENV.fetch(host_env)
        browser = open_session
        browser.host!(host)
        browser.https!

        Flipper.enable(feature)
        browser.get(path, params: { ri: "jp" })

        assert_equal 303, browser.response.status, "#{surface} #{flow} allowed before the flag changes"
        assert_equal "/sign/#{(flow == "sign_in") ? "in" : "up"}", URI.parse(browser.response.location).path

        Flipper.disable(feature)
        browser.get(path, params: { ri: "jp" })

        assert_equal 503, browser.response.status, "#{surface} #{flow} must observe ALLOWED → BLOCKED"
        assert_equal "no-store", browser.response.headers["Cache-Control"]

        Flipper.enable(feature)
        browser.get(path, params: { ri: "jp" })

        assert_equal 303, browser.response.status, "#{surface} #{flow} must observe BLOCKED → ALLOWED"
        assert_equal "/sign/#{(flow == "sign_in") ? "in" : "up"}", URI.parse(browser.response.location).path
      end
    end
  end
  test "A29-8 blocked entry preserves authenticated page, real refresh and completed Step-Up" do
    features = %i(sign_in_available_app sign_up_available_app)
    previous = features.index_with { |feature| Flipper.enabled?(feature) }
    protection = ActionController::Base.allow_forgery_protection
    previous_turnstile = [TurnstileVerifierStub.enabled, TurnstileVerifierStub.response,
                          TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response,]
    ActionController::Base.allow_forgery_protection = true
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    visa_host = visa_host_for_test_surface(:app)
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    root = ClientToken.create!(authentication_epoch: 0, user: actor, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
    BaseSelectorAuthority.prepare(surface: :app, principal: actor, session: root)
    root.rotate_refresh_token! unless root.device_session_record.current_refresh_token_id
    fake = WebAuthn::FakeClient.new("https://#{auth_host}", encoding: :base64url)
    registration = fake.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
    relying_party = WebAuthn::RelyingParty.new(
      id: auth_host, allowed_origins: ["https://#{auth_host}"], encoding: :base64url,
    )
    public_credential = WebAuthn::Credential.from_create(registration, relying_party: relying_party)
    passkey = actor.client_passkeys.create!(
      webauthn_id: public_credential.id, public_key: public_credential.public_key, sign_count: 0,
    )
    base_client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.create!(
      authentication_epoch: 0, client_token: root, oidc_client_id: base_client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: 1.minute.ago, refresh_token_expires_at: 1.hour.from_now,
    )
    access = AuthenticationTokenService.encode(
      actor, host: base_host, resource_type: "client", session_public_id: root.public_id,
             base_session_public_id: root.public_id, oidc_sid: grant.public_id, oidc_jti: grant.oidc_jti,
             expires_at: 10.minutes.from_now, scopes: %w(openid profile), issuer: OidcIssuer.for_client(base_client),
             audiences: [base_client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(base_client),
             subject: OidcSubject.for(actor, resource_type: "client"), client_id: base_client.client_id,
    )
    base = open_session
    base.host!(base_host)
    base.https!
    base.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access
    base.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = grant.issue_refresh_token!
    base.cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = AuthenticationToken.encode(
      actor, host: base_host, session_public_id: root.public_id, resource_type: "client",
             jwt_issuer_id: "surface:BASE_APP",
    )
    features.each { |feature| Flipper.disable(feature) }
    auth_entry = open_session
    auth_entry.host!(auth_host)
    auth_entry.https!
    %w(in up).each do |flow|
      auth_entry.get("/sign/#{flow}/sentry", params: { ri: "jp" })

      assert_equal 503, auth_entry.response.status
    end
    base.get(base_app_welcome_path(ri: "jp"))

    assert_equal 200, base.response.status
    assert_includes base.response.body, base_app_dashboard_path(ri: "jp")
    client = OidcClientRegistry.find!("core-app-jp")
    refresh_grant = OpAppGrant.create!(
      authentication_epoch: 0, client_token: root, oidc_client_id: client.client_id, oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 1.hour.from_now,
    )
    refresh = refresh_grant.issue_refresh_token!
    token_url = OidcIssuer.token_endpoint("client")
    assertion = OidcClientAssertionJwt.issue(client_id: client.client_id, token_url: token_url)
    visa = open_session
    visa.host!(visa_host)
    visa.https!
    visa.post(
      "/oauth/token", params: {
        grant_type: "refresh_token",
        refresh_token: refresh,
        client_id: client.client_id,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: assertion,
      },
    )

    assert_equal 200, visa.response.status, visa.response.parsed_body.slice("error", "error_description").inspect
    assert_predicate visa.response.parsed_body.fetch("access_token"), :present?
    assert_predicate visa.response.parsed_body.fetch("refresh_token"), :present?
    refresh_digest = Digest::SHA256.hexdigest(visa.response.parsed_body.fetch("refresh_token"))

    assert_not_equal Digest::SHA256.hexdigest(refresh), refresh_digest
    assert_predicate root.reload, :currently_usable?
    requirement = StepUpRequirement.new(
      scope: "settings_email", allowed_methods: [:passkey], purpose: "step_up", audience: "step_up:app",
      step_up_required: true, phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil, session_binding: root.public_id, token_binding: root.public_id,
      require_session_binding: true,
    )
    nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: root, requirement: requirement, return_to: "/identity/emails/registration/new",
      base_browser_nonce: nonce, base_token: root,
    )
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: root, browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref: binding.entry_ref, nonce: nonce,
      ),
    )
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "step_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    admitted, admitted_sid = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", previous_raw_sid: raw_sid,
      step_up_ceremony_transaction_ref: issuance.transaction.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    locator = SecureRandom.urlsafe_base64(32)
    BaseStepUpMarkerAdapter.new.issue!(
      locator: locator, transaction_ref: issuance.transaction.transaction_id, surface: "app",
      actor_ref: actor.public_id, session_ref: root.public_id, expires_at: issuance.transaction.expires_at,
    )
    jar = ActionDispatch::Cookies::CookieJar.build(ActionDispatch::TestRequest.create, {})
    session_key = Rails.application.config.session_options.fetch(:key)
    jar.encrypted[session_key] = { value: {
      "session_id" => SecureRandom.hex(16),
      "_csrf_token" => SecureRandom.urlsafe_base64(32),
      BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY => nonce,
      "base_step_up_marker_locator" => locator,
    } }
    store_raw_cookies(base.cookies, "#{session_key}=#{Rack::Utils.escape(jar[session_key])}", URI.parse("https://#{base_host}/"))
    auth = open_session
    auth.host!(auth_host)
    auth.https!
    sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    store_raw_cookies(auth.cookies, "#{sid_cookie}=#{Rack::Utils.escape(admitted_sid)}", URI.parse("https://#{auth_host}/"))
    auth.get("/verification/passkey/new", params: { ri: "jp" })

    assert_equal 200, auth.response.status
    page = auth.response.parsed_body
    panel = JSON.parse(page.at_css("script[data-page='app']").text).fetch("props").fetch("panel")
    csrf = page.at_css('meta[name="csrf-token"]')["content"]
    headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin", "X-CSRF-Token" => csrf }
    auth.post(panel.fetch("options_url"), params: { "cf-turnstile-response" => "test" }, headers: headers, as: :json)

    assert_equal 200, auth.response.status
    options = auth.response.parsed_body
    signature = fake.get(challenge: options.fetch("options").fetch("challenge"), user_verified: true, sign_count: 1)
    auth.post(
      panel.fetch("verification_url"), params: { credential: signature, challenge_id: options.fetch("challenge_id") },
                                       headers: headers, as: :json,
    )

    assert_equal 200, auth.response.status
    auth.get(auth.response.parsed_body.fetch("redirect_url"))
    form = auth.response.parsed_body.at_css("form")

    assert form
    auth.post(
      form["action"], params: {
        authenticity_token: form.at_css('input[name="authenticity_token"]')["value"],
      }, headers: headers,
    )

    assert_equal 303, auth.response.status
    completion = URI.parse(auth.response.location)

    assert_equal base_host, completion.host
    base.get(completion.request_uri)

    assert_equal 200, base.response.status
    form = base.response.parsed_body.at_css("form")

    assert form
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(
      form["action"], params: fields, headers: {
        "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
      },
    )

    assert_equal 303, base.response.status
    assert_predicate issuance.transaction.reload, :consumed?
    assert_equal passkey.public_id, root.reload.last_step_up_credential_ref
    assert_predicate StepUpResolver.call(token: root, requirement: requirement), :satisfied?
    assert_predicate admitted.reload, :completed?
  ensure
    previous&.each { |feature, enabled| enabled ? Flipper.enable(feature) : Flipper.disable(feature) }
    ActionController::Base.allow_forgery_protection = protection unless protection.nil?
    if previous_turnstile
      TurnstileVerifierStub.enabled, TurnstileVerifierStub.response,
        TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response = previous_turnstile
    end
  end
end
