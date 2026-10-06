# frozen_string_literal: true

require "test_helper"

class TotpRegistrationBoundaryTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  fixtures :clients, :client_statuses, :client_email_statuses, :visitor_statuses, :operator_statuses

  teardown do
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "registration pages reject missing continuity and ordinary step-up admission" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    get new_auth_app_settings_totp_path(ri: "jp")

    assert_response :bad_request
    get new_auth_app_verification_setup_path(ri: "jp")

    assert_response :bad_request
    actor = Client.create!(id: 9_106_000_000_000, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    issuance = issue_base_step_up_admission!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        step_up_required: true, scope: "settings_birthdate", purpose: "step_up", allowed_methods: [:totp],
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, audience: "step_up:app",
        session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
        actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      ), return_to: "/identity/birthdate", base_browser_nonce: "test-browser-nonce", base_token: token,
    )
    get auth_app_verification_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_verification_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }
    assert_no_difference("IdentityTotpCeremonyCandidate.count") do
      get new_auth_app_settings_totp_path(ri: "jp")

      assert_response :bad_request
      post auth_app_settings_totps_enrollment_path(ri: "jp"), params: { authenticity_token: csrf }

      assert_response :bad_request
    end
    assert_equal "pending", issuance.transaction.reload.status
  end

  test "setup admission refuses a cross-site POST before consuming its reference" do
    original_protection = Auth::App::Verification::SetupsController.allow_forgery_protection
    actor = Client.create!(id: 9_106_000_000_001, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    issuance = issue_base_step_up_admission!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, allowed_methods: [:totp], audience: "step_up:app",
        session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
        actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      ), return_to: "/identity/birthdate", base_browser_nonce: "test-browser-nonce", base_token: token,
    )
    Auth::App::Verification::SetupsController.allow_forgery_protection = true
    host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    https!
    install_confirmed_auth_admission_cookie!(
      self, issuance: issuance, base_token: token, host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
    )
    get(new_auth_app_verification_setup_path(ri: "jp", entry_ref: issuance.reference))
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    assert_no_difference("ClientAuthCeremonySession.count") do
      post(
        auth_app_verification_setup_path(ri: "jp"),
        params: { entry_ref: issuance.reference, authenticity_token: csrf },
        headers: { "Origin" => "https://outside.invalid", "Sec-Fetch-Site" => "cross-site" },
      )

      assert_response :unprocessable_content
    end
    post(
      auth_app_verification_setup_path(ri: "jp"),
      params: { entry_ref: issuance.reference, authenticity_token: csrf },
      headers: { "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-site" },
    )

    assert_response :see_other
    assert_equal "pending", issuance.transaction.reload.status
  ensure
    Auth::App::Verification::SetupsController.allow_forgery_protection = original_protection
  end

  # The candidate, registration proof and Base credential must remain distinct across requests.
  # rubocop:disable Minitest/MultipleAssertions
  test "admitted bootstrap confirms a DB TOTP candidate without Auth root credentials or freshness" do
    actor = Client.create!(id: 9_106_000_000_002, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    issuance = issue_base_step_up_admission!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, allowed_methods: [:totp], audience: "step_up:app",
        session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
        actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      ), return_to: "/identity/birthdate", base_browser_nonce: "test-browser-nonce", base_token: token,
    )
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    install_confirmed_auth_admission_cookie!(
      self, issuance: issuance, base_token: token, host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
    )
    get new_auth_app_verification_setup_path(ri: "jp", entry_ref: issuance.reference)

    assert_response :success
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]

    assert_nil ClientAuthCeremonySession.find_by(step_up_ceremony_transaction_ref: issuance.transaction.transaction_id)
    post auth_app_verification_setup_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }

    # Base admitted TOTP only, so Auth goes straight to its enrollment; the method choice is Base's.
    assert_redirected_to new_auth_app_settings_totp_path(ri: "jp")
    follow_redirect!

    assert_response :success
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")

    assert_nil props.fetch("qr_code_image")
    assert_no_difference("ClientTotpCredential.count") do
      post props.fetch("start").fetch("action"), params: { authenticity_token: csrf }
      follow_redirect!
    end
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    candidate = IdentityTotpCeremonyCandidate.find_by!(ref: props.fetch("form").fetch("enrollment_id"))

    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    assert props.fetch("qr_code_image").start_with?("data:image/png;base64,")
    assert_equal issuance.transaction.transaction_id, candidate.step_up_ceremony_transaction_ref
    assert_nil session[:totp_enrollment]
    assert_nil session[:private_key]
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    now = ClientStepUpCeremonyTransaction.database_now
    assert_no_difference("ClientTotpCredential.count") do
      ClientStepUpCeremonyTransaction.stub(:database_now, now) do
        post props.fetch("form").fetch("action"), params: {
          :authenticity_token => csrf,
          :user_totp_credential => { enrollment_id: candidate.ref,
                                     title: "My app",
                                     first_token: ROTP::TOTP.new(candidate.private_key).at(now.to_i), },
          "cf-turnstile-response" => "test-only",
        }
      end
    end

    assert_redirected_to auth_app_settings_totps_handoff_path(ri: "jp")
    follow_redirect!
    post auth_app_settings_totps_handoff_path(ri: "jp"), params: { authenticity_token: csrf }

    assert_response :see_other
    result = Rack::Utils.parse_nested_query(URI.parse(response.location).query)
    credential = IdentityTotpEnrollmentFinalCommitter.call!(
      actor: actor, token: token, transaction: issuance.transaction.reload,
      result_reference: result.fetch("result_ref"),
    )

    assert_equal actor.id, credential.user_id
    assert_equal "My app", credential.title
    assert_equal "consumed", issuance.transaction.reload.status
    assert_nil token.reload.last_step_up_at
    assert_nil cookies[AuthenticationCookieName.access]
    assert_nil cookies[AuthenticationCookieName.refresh]
  end
  # rubocop:enable Minitest/MultipleAssertions

  # Each surface redeems its own permission and limits registration to its method matrix.
  # rubocop:disable Minitest/MultipleAssertions
  test "COM and ORG setup admit only their actor-specific Passkey registration permission" do
    %w(com org).each do |surface|
      case surface
      when "com"
        actor = Visitor.create!(status_id: VisitorStatus::ACTIVE)
        token = VisitorToken.create!(visitor: actor, root_login_established_at: Time.current)
        auth_host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
        display_path = new_auth_com_verification_setup_path(ri: "jp")
        create_path = auth_com_verification_setup_path(ri: "jp")
        cancel_path = auth_com_verification_cancellation_path(ri: "jp")
        base_host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
      when "org"
        actor = Operator.create!(status_id: OperatorStatus::ACTIVE)
        token = OperatorToken.create!(staff: actor, root_login_established_at: Time.current)
        auth_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
        display_path = new_auth_org_verification_setup_path(ri: "jp")
        create_path = auth_org_verification_setup_path(ri: "jp")
        cancel_path = auth_org_verification_cancellation_path(ri: "jp")
        base_host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
      end
      issuance = issue_base_step_up_admission!(
        actor: actor, token: token,
        requirement: StepUpRequirement.new(
          scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
          phishing_resistant_required: false, user_verification_required: false,
          full_reauthentication_required: false, ttl: 15.minutes, allowed_methods: [:passkey], audience: "step_up:#{surface}",
          session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
          actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
        ), return_to: "/identity/birthdate", base_browser_nonce: "test-browser-nonce", base_token: token,
      )
      browser = open_session
      browser.host!(auth_host)
      install_confirmed_auth_admission_cookie!(
        browser, issuance: issuance, base_token: token, host: auth_host, surface: surface,
      )
      browser.get(display_path, params: { entry_ref: issuance.reference })
      csrf = Nokogiri::HTML(browser.response.body).at_css('input[name="authenticity_token"]')["value"]
      browser.post(create_path, params: { entry_ref: issuance.reference, authenticity_token: csrf })

      assert_equal 303, browser.response.status
      browser.follow_redirect!

      assert_equal 200, browser.response.status
      page = JSON.parse(Nokogiri::HTML(browser.response.body).at_css("script[data-page='app']").text)
      props = page.fetch("props")

      assert_equal "auth/#{surface}/verification/registration/passkeys/new", page.fetch("component")
      assert_equal(
        public_send("auth_#{surface}_verification_registration_passkey_options_path", ri: "jp"),
        props.fetch("panel").fetch("options_url"),
      )
      assert_equal(
        public_send("auth_#{surface}_verification_registration_passkey_path", ri: "jp"),
        props.fetch("panel").fetch("verification_url"),
      )
      assert_nil props.fetch("panel").fetch("challenge_id", nil)
      assert_nil browser.cookies[AuthenticationCookieName.access]
      assert_nil browser.cookies[AuthenticationCookieName.refresh]
      assert_nil token.reload.last_step_up_at
      destination = nil
      JumpRtIssuer.stub(:call, ->(**args) { destination = args.fetch(:url); "opaque-jump" }) do
        RedirectsJumpGatewayUrl.stub(
          :call, ->(_code) { RedirectsTargetResult.ok(kind: :external, source: :test, value: destination) },
        ) do
          browser.post(cancel_path, params: { authenticity_token: csrf })
        end
      end

      assert_equal 303, browser.response.status
      assert_equal base_host, URI.parse(browser.response.location).host
      assert_nil destination
      assert_equal "pending", issuance.transaction.reload.status
    end
  end
  # rubocop:enable Minitest/MultipleAssertions

  # A failure and redisplay must retain the same candidate and the same authority deadline.
  # rubocop:disable Minitest/MultipleAssertions
  test "GET and repeated start preserve enrollment deadline and failures while cancel closes the permission" do
    actor = Client.create!(id: 9_106_000_000_003, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    issuance = issue_base_step_up_admission!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, allowed_methods: [:totp], audience: "step_up:app",
        session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
        actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      ), return_to: "/identity/birthdate", base_browser_nonce: "test-browser-nonce", base_token: token,
    )
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    install_confirmed_auth_admission_cookie!(
      self, issuance: issuance, base_token: token, host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
    )
    get new_auth_app_verification_setup_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_verification_setup_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }
    assert_no_difference("IdentityTotpCeremonyCandidate.count") do
      get new_auth_app_settings_totp_path(ri: "jp")
      get new_auth_app_settings_totp_path(ri: "jp")
    end
    post auth_app_settings_totps_enrollment_path(ri: "jp"), params: { authenticity_token: csrf }
    child = ClientTotpCeremonyTransaction.find_by!(
      step_up_ceremony_transaction_ref: issuance.transaction.transaction_id,
    )
    candidate = IdentityTotpCeremonyCandidate.find_by!(ref: child.credential_candidate_ref)
    deadline = candidate.expires_at
    digest = candidate.digest
    record = ClientStepUpSession.find_by!(step_up_ceremony_transaction_ref: issuance.transaction.transaction_id)
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    ["12345", "1234567", ""].each_with_index do |code, index|
      post auth_app_settings_totps_path(ri: "jp"), params: {
        :authenticity_token => csrf,
        :user_totp_credential => { enrollment_id: candidate.ref, title: "App", first_token: code },
        "cf-turnstile-response" => "test-only",
      }

      assert_response :unprocessable_content
      assert_equal index + 1, record.reload.attempt_count
      post auth_app_settings_totps_enrollment_path(ri: "jp"), params: { authenticity_token: csrf }

      assert_response :see_other
      get new_auth_app_settings_totp_path(ri: "jp")

      assert_response :success
      assert_equal deadline, candidate.reload.expires_at
      assert_equal digest, candidate.digest
      assert_equal index + 1, record.reload.attempt_count
      assert_equal candidate.ref, child.reload.credential_candidate_ref
    end
    destination = nil
    JumpRtIssuer.stub(:call, ->(**args) { destination = args.fetch(:url); "opaque-jump" }) do
      RedirectsJumpGatewayUrl.stub(
        :call, ->(_code) { RedirectsTargetResult.ok(kind: :external, source: :test, value: destination) },
      ) do
        delete auth_app_settings_totps_enrollment_path(ri: "jp"), params: { authenticity_token: csrf }
      end
    end

    assert_response :see_other
    assert_equal URI.parse(
      base_app_dashboard_url(
        ri: "jp", host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
        protocol: "https",
      ),
    ).path, URI.parse(destination).path
    assert_equal "canceled", issuance.transaction.reload.status
    get new_auth_app_settings_totp_path(ri: "jp")

    assert_response :bad_request
    assert_nil candidate.reload.last_otp_at
    assert_nil token.reload.last_step_up_at
  end
  # rubocop:enable Minitest/MultipleAssertions

  # This journey starts from a real Base Browser-RP session. Root issuance itself is covered by
  # the root-login integration boundary; this case focuses on bootstrap admission and completion.
  # rubocop:disable Minitest/MultipleAssertions
  test "Base begins bootstrap from its own root session and returns TOTP registration without freshness" do
    actor = Client.create!(id: 9_106_000_000_004, status_id: ClientStatus::ACTIVE)
    actor.client_emails.create!(address: "bootstrap-http@example.com")
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    base_client = OidcClientRegistry.find!("base-app-ww")
    token = ClientToken.create!(
      user: actor, established_authentication_method: "email",
      root_login_established_at: ClientToken.database_now,
    )
    rp_session = ClientRpSession.create!(
      client_token: token, oidc_client_id: base_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: token.root_login_established_at, refresh_token_expires_at: 10.minutes.from_now,
    )
    rp_access_token = AuthenticationTokenService.encode(
      actor,
      host: base_host, resource_type: "client", session_public_id: token.public_id,
      base_session_public_id: token.public_id, oidc_sid: rp_session.public_id,
      oidc_jti: rp_session.oidc_jti, expires_at: 10.minutes.from_now,
      scopes: %w(openid profile), issuer: OidcIssuer.for_client(base_client), audiences: [base_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(base_client),
      subject: OidcSubject.for(actor, resource_type: "client"), client_id: base_client.client_id,
    )
    host! base_host
    https!
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = rp_access_token
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = rp_session.issue_refresh_token!
    root_access_token = as_user_headers(actor, host: base_host, session_public_id: token.public_id)
      .fetch("Authorization").delete_prefix("Bearer ")
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = root_access_token
    get base_app_identity_birthdate_path(ri: "jp")

    assert_response :redirect
    assert_equal base_app_verification_setup_path, URI.parse(response.location).path
    follow_redirect!

    assert_response :success
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    auth = open_session
    auth.host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    auth.https!
    auth_headers = {
      "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
      "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
      "Sec-Fetch-Site" => "same-origin",
    }

    assert_equal 0, ClientStepUpCeremonyTransaction.where(session_ref: token.public_id).count
    destination = nil
    JumpRtIssuer.stub(:call, ->(**args) { destination = args.fetch(:url); "opaque-jump" }) do
      RedirectsJumpGatewayUrl.stub(
        :call, ->(_code) { RedirectsTargetResult.ok(kind: :external, source: :test, value: destination) },
      ) do
        post props.fetch("form").fetch("action"),
             params: props.fetch("form").slice("scope", "pt").merge("registration_method" => "totp")
      end
    end

    assert_response :see_other
    assert_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), URI.parse(destination).host
    assert_equal "/verification/setup/new", URI.parse(destination).path
    assert_nil token.reload.last_step_up_at
    destination_uri = URI.parse(destination)
    entry = Rack::Utils.parse_nested_query(destination_uri.query).fetch("entry_ref")
    auth.get(destination_uri.path, params: { entry_ref: entry, ri: "jp" }, headers: auth_headers)
    continuation = Nokogiri::HTML(auth.response.body).at_css("form")
    continuation_hidden =
      continuation.css("input[type='hidden']").to_h do |input|
        [input["name"], input["value"]]
      end
    continuation_token = continuation_hidden.delete("authenticity_token")
    auth.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] = "test-browser-nonce"
    auth.post(
      continuation["action"],
      params: continuation_hidden.merge("authenticity_token" => continuation_token), headers: auth_headers,
    )
    binding_uri = URI.parse(auth.response.location)
    _binding = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
      surface: "app", reference: binding_uri.path.split("/").fetch(-2),
    )
    host! binding_uri.host
    https!
    session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||= "test-browser-nonce"
    base_headers = {
      "Host" => binding_uri.host, "Origin" => "https://#{binding_uri.host}", "Sec-Fetch-Site" => "same-origin",
    }
    get binding_uri.request_uri, headers: base_headers

    assert_equal 200, response.status
    confirmation = response.parsed_body.at_css("form")
    confirmation_hidden =
      confirmation.css("input[type='hidden']").to_h do |input|
        [input["name"], input["value"]]
      end
    confirmation_token = confirmation_hidden.delete("authenticity_token")
    post(
      confirmation["action"],
      params: confirmation_hidden.merge("authenticity_token" => confirmation_token), headers: base_headers,
    )
    sync_response_cookie!(self, "session")
    auth_uri = URI.parse(response.location)
    auth_query = Rack::Utils.parse_nested_query(auth_uri.query.to_s)
    auth_query["ri"] ||= "jp"
    auth_uri.query = URI.encode_www_form(auth_query)
    auth.host!(auth_uri.host)
    auth.https!
    auth.get(auth_uri.request_uri, headers: auth_headers.merge("Host" => auth_uri.host))

    assert_equal 200, auth.response.status
    final = Nokogiri::HTML(auth.response.body).at_css("form")
    final_hidden = final.css("input[type='hidden']").to_h { |input| [input["name"], input["value"]] }
    final_token = final_hidden.delete("authenticity_token")
    auth.post(final["action"], params: final_hidden.merge("authenticity_token" => final_token), headers: auth_headers)

    assert_equal 303, auth.response.status
    auth.get(new_auth_app_settings_totp_path(ri: "jp"))

    assert_equal 200, auth.response.status
    csrf = continuation_token
    auth.post(
      auth_app_settings_totps_enrollment_path(ri: "jp"), params: { authenticity_token: csrf },
                                                         headers: auth_headers,
    )
    auth.follow_redirect!
    props = JSON.parse(Nokogiri::HTML(auth.response.body).at_css("script[data-page='app']").text).fetch("props")
    candidate = IdentityTotpCeremonyCandidate.find_by!(ref: props.fetch("form").fetch("enrollment_id"))
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    now = ClientStepUpCeremonyTransaction.database_now
    ClientStepUpCeremonyTransaction.stub(:database_now, now) do
      auth.post(
        auth_app_settings_totps_path(ri: "jp"), params: {
          :authenticity_token => csrf,
          :user_totp_credential => { enrollment_id: candidate.ref,
                                     title: "Bootstrap authenticator",
                                     first_token: ROTP::TOTP.new(candidate.private_key).at(now.to_i), },
          "cf-turnstile-response" => "test-only",
        },
      )
    end

    assert_equal 303, auth.response.status
    auth.follow_redirect!
    auth.post(auth_app_settings_totps_handoff_path(ri: "jp"), params: { authenticity_token: csrf })

    assert_equal 303, auth.response.status
    completion_uri = URI.parse(auth.response.location)
    host! completion_uri.host
    https!
    get completion_uri.request_uri
    completion_form = response.parsed_body.at_css("form")
    completion = completion_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    completion_headers = {
      "Origin" => "https://#{completion_uri.host}", "Sec-Fetch-Site" => "same-origin",
    }
    stranger = open_session
    stranger.host!(completion_uri.host)
    stranger.https!
    assert_no_difference("ClientTotpCredential.count") do
      stranger.post(completion_form["action"], params: completion, headers: completion_headers)
    end

    assert_equal 302, stranger.response.status
    assert_difference("ClientTotpCredential.count", 1) do
      post completion_form["action"], params: completion, headers: completion_headers
    end

    assert_response :see_other
    assert_equal "/identity/birthdate", URI.parse(response.location).path
    assert_nil token.reload.last_step_up_at
    assert_no_difference("ClientTotpCredential.count") do
      post base_app_verification_completion_path(ri: "jp"), params: completion, headers: completion_headers
    end

    assert_equal 303, response.status
    follow_redirect!

    assert_response :redirect
    assert_equal "/verification", URI.parse(response.location).path
    follow_redirect!
    verification_page = response.parsed_body.at_css("script[data-page='app']")

    assert_equal 200, response.status
    assert_not_nil verification_page
    props = JSON.parse(verification_page.text).fetch("props")
    JumpRtIssuer.stub(:call, ->(**args) { destination = args.fetch(:url); "opaque-jump" }) do
      RedirectsJumpGatewayUrl.stub(
        :call, ->(_code) { RedirectsTargetResult.ok(kind: :external, source: :test, value: destination) },
      ) do
        post props.fetch("form").fetch("action"), params: props.fetch("form").slice("scope", "pt")
      end
    end

    assert_response :see_other
    assert_equal "/verification", URI.parse(destination).path
    assert_nil token.reload.last_step_up_at
    assert_nil auth.cookies[AuthenticationCookieName.access]
    entry = Rack::Utils.parse_nested_query(URI.parse(destination).query).fetch("entry_ref")
    redeem_auth_ceremony_session!(
      auth, auth_app_verification_path(ri: "jp"), reference: entry,
                                                  params: { ri: "jp" }, headers: auth_headers, confirm_via_http: true, base_browser: self,
    )

    assert_equal 303, auth.response.status
    auth.get(new_auth_app_verification_totp_path(ri: "jp"))

    assert_equal 200, auth.response.status
    props = JSON.parse(Nokogiri::HTML(auth.response.body).at_css("script[data-page='app']").text).fetch("props")
    csrf = props.fetch("form").fetch("csrf_token")
    credential = actor.client_totp_credentials.find_by!(title: "Bootstrap authenticator")
    future = (ClientTotpCredential.database_now + 30.seconds).change(usec: 0)
    travel_to(future) do
      ClientTotpCredential.stub(:database_now, future) do
        ClientStepUpCeremonyTransaction.stub(:database_now, future) do
          auth.post(
            props.fetch("form").fetch("action"), params: {
              :authenticity_token => props.fetch("form").fetch("csrf_token"),
              :verification => { credential_public_id: credential.public_id,
                                 code: ROTP::TOTP.new(credential.private_key).at(future.to_i), },
              "cf-turnstile-response" => "test-only",
            },
          )

          assert_equal 302, auth.response.status
          auth.follow_redirect!
          auth.post(auth_app_verification_handoff_path(ri: "jp"), params: { authenticity_token: csrf })

          assert_equal 303, auth.response.status
          completion_uri = URI.parse(auth.response.location)
          host! completion_uri.host
          https!
          get completion_uri.request_uri
          completion_form = response.parsed_body.at_css("form")
          completion = completion_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
          post completion_form["action"], params: completion, headers: completion_headers

          assert_response :see_other
          assert_equal "totp", token.reload.last_step_up_method
          follow_redirect!

          assert_response :success
          assert_nil auth.cookies[AuthenticationCookieName.access]
          assert_nil auth.cookies[AuthenticationCookieName.refresh]
        end
      end
    end
  end
  # rubocop:enable Minitest/MultipleAssertions

  private

  def install_confirmed_auth_admission_cookie!(browser, issuance:, base_token:, host:, surface: "app")
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: issuance.reference)
    _auth_session, raw_sid = prepare_admission_binding_for_consumption!(binding, base_token: base_token)
    cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    browser.cookies.delete("auth_sid")
    browser.cookies.delete("__Host-auth_sid")
    browser.cookies.merge(
      "#{cookie_name}=#{Rack::Utils.escape(raw_sid)}", URI.parse("https://#{host}/"),
    )
  end
end
