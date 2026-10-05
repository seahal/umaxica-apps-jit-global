# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class AppSecretLoginJourneyTest < ActionDispatch::IntegrationTest
  setup do
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @previous_lifetimes = ENV.to_h.slice("APP_SECRET_ISSUANCE_TTL_SECONDS", "APP_SECRET_PURGE_DELAY_SECONDS")
    ENV["APP_SECRET_ISSUANCE_TTL_SECONDS"] = "600"
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "86400"
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    %w(APP_SECRET_ISSUANCE_TTL_SECONDS APP_SECRET_PURGE_DELAY_SECONDS).each do |key|
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
      token = ClientToken.create!(user: actor, established_authentication_method: "secret")
      BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
      BaseSelectorAuthority.prepare(surface: :app, principal: actor, session: token)
      token.update!(
        last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_passkey",
        last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
        last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
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
          lookup_digest: SignSecretLookupDigest.digest(raw), confirmed_at: now,
        )
      end
      headers = as_user_headers(actor, host: auth_host, session_public_id: token.public_id).except("Cookie", "HTTP_COOKIE").merge(
        "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin",
      )
      host!(auth_host)
      https!
      get new_auth_app_settings_passkey_path(ri: "jp"), headers: headers

      assert_response :success
      csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      post auth_app_settings_passkeys_options_path(ri: "jp"), headers: headers.merge("X-CSRF-Token" => csrf),
                                                              params: { "cf-turnstile-response" => "synthetic" }, as: :json

      assert_response :success
      options = response.parsed_body
      fake = WebAuthn::FakeClient.new("https://#{auth_host}", encoding: :base64url)
      credential = fake.create(challenge: options.fetch("options").fetch("challenge"), user_verified: true)
      passkey_count = ClientPasskey.count
      post auth_app_settings_passkeys_verification_path(ri: "jp"), headers: headers.merge("X-CSRF-Token" => csrf),
                                                                   params: { credential: credential, challenge_id: options.fetch("challenge_id") }, as: :json

      assert_response :created, response.body
      assert_equal passkey_count + 1, ClientPasskey.count
      destination = URI.parse(response.parsed_body.fetch("redirect_url"))

      assert_equal base_host, destination.host
      issuance = ClientSecretIssuance.find_by!(client_id: actor.id, origin: "passkey_registration")
      expected_count = [2, 20 - active_count].min

      assert_equal expected_count, issuance.planned_count
      assert_nil issuance.encrypted_payload
      host!(base_host)
      headers = as_user_headers(actor, host: base_host, session_public_id: token.public_id).except("Cookie", "HTTP_COOKIE").merge(
        "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
      )
      get destination.request_uri, headers: headers

      assert_response :success
      page = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text)
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
      post base_app_secret_issuance_presentation_path(issuance.public_id, ri: "jp"),
           headers: headers, params: { authenticity_token: csrf }

      assert_response :success
      values = response.parsed_body.css("[data-secret-value] code").map(&:text)

      assert_equal expected_count, values.length
      values.each { |value| assert_nil ClientSecretLookupQuery.call(secret: value) }
      csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      patch base_app_secret_issuance_path(issuance.public_id, ri: "jp"),
            headers: headers, params: { authenticity_token: csrf, stored: "1" }

      assert_response :see_other
      values.each { |value| assert ClientSecretLookupQuery.call(secret: value) }
      assert_equal active_count + expected_count,
                   ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).active_count
      get base_app_secret_issuance_path(issuance.public_id, ri: "jp"), headers: headers

      assert_response :success
      if active_count == 19
        page = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text)

        assert_equal I18n.t("base.app.secrets.distribution_one_confirmed"), page.fetch("props").fetch("notice")
      end
    end
  end

  test "unavailable manual payload retires candidates and releases capacity through the protected HTTP endpoint" do
    [nil, "invalid encrypted payload"].each do |payload|
      base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      actor = Client.create!(status_id: ClientStatus::ACTIVE)
      token = ClientToken.create!(user: actor, established_authentication_method: "secret")
      BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
      BaseSelectorAuthority.prepare(surface: :app, principal: actor, session: token)
      token.update!(
        last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
        last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
        last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
      )
      context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
      issuance = ClientSecretManualReservationIssuer.call!(
        actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      )
      ClientSecretPresentationIssuer.prepare!(actor_context: context, token: token, issuance: issuance)
      issuance.reload.update!(encrypted_payload: payload)
      headers = as_user_headers(actor, host: base_host, session_public_id: token.public_id)
        .except("Cookie", "HTTP_COOKIE").merge(
        "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
      )
      host!(base_host)
      https!
      get base_app_secret_issuance_path(issuance.public_id, ri: "jp"), headers: headers

      assert_response :success
      page = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text)
      csrf = page.fetch("props").fetch("authenticity_token")
      assert_no_difference "ClientSecretCredential.count" do
        post base_app_secret_issuance_presentation_path(issuance.public_id, ri: "jp"),
             headers: headers, params: { authenticity_token: csrf }
      end

      assert_response :gone
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
      patch base_app_secret_issuance_path(issuance.public_id, ri: "jp"),
            headers: headers, params: { authenticity_token: csrf, stored: "1" }

      assert_response :forbidden
      assert_nil candidate.reload.confirmed_at
      assert_nil issuance.reload.confirmed_at
    end
  end

  test "manual HTTP delivery and storage confirmation lead to one canonical Base Secret login" do
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    actor = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: "2000-01-01")
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
    token = ClientToken.create!(user: actor, established_authentication_method: "passkey")
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
    BaseSelectorAuthority.prepare(surface: :app, principal: actor, session: token)
    # This fixture establishes scoped admission; WebAuthn verification has its own journey tests.
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )

    assert_predicate StepUpResolver.call(
      token: token.reload, requirement: StepUpRequirement.new(
        scope: "settings_secret_credential", purpose: "step_up", audience: "step_up:app",
        session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
      ),
    ), :satisfied?
    headers = as_user_headers(actor, host: base_host, session_public_id: token.public_id).except("Cookie", "HTTP_COOKIE").merge(
      "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
    )
    host!(base_host)
    https!
    get new_base_app_secret_path(ri: "jp"), headers: headers

    assert_response :success
    page = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text)
    csrf = page.fetch("props").fetch("authenticity_token")
    post base_app_secrets_path(ri: "jp"), params: { authenticity_token: csrf }, headers: headers

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
    assert_nil ClientSecretLookupQuery.call(secret: raw)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    patch base_app_secret_issuance_path(issuance.public_id, ri: "jp"),
          params: { authenticity_token: csrf, stored: "1" }, headers: headers

    assert_response :see_other
    assert_equal candidate.id, ClientSecretLookupQuery.call(secret: raw).id

    assert_no_difference ["ClientSecretIssuance.count", "ClientSecretCredential.count", "ClientSecretAuditOutbox.count"] do
      post base_app_secrets_path(ri: "jp"), params: { authenticity_token: csrf }, headers: headers
    end
    assert_redirected_to base_app_secret_issuance_path(issuance.public_id)

    base = open_session
    base.host!(base_host)
    base.https!
    base.get("/sign", params: { ri: "jp" })
    csrf = Nokogiri::HTML(base.response.body).at_css('input[name="authenticity_token"]')["value"]
    base.post(
      "/sign", params: { ri: "jp", authenticity_token: csrf }, headers: {
        "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
      },
    )
    rt = Rack::Utils.parse_query(URI.parse(base.response.location).query).fetch("rt")
    issuer = JitSecurityJwtRegistry.surface("BASE_APP")
    payload, = JWT.decode(
      rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
      algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
      verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
    )
    target = URI.parse(payload.fetch("url"))
    entry_ref = Rack::Utils.parse_query(target.query).fetch("entry_ref")
    flow = ClientSignInFlow.find_by!(public_id: entry_ref)
    browser = open_session
    browser.host!(auth_host)
    browser.https!
    browser.get(target.request_uri)
    csrf = Nokogiri::HTML(browser.response.body).at_css('input[name="authenticity_token"]')["value"]
    browser.post(
      auth_app_sign_in_path(ri: "jp"), params: { entry_ref: entry_ref, authenticity_token: csrf },
                                       headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" },
    )
    browser.get(new_auth_app_sign_in_secret_path(ri: "jp"))

    assert_equal 200, browser.response.status
    page = JSON.parse(Nokogiri::HTML(browser.response.body).at_css("script[data-page='app']").text)
    csrf = page.fetch("props").fetch("authenticity_token")
    assert_no_difference("ClientToken.count") do
      browser.post(
        auth_app_sign_in_secret_path(ri: "jp"), params: {
          :secret => raw, :authenticity_token => csrf, "cf-turnstile-response" => "synthetic",
        }, headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" },
      )
    end
    assert_equal 303, browser.response.status
    assert_nil ClientSecretLookupQuery.call(secret: raw)
    browser.follow_redirect!
    browser.follow_redirect! if browser.response.redirect?
    csrf = Nokogiri::HTML(browser.response.body).at_css('input[name="authenticity_token"]')["value"]
    browser.post(
      auth_app_sign_handoff_path(ri: "jp"), params: { authenticity_token: csrf },
                                            headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" },
    )

    assert_equal 200, browser.response.status
    result = Nokogiri::HTML(browser.response.body).at_css('input[name="result"]')["value"]
    assert_difference("ClientToken.count", 1) do
      base.post(
        base_app_sign_completion_path(ri: "jp"), params: { result: result, transaction_ref: flow.public_id },
                                                 headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-site" },
      )
    end
    assert_equal 303, base.response.status
    root = flow.reload.token

    assert_equal "secret", root.established_authentication_method
    receipt = ClientSecretSignInReceipt.find_by!(operation_id: candidate.reload.claim_operation_id)

    assert_equal root.public_id, receipt.root_token_ref
    assert_equal candidate.public_id, receipt.credential_ref
    assert_equal actor.public_id, receipt.client_ref
    assert candidate.reload.consumed_at
    assert_nil ClientSecretLookupQuery.call(secret: raw)
    assert_not_nil base.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_no_difference("ClientToken.count") do
      base.post(
        base_app_sign_completion_path(ri: "jp"), params: { result: result, transaction_ref: flow.public_id },
                                                 headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-site" },
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
    step_up_browser.get(step_up_target.request_uri)
    csrf = Nokogiri::HTML(step_up_browser.response.body).at_css('input[name="authenticity_token"]')["value"]
    step_up_browser.post(
      auth_app_verification_path(ri: "jp"), params: {
        entry_ref: admission_ref, authenticity_token: csrf,
      }, headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" },
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
      }, headers: { "Origin" => "https://#{auth_host}" },
    )
    form = Nokogiri::HTML(step_up_browser.response.body).at_css("form")
    base.post(
      form["action"], params: form.css("input[name]").to_h { |input| [input["name"], input["value"]] },
                      headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-site" },
    )

    assert_equal 303, base.response.status
    assert_equal "passkey", root.reload.last_step_up_method
    assert_equal "settings_secret_credential", root.last_step_up_scope
    assert_equal "secret", root.established_authentication_method
    assert_equal 2, passkey.reload.sign_count
    base.get(new_base_app_secret_path(ri: "jp"))

    assert_equal 200, base.response.status
    page = JSON.parse(Nokogiri::HTML(base.response.body).at_css("script[data-page='app']").text)
    csrf = page.fetch("props").fetch("authenticity_token")
    assert_difference("ClientSecretIssuance.count", 1) do
      base.post(
        base_app_secrets_path(ri: "jp"), params: { authenticity_token: csrf },
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

    assert_nil ClientSecretLookupQuery.call(secret: additional_raw)
    base.patch(
      base_app_secret_issuance_path(additional_issuance.public_id, ri: "jp"),
      params: { authenticity_token: csrf, stored: "1" }, headers: { "Origin" => "https://#{base_host}" },
    )

    assert_equal 303, base.response.status
    additional = ClientSecretLookupQuery.call(secret: additional_raw)

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
    assert_nil ClientSecretLookupQuery.call(secret: additional_raw)
    assert_equal 0, ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).active_count
    assert_equal ClientTokenStatus::ACTIVE, root.reload.user_token_status_id
    retry_entry = BaseAuthAdmissionCoordinator.issue_local_entry!(surface: "app", intent: "sign_in")
    retry_browser = open_session
    retry_browser.host!(auth_host)
    retry_browser.https!
    retry_browser.get(auth_app_sign_in_path(ri: "us", entry_ref: retry_entry.reference))
    csrf = Nokogiri::HTML(retry_browser.response.body).at_css('input[name="authenticity_token"]')["value"]
    retry_browser.post(
      auth_app_sign_in_path(ri: "us"), params: {
        entry_ref: retry_entry.reference, authenticity_token: csrf,
      }, headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" },
    )
    retry_browser.get(new_auth_app_sign_in_secret_path(ri: "us"))

    assert_equal 200, retry_browser.response.status
    page = JSON.parse(Nokogiri::HTML(retry_browser.response.body).at_css("script[data-page='app']").text)
    csrf = page.fetch("props").fetch("authenticity_token")
    assert_no_difference -> { ClientToken.count + ClientSecretSignInReceipt.count } do
      retry_browser.post(
        auth_app_sign_in_secret_path(ri: "us"), params: {
          :secret => raw, :authenticity_token => csrf, "cf-turnstile-response" => "synthetic",
        }, headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" },
      )
    end
    assert_equal 422, retry_browser.response.status
    assert_equal 1, ClientSecretSignInReceipt.where(credential_ref: candidate.public_id).count
  end
end
