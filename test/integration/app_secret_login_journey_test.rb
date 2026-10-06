# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class AppSecretLoginJourneyTest < ActionDispatch::IntegrationTest
  SECRET_LIFETIME_VALUES = {
    "APP_SECRET_ISSUANCE_TTL_SECONDS" => "600",
    "APP_SECRET_PURGE_DELAY_SECONDS" => "86400",
    "APP_SECRET_OUTBOX_RETENTION_SECONDS" => "604800",
    "APP_SECRET_PROOF_RETENTION_SECONDS" => "2592000",
  }.freeze

  setup do
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @previous_lifetimes = ENV.to_h.slice(*SECRET_LIFETIME_VALUES.keys)
    SECRET_LIFETIME_VALUES.each { |key, value| ENV[key] = value }
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    SECRET_LIFETIME_VALUES.each_key do |key|
      @previous_lifetimes.key?(key) ? ENV[key] = @previous_lifetimes.fetch(key) : ENV.delete(key)
    end
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  (0..20).each do |active_count|
    test "signed-in Passkey registration distributes correctly at A=#{active_count}" do
      auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      actor = Client.create!(status_id: ClientStatus::ACTIVE)
      token = ClientToken.create!(
        user: actor, established_authentication_method: "secret", root_login_established_at: ClientToken.database_now,
      )
      BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
      BaseSelectorAuthority.prepare(surface: :app, principal: actor, session: token)
      token.update!(
        last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_passkey",
        last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
        last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
        last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
        last_step_up_credential_ref: "test-step-up", last_step_up_full_reauthentication: false,
      )
      now = Client.database_now
      active_count.times do
        prior = ClientSecretIssuance.create!(
          client: actor, origin: "manual", origin_operation_id: SecureRandom.uuid,
          attempt_number: 1, browser_session_ref: token.public_id, planned_count: 1,
          expires_at: now + 1.minute, presented_at: now, confirmed_at: now,
        )
        raw = SecureRandom.base58(32)
        ClientSecretCredential.create!(
          client: actor, issuance: prior, name: "Existing", password: raw,
          confirmed_at: now,
        )
      end
      base = open_session
      base.host!(base_host)
      base.https!
      install_base_browser_rp!(base, actor: actor, token: token, base_host: base_host)
      base_headers = as_user_headers(actor, host: base_host, session_public_id: token.public_id)
        .except("Cookie", "HTTP_COOKIE").merge(
          "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
        )
      root_access_token = base_headers.fetch("Authorization").delete_prefix("Bearer ")
      base.cookies.merge(
        "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(root_access_token)}",
        URI.parse("https://#{base_host}/"),
      )
      base.get(new_base_app_identity_passkey_path(ri: "jp"), headers: base_headers)

      assert_equal 303, base.response.status, base.response.body
      registration_uri = URI.parse(base.response.location)

      assert_equal auth_host, registration_uri.host
      entry_ref = Rack::Utils.parse_query(registration_uri.query).fetch("entry_ref")
      admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: entry_ref)

      assert_equal admission_binding.base_browser_digest,
                   AuthAdmissionBinding.browser_digest(
                     surface: "app", entry_ref: entry_ref,
                     nonce: base.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY],
                   )
      browser = open_session
      browser.host!(auth_host)
      browser.https!
      auth_headers = {
        "Host" => auth_host, "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin",
      }
      redeem_auth_ceremony_session!(
        browser, registration_uri.path, reference: entry_ref, params: { ri: "jp" },
                                        headers: auth_headers, confirm_via_http: true, base_browser: base,
      )

      assert_equal 303, browser.response.status, browser.response.body
      browser.get(new_auth_app_verification_registration_passkey_path(ri: "jp"), headers: auth_headers)

      assert_equal 200, browser.response.status
      page = JSON.parse(Nokogiri::HTML(browser.response.body).at_css("script[data-page='app']").text)
      panel = page.fetch("props").fetch("panel")
      csrf = Nokogiri::HTML(browser.response.body).at_css('meta[name="csrf-token"]')["content"]
      browser.post(
        panel.fetch("options_url"), params: { "cf-turnstile-response" => "synthetic" },
                                    headers: auth_headers.merge("X-CSRF-Token" => csrf), as: :json,
      )

      assert_equal 200, browser.response.status
      options = browser.response.parsed_body
      fake = WebAuthn::FakeClient.new("https://#{auth_host}", encoding: :base64url)
      credential = fake.create(challenge: options.fetch("options").fetch("challenge"), user_verified: true)
      passkey_count = ClientPasskey.count
      browser.post(
        panel.fetch("verification_url"),
        params: { credential: credential, challenge_id: options.fetch("challenge_id") },
        headers: auth_headers.merge("X-CSRF-Token" => csrf), as: :json,
      )

      assert_equal 201, browser.response.status, browser.response.body
      assert_equal passkey_count, ClientPasskey.count
      handoff_uri = URI.parse(browser.response.parsed_body.fetch("redirect_url"))
      handoff_path = handoff_uri.path
      handoff_path = "#{handoff_path}?#{handoff_uri.query}" if handoff_uri.query.present?
      browser.get(handoff_path, headers: auth_headers)
      handoff_form = Nokogiri::HTML(browser.response.body).at_css("form")
      browser.post(
        handoff_form["action"],
        params: { authenticity_token: handoff_form.at_css('input[name="authenticity_token"]')["value"] },
        headers: auth_headers,
      )

      assert_equal 303, browser.response.status
      completion_uri = URI.parse(browser.response.location)
      base.host!(completion_uri.host)
      base.https!
      base.get(completion_uri.request_uri, headers: base_headers)
      completion_form = Nokogiri::HTML(base.response.body).at_css("form")
      completion_params = completion_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      base.post(completion_form["action"], params: completion_params, headers: base_headers)

      assert_equal 303, base.response.status
      assert_equal passkey_count + 1, ClientPasskey.count
      destination = URI.parse(base.response.location)

      assert_equal base_host, destination.host
      issuance = ClientSecretIssuance.find_by!(client_id: actor.id, origin: "passkey_registration")
      expected_count = [2, 20 - active_count].min

      assert_equal expected_count, issuance.planned_count
      assert_nil issuance.encrypted_payload
      base.get(destination.request_uri, headers: base_headers)

      assert_equal 200, base.response.status
      page = JSON.parse(Nokogiri::HTML(base.response.body).at_css("script[data-page='app']").text)
      csrf = page.fetch("props").fetch("authenticity_token")
      if active_count == 19
        assert_equal I18n.t("base.app.secrets.distribution_one_present"), page.fetch("props").fetch("notice")
      elsif active_count == 20
        assert_equal I18n.t("base.app.secrets.distribution_omitted"), page.fetch("props").fetch("notice")
        assert_nil issuance.reload.encrypted_payload
        assert_nil issuance.expires_at
        assert_equal 0, ClientSecretCredential.where(issuance_id: issuance.id).count
        assert_equal 0, ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).reserved_count
        assert_equal "omitted", page.fetch("props").fetch("state")
        next
      else
        assert_nil page.fetch("props").fetch("notice")
      end
      base.post(
        base_app_secret_issuance_presentation_path(issuance.public_id, ri: "jp"),
        headers: base_headers, params: { authenticity_token: csrf },
      )

      assert_equal 200, base.response.status
      values = Nokogiri::HTML(base.response.body).css("[data-secret-value] code").map(&:text)

      assert_equal expected_count, values.length
      values.each { |value| assert_nil ClientSecretLookupQuery.call(client: actor, secret: value) }
      csrf = Nokogiri::HTML(base.response.body).at_css('input[name="authenticity_token"]')["value"]
      base.patch(
        base_app_secret_issuance_path(issuance.public_id, ri: "jp"),
        headers: base_headers, params: { authenticity_token: csrf, stored: "1" },
      )

      assert_equal 303, base.response.status
      values.each { |value| assert ClientSecretLookupQuery.call(client: actor, secret: value) }
      assert_equal active_count + expected_count,
                   ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).active_count
      base.get(base_app_secret_issuance_path(issuance.public_id, ri: "jp"), headers: base_headers)

      assert_equal 200, base.response.status
      if active_count == 19
        page = JSON.parse(Nokogiri::HTML(base.response.body).at_css("script[data-page='app']").text)

        assert_equal I18n.t("base.app.secrets.distribution_one_confirmed"), page.fetch("props").fetch("notice")
      end
    end
  end

  test "unavailable manual payload retires candidates and releases capacity through the protected HTTP endpoint" do
    [nil, "invalid encrypted payload"].each do |payload|
      base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      actor = Client.create!(status_id: ClientStatus::ACTIVE)
      token = ClientToken.create!(
        user: actor, established_authentication_method: "secret", root_login_established_at: ClientToken.database_now,
      )
      BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
      BaseSelectorAuthority.prepare(surface: :app, principal: actor, session: token)
      token.update!(
        last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
        last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
        last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
        last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
        last_step_up_credential_ref: "test-step-up", last_step_up_full_reauthentication: false,
      )
      context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
      issuance = ClientSecretManualReservationIssuer.call!(
        actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      )
      ClientSecretPresentationIssuer.prepare!(actor_context: context, token: token, issuance: issuance)
      issuance.reload.update!(encrypted_payload: payload)
      base = open_session
      base.host!(base_host)
      base.https!
      install_base_browser_rp!(base, actor: actor, token: token, base_host: base_host)
      headers = {
        "Host" => base_host, "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
      }
      base.get(base_app_secret_issuance_path(issuance.public_id, ri: "jp"), headers: headers)

      assert_equal 200, base.response.status
      page = JSON.parse(Nokogiri::HTML(base.response.body).at_css("script[data-page='app']").text)
      csrf = page.fetch("props").fetch("authenticity_token")
      assert_no_difference "ClientSecretCredential.count" do
        base.post(
          base_app_secret_issuance_presentation_path(issuance.public_id, ri: "jp"),
          headers: headers, params: { authenticity_token: csrf },
        )
      end

      assert_equal 410, base.response.status
      assert_nil issuance.reload.encrypted_payload
      assert_not_nil issuance.canceled_at
      assert_equal ["payload_unavailable"], ClientSecretAuditOutbox.where(
        operation_ref: issuance.origin_operation_id,
        event_name: %w(secret.issuance_canceled secret.discarded),
      ).distinct.pluck(:reason)
      assert_equal 0, ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).reserved_count
      candidate = ClientSecretCredential.find_by!(issuance_id: issuance.id)

      assert_nil candidate.confirmed_at
      assert_not_nil candidate.discard_at
      base.patch(
        base_app_secret_issuance_path(issuance.public_id, ri: "jp"),
        headers: headers, params: { authenticity_token: csrf, stored: "1" },
      )

      assert_equal 403, base.response.status
      assert_nil candidate.reload.confirmed_at
      assert_nil issuance.reload.confirmed_at
    end
  end

  test "manual HTTP delivery and storage confirmation lead to one canonical Base Secret login" do
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    issuer = JitSecurityJwtRegistry.surface("BASE_APP")
    actor = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: "2000-01-01")
    identifier = "secret-login-#{SecureRandom.hex(4)}@example.com"
    actor.client_emails.create!(
      address: identifier, user_email_status_id: ClientEmailStatus::VERIFIED,
    ).finalize_binding!
    fake = WebAuthn::FakeClient.new("https://#{auth_host}", encoding: :base64url)
    registration = fake.create(
      challenge: Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false), user_verified: true,
    )
    relying_party = WebAuthn::RelyingParty.new(
      id: auth_host, allowed_origins: ["https://#{auth_host}"], encoding: :base64url,
    )
    registered = WebAuthn::Credential.from_create(registration, relying_party: relying_party)
    passkey = actor.client_passkeys.create!(
      webauthn_id: registered.id, public_key: registered.public_key, sign_count: 0,
    )
    token = ClientToken.create!(
      user: actor, established_authentication_method: "passkey",
      root_login_established_at: ClientToken.database_now - 1.hour,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
    BaseSelectorAuthority.prepare(surface: :app, principal: actor, session: token)
    # This fixture establishes scoped admission; WebAuthn verification has its own journey tests.
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up", last_step_up_full_reauthentication: false,
    )

    assert_predicate StepUpResolver.call(
      token: token.reload, requirement: StepUpRequirement.new(
        step_up_required: true, scope: "settings_secret_credential", allowed_methods: %i(passkey totp email_otp),
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: StepUpRequirement::DEFAULT_TTL,
        purpose: "step_up", audience: "step_up:app", session_binding: token.public_id,
        token_binding: token.public_id, require_session_binding: true,
        actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      ),
    ), :satisfied?
    base_client = OidcClientRegistry.find!("base-app-ww")
    base_rp_session = ClientRpSession.create!(
      client_token: token, oidc_client_id: base_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: token.root_login_established_at,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    base_rp_access_token = AuthenticationTokenService.encode(
      actor, host: base_host, resource_type: "client", session_public_id: token.public_id,
             base_session_public_id: token.public_id, oidc_sid: base_rp_session.public_id,
             oidc_jti: base_rp_session.oidc_jti, expires_at: 10.minutes.from_now,
             scopes: %w(openid profile), issuer: OidcIssuer.for_client(base_client),
             audiences: [base_client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(base_client),
             subject: OidcSubject.for(actor, resource_type: "client"), client_id: base_client.client_id,
    )
    base_rp_refresh_token = base_rp_session.issue_refresh_token!
    host!(base_host)
    https!
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = base_rp_access_token
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = base_rp_refresh_token
    rp_payload = OidcRpBrowserCredentialContract.decode_access_token(
      token: base_rp_access_token, host: base_host, resource_type: "client", client_id: "base-app-ww",
    )

    assert_predicate rp_payload, :present?
    assert_equal base_rp_session.public_id, AuthorizationTokenClaims.session_id(rp_payload)
    assert_predicate base_rp_session, :active?
    assert_predicate base_rp_session.parent_device_session, :usable?
    assert_equal token.id, base_rp_session.parent_token.id
    headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
    get new_base_app_secret_path(ri: "jp"), headers: headers

    assert_response :success
    page = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text)
    csrf = page.fetch("props").fetch("authenticity_token")
    operation_id = page.fetch("props").fetch("operation_id")
    post base_app_secrets_path(ri: "jp"), params: {
      authenticity_token: csrf, operation_id: operation_id,
    }, headers: headers

    assert_response :see_other
    issuance = ClientSecretIssuance.find_by!(client_id: actor.id)

    assert_equal 1, issuance.planned_count
    assert_nil issuance.confirmed_at
    candidate = ClientSecretCredential.find_by!(issuance_id: issuance.id)
    post base_app_secret_issuance_presentation_path(issuance.public_id, ri: "jp"),
         params: { authenticity_token: csrf }, headers: headers

    assert_response :success
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    assert_equal "no-referrer", response.headers["Referrer-Policy"]
    assert_nil response.headers["X-Inertia"]
    raw = response.parsed_body.at_css("[data-secret-value] code").text

    assert_match(/\A[1-9A-HJ-NP-Za-km-z]{32}\z/, raw)
    assert_nil ClientSecretLookupQuery.call(client: actor, secret: raw)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    patch base_app_secret_issuance_path(issuance.public_id, ri: "jp"),
          params: { authenticity_token: csrf, stored: "1" }, headers: headers

    assert_response :see_other
    assert_equal candidate.id, ClientSecretLookupQuery.call(client: actor, secret: raw).id

    assert_no_difference ["ClientSecretIssuance.count", "ClientSecretCredential.count",
                          "ClientSecretAuditOutbox.count",] do
      post base_app_secrets_path(ri: "jp"), params: { authenticity_token: csrf, operation_id: operation_id },
                                            headers: headers
    end
    assert_redirected_to base_app_secret_issuance_path(issuance.public_id, ri: "jp")

    base = open_session
    auth_uri = app_oidc_auth_target!(base, base_host: base_host)
    entry_ref = Rack::Utils.parse_query(auth_uri.query).fetch("entry_ref")
    authorization = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: entry_ref)
      .authorization_transaction
    browser = open_session
    browser.host!(auth_host)
    browser.https!
    auth_headers = {
      "Host" => auth_host, "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin",
    }
    redeem_auth_ceremony_session!(
      browser, auth_uri.path, reference: entry_ref, params: { ri: "jp" },
                              headers: auth_headers, confirm_via_http: true, base_browser: base,
    )

    assert_equal 303, browser.response.status
    browser.get(new_auth_app_sign_in_secret_path(ri: "jp"))

    assert_equal 200, browser.response.status
    page = JSON.parse(Nokogiri::HTML(browser.response.body).at_css("script[data-page='app']").text)
    csrf = page.fetch("props").fetch("authenticity_token")
    assert_no_difference("ClientToken.count") do
      browser.post(
        auth_app_sign_in_secret_path(ri: "jp"), params: {
          :identifier => identifier, :secret => raw, :authenticity_token => csrf, "cf-turnstile-response" => "synthetic",
        }, headers: auth_headers,
      )
    end
    assert_equal 303, browser.response.status
    assert_nil ClientSecretLookupQuery.call(client: actor, secret: raw)
    browser.follow_redirect!

    assert_equal 302, browser.response.status
    browser.follow_redirect! if browser.response.redirect?

    assert_equal 200, browser.response.status
    csrf = Nokogiri::HTML(browser.response.body).at_css('input[name="authenticity_token"]')["value"]
    browser.post(
      auth_app_sign_oidc_handoff_path(ri: "jp"), params: { authenticity_token: csrf }, headers: auth_headers,
    )

    assert_equal 303, browser.response.status
    result_uri = URI.parse(browser.response.location)
    base.host!(result_uri.host)
    base.https!
    base.get(result_uri.request_uri, headers: { "Host" => result_uri.host })

    assert_equal 200, base.response.status
    result_form = Nokogiri::HTML(base.response.body).at_css("form")
    result_csrf = result_form.at_css('input[name="authenticity_token"]')["value"]
    result = result_form.at_css('input[name="result_ref"]')["value"]
    transaction_ref = result_form.at_css('input[name="transaction_ref"]')["value"]
    base_headers = {
      "Host" => result_uri.host, "Origin" => "https://#{result_uri.host}", "Sec-Fetch-Site" => "same-origin",
    }
    assert_difference("ClientToken.count", 1) do
      base.post(
        result_form["action"],
        params: { result_ref: result, transaction_ref: transaction_ref, authenticity_token: result_csrf },
        headers: base_headers,
      )
    end
    assert_equal 302, base.response.status
    callback_uri = decode_base_jump_target!(base.response.location, base_host: base_host)
    base.host!(callback_uri.host)
    base.https!
    flow = authorization.reload.secret_sign_in_flow
    root = flow.reload.token
    id_token = OidcIdTokenIssuer.call(
      resource: actor,
      client: OidcClientRegistry.find!("base-app-ww"),
      nonce: authorization.reload.nonce,
      auth_time: authorization.authenticated_at,
    )
    rp_client = OidcClientRegistry.find!("base-app-ww")
    rp_session = ClientRpSession.create!(
      client_token: root,
      oidc_client_id: rp_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: authorization.authenticated_at,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    rp_access_token = AuthenticationTokenService.encode(
      actor,
      host: base_host,
      resource_type: "client",
      session_public_id: root.public_id,
      base_session_public_id: root.public_id,
      oidc_sid: rp_session.public_id,
      oidc_jti: rp_session.oidc_jti,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(rp_client),
      audiences: [rp_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
      subject: OidcSubject.for(actor, resource_type: "client"),
      client_id: rp_client.client_id,
    )
    token_result = OidcRpTokenClient::Result.new(
      success: true,
      token_response: {
        access_token: rp_access_token,
        refresh_token: rp_session.issue_refresh_token!,
        id_token: id_token,
        expires_in: 600,
        refresh_token_expires_in: 3600,
      },
      error: nil,
    )
    userinfo_result = OidcRpUserInfoClient::Result.new(
      success: true,
      claims: { "sub" => OidcSubject.for(actor, resource_type: "client") },
      error: nil,
      dependency_failure: false,
    )
    OidcRpTokenClient.stub(:call, token_result) do
      OidcRpUserInfoClient.stub(:call, userinfo_result) do
        base.get(callback_uri.request_uri, headers: { "Host" => callback_uri.host })
      end
    end
    set_cookie = base.response.headers.fetch("Set-Cookie")
    set_cookie = JSON.parse(set_cookie) if set_cookie.is_a?(String) && set_cookie.start_with?("[")

    assert_includes Array(set_cookie).join("\n"), "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}="
    base.cookies.delete(OidcRpBrowserCredentialContract::ACCESS_COOKIE)
    base.cookies.delete(OidcRpBrowserCredentialContract::REFRESH_COOKIE)
    base.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = rp_access_token
    base.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = token_result.token_response.fetch(:refresh_token)
    callback_access_payload = OidcRpBrowserCredentialContract.decode_access_token(
      token: base.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE], host: base_host,
      resource_type: "client", client_id: "base-app-ww",
    )

    assert_equal rp_session.public_id, AuthorizationTokenClaims.session_id(callback_access_payload)

    assert_equal "secret", root.established_authentication_method
    receipt = ClientSecretSignInReceipt.find_by!(operation_id: candidate.reload.claim_operation_id)

    assert_equal root.public_id, receipt.root_token_ref
    assert_equal candidate.public_id, receipt.credential_ref
    assert_equal actor.public_id, receipt.client_ref
    assert candidate.reload.consumed_at
    assert_nil ClientSecretLookupQuery.call(client: actor, secret: raw)
    assert_not_nil base.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_no_difference("ClientToken.count") do
      base.post(
        result_form["action"],
        params: { result_ref: result, transaction_ref: transaction_ref, authenticity_token: result_csrf },
        headers: base_headers,
      )
    end
    assert_nil root.reload.last_step_up_at
    base.get(new_base_app_secret_path(ri: "jp"))

    assert_equal 302, base.response.status
    assert_nil root.reload.last_step_up_at
    base.follow_redirect!
    verification_page = Nokogiri::HTML(base.response.body)
    verification_props = JSON.parse(verification_page.at_css("script[data-page='app']").text).fetch("props")
    intent = verification_props.fetch("form")
    csrf = verification_page.at_css('meta[name="csrf-token"]')["content"]
    original_name = candidate.name
    assert_no_difference -> { ClientSecretIssuance.count + ClientSecretAuditOutbox.count } do
      base.post(
        base_app_secrets_path(ri: "jp"), params: { authenticity_token: csrf },
                                         headers: { "Origin" => "https://#{base_host}" },
      )

      assert_equal 401, base.response.status
      base.patch(
        base_app_secret_path(candidate.public_id, ri: "jp"),
        params: { authenticity_token: csrf, name: "Unauthorized rename" },
        headers: { "Origin" => "https://#{base_host}" },
      )

      assert_equal 401, base.response.status
      base.delete(
        base_app_secret_path(candidate.public_id, ri: "jp"),
        params: { authenticity_token: csrf }, headers: { "Origin" => "https://#{base_host}" },
      )

      assert_equal 401, base.response.status
    end
    assert_equal original_name, candidate.reload.name
    assert_nil candidate.revoked_at
    assert_nil root.reload.last_step_up_at
    base.post(
      intent.fetch("action"), params: {
        scope: intent.fetch("scope"), pt: intent.fetch("pt"), authenticity_token: csrf,
      }, headers: { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" },
    )

    assert_equal 303, base.response.status
    sync_response_cookie!(base, "session")
    rt = Rack::Utils.parse_query(URI.parse(base.response.location).query).fetch("rt")
    step_up_jump, = JWT.decode(
      rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
      algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
      verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
    )
    step_up_target = URI.parse(step_up_jump.fetch("url"))
    admission_ref = Rack::Utils.parse_query(step_up_target.query).fetch("entry_ref")
    step_up_browser = open_session
    step_up_browser.host!(auth_host)
    step_up_browser.https!
    step_up_headers = {
      "Host" => auth_host, "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin",
    }
    redeem_auth_ceremony_session!(
      step_up_browser, step_up_target.path, reference: admission_ref, params: { ri: "jp" },
                                            headers: step_up_headers, confirm_via_http: true, base_browser: base,
    )
    step_up_browser.get(new_auth_app_verification_passkey_path(ri: "jp"))
    step_up_page = Nokogiri::HTML(step_up_browser.response.body)
    panel = JSON.parse(step_up_page.at_css("script[data-page='app']").text).fetch("props").fetch("panel")
    csrf = step_up_page.at_css('meta[name="csrf-token"]')["content"]
    step_up_browser.post(
      panel.fetch("options_url"), params: { "cf-turnstile-response" => "synthetic" },
                                  headers: { "X-CSRF-Token" => csrf, "Origin" => "https://#{auth_host}" }, as: :json,
    )

    assert_equal 200, step_up_browser.response.status
    options = step_up_browser.response.parsed_body
    assertion = fake.get(
      challenge: options.fetch("options").fetch("challenge"), user_present: true, user_verified: true, sign_count: 2,
    )
    step_up_browser.post(
      panel.fetch("verification_url"), params: {
        credential: assertion, challenge_id: options.fetch("challenge_id"),
      }, headers: { "X-CSRF-Token" => csrf, "Origin" => "https://#{auth_host}" }, as: :json,
    )

    assert_equal 200, step_up_browser.response.status
    assert_nil root.reload.last_step_up_at
    step_up_browser.get(step_up_browser.response.parsed_body.fetch("redirect_url"))
    form = Nokogiri::HTML(step_up_browser.response.body).at_css("form")
    step_up_browser.post(
      form["action"], params: {
        authenticity_token: form.at_css('input[name="authenticity_token"]')["value"],
      }, headers: step_up_headers,
    )

    assert_equal 303, step_up_browser.response.status
    completion_uri = URI.parse(step_up_browser.response.location)
    base.host!(completion_uri.host)
    base.https!
    base_headers = {
      "Host" => completion_uri.host,
      "Origin" => "https://#{completion_uri.host}",
      "Sec-Fetch-Site" => "same-origin",
    }
    base.get(completion_uri.request_uri, headers: base_headers)

    assert_equal 200, base.response.status
    form = Nokogiri::HTML(base.response.body).at_css("form")
    completion_params = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    step_up_transaction = ClientStepUpCeremonyTransaction.find_by!(transaction_id: completion_params.fetch("transaction_ref"))
    base.post(
      form["action"], params: completion_params,
                      headers: base_headers,
    )

    assert_equal 303, base.response.status,
                 "#{base.response.body} params=#{completion_params.inspect} tx=#{step_up_transaction.reload.status} " \
                 "token_method=#{root.reload.last_step_up_method.inspect} passkey=#{passkey.reload.sign_count}"
    assert_equal "passkey", root.reload.last_step_up_method
    assert_equal "settings_secret_credential", root.last_step_up_scope
    assert_equal "secret", root.established_authentication_method
    assert_equal 2, passkey.reload.sign_count
    sync_response_cookie!(base, OidcRpBrowserCredentialContract::ACCESS_COOKIE)
    sync_response_cookie!(base, OidcRpBrowserCredentialContract::REFRESH_COOKIE)
    base.get(new_base_app_secret_path(ri: "jp"))

    assert_equal 200, base.response.status
    page = JSON.parse(Nokogiri::HTML(base.response.body).at_css("script[data-page='app']").text)
    csrf = page.fetch("props").fetch("authenticity_token")
    operation_id = page.fetch("props").fetch("operation_id")
    assert_difference("ClientSecretIssuance.count", 1) do
      base.post(
        base_app_secrets_path(ri: "jp"), params: { authenticity_token: csrf, operation_id: operation_id },
                                         headers: { "Origin" => "https://#{base_host}" },
      )
    end
    assert_equal 303, base.response.status
    assert_equal 1, ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).reserved_count
    additional_issuance = ClientSecretIssuance.find_by!(client_id: actor.id, browser_session_ref: root.public_id)
    base.post(
      base_app_secret_issuance_presentation_path(additional_issuance.public_id, ri: "jp"),
      params: { authenticity_token: csrf }, headers: { "Origin" => "https://#{base_host}" },
    )

    assert_equal 200, base.response.status
    presentation = Nokogiri::HTML(base.response.body)
    additional_raw = presentation.at_css("[data-secret-value] code").text
    csrf = presentation.at_css('input[name="authenticity_token"]')["value"]

    assert_nil ClientSecretLookupQuery.call(client: actor, secret: additional_raw)
    base.patch(
      base_app_secret_issuance_path(additional_issuance.public_id, ri: "jp"),
      params: { authenticity_token: csrf, stored: "1" }, headers: { "Origin" => "https://#{base_host}" },
    )

    assert_equal 303, base.response.status
    additional = ClientSecretLookupQuery.call(client: actor, secret: additional_raw)

    assert additional
    base.patch(
      base_app_secret_path(additional.public_id, ri: "jp"),
      params: { authenticity_token: csrf, name: "Saved after independent Step-Up" },
      headers: { "Origin" => "https://#{base_host}" },
    )

    assert_equal 303, base.response.status
    assert_equal "Saved after independent Step-Up", additional.reload.name
    base.delete(
      base_app_secret_path(additional.public_id, ri: "jp"),
      params: { authenticity_token: csrf }, headers: { "Origin" => "https://#{base_host}" },
    )

    assert_equal 303, base.response.status
    assert additional.reload.revoked_at
    assert_nil ClientSecretLookupQuery.call(client: actor, secret: additional_raw)
    assert_equal 0, ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).active_count
    assert_equal ClientTokenStatus::ACTIVE, root.reload.user_token_status_id
    retry_base = open_session
    retry_browser = open_session
    retry_auth_uri = app_oidc_auth_target!(retry_base, base_host: base_host)
    retry_entry_ref = Rack::Utils.parse_query(retry_auth_uri.query).fetch("entry_ref")
    retry_browser.host!(auth_host)
    retry_browser.https!
    retry_auth_headers = {
      "Host" => auth_host, "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin",
    }
    redeem_auth_ceremony_session!(
      retry_browser, retry_auth_uri.path, reference: retry_entry_ref, params: { ri: "us" },
                                          headers: retry_auth_headers, confirm_via_http: true, base_browser: retry_base,
    )

    assert_equal 303, retry_browser.response.status
    retry_browser.get(
      new_auth_app_sign_in_secret_path(ri: "us"),
      headers: retry_auth_headers,
    )

    assert_equal 200, retry_browser.response.status
    page = JSON.parse(Nokogiri::HTML(retry_browser.response.body).at_css("script[data-page='app']").text)
    csrf = page.fetch("props").fetch("authenticity_token")
    assert_no_difference -> { ClientToken.count + ClientSecretSignInReceipt.count } do
      retry_browser.post(
        auth_app_sign_in_secret_path(ri: "us"), params: {
          :secret => raw, :authenticity_token => csrf, "cf-turnstile-response" => "synthetic",
        }, headers: retry_auth_headers,
      )
    end
    assert_equal 422, retry_browser.response.status
    assert_equal 1, ClientSecretSignInReceipt.where(credential_ref: candidate.public_id).count
  end

  private

  def install_base_browser_rp!(browser, actor:, token:, base_host:)
    base_client = OidcClientRegistry.find!("base-app-ww")
    now = ClientRpSession.database_now
    rp_session = ClientRpSession.create!(
      client_token: token,
      oidc_client_id: base_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: token.root_login_established_at || now,
      refresh_token_expires_at: now + 30.minutes,
    )
    access_token = AuthenticationTokenService.encode(
      actor,
      host: base_host,
      resource_type: "client",
      session_public_id: token.public_id,
      base_session_public_id: token.public_id,
      oidc_sid: rp_session.public_id,
      oidc_jti: rp_session.oidc_jti,
      expires_at: now + 10.minutes,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(base_client),
      audiences: [base_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(base_client),
      subject: OidcSubject.for(actor, resource_type: "client"),
      client_id: base_client.client_id,
    )
    browser.cookies.merge(
      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(access_token)}",
      URI.parse("https://#{base_host}/"),
    )
    browser.cookies.merge(
      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_session.issue_refresh_token!)}",
      URI.parse("https://#{base_host}/"),
    )
  end

  def app_oidc_auth_target!(base, base_host:)
    base.host!(base_host)
    base.https!
    base.get("/sign", params: { ri: "jp" })
    csrf = Nokogiri::HTML(base.response.body).at_css('input[name="authenticity_token"]')["value"]
    base.post(
      "/sign", params: { ri: "jp", authenticity_token: csrf }, headers: {
        "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
      },
    )

    target = decode_base_jump_target!(base.response.location, base_host: base_host)

    assert_equal base_host, target.host
    assert_equal "/oauth/authorize", target.path
    base.host!(target.host)
    base.https!
    base.get(target.request_uri)
    form = Nokogiri::HTML(base.response.body).at_css("form#base-authorization-ceremony-start-form")

    assert form
    base.post(
      form["action"],
      params: form.css("input[name]").to_h { |input| [input["name"], input["value"]] },
      headers: { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" },
    )

    decode_base_jump_target!(base.response.location, base_host: base_host)
  end

  def decode_base_jump_target!(location, base_host:)
    gateway = URI.parse(location)
    rt = Rack::Utils.parse_query(gateway.query).fetch("rt")
    issuer = JitSecurityJwtRegistry.surface("BASE_APP")
    payload, = JWT.decode(
      rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
      algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
      verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
    )
    URI.parse(payload.fetch("url"))
  end
end
