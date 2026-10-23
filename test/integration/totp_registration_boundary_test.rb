# frozen_string_literal: true

require "test_helper"

class TotpRegistrationBoundaryTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  fixtures :clients, :client_statuses, :client_email_statuses, :visitor_statuses, :operator_statuses

  setup do
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

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
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_106_000_000_000, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor, root_login_established_at: Time.current)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor,
      token: token,
      requirement: StepUpRequirement.new(
        step_up_required: true, scope: "settings_birthdate", purpose: "step_up", allowed_methods: [:totp],
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, audience: "step_up:app",
        session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
        actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      ),
      return_to: "/identity/birthdate",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: token,
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
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_106_000_000_001, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor, root_login_established_at: Time.current)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor,
      token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, allowed_methods: [:totp], audience: "step_up:app",
        session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
        actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      ),
      return_to: "/identity/birthdate",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: token,
    )
    Auth::App::Verification::SetupsController.allow_forgery_protection = true
    host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    https!
    begin
      fv5104 = self
      fv5110 = issuance
      fv5108 = token
      fv5043 = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      fv5111 = "app"
      fv5109 = BaseAuthAdmissionCoordinator.find_admission_binding!(
        surface: fv5111,
        reference: fv5110.reference,
      )
      _, fv5102 =
        begin
          fv5107 = fv5109
          fv5106, fv5105 = fv5107.class.auth_admission_session_class.issue!
          fv5107.attach_auth_session!(
            auth_session: fv5106,
            confirmation_ref: SecureRandom.uuid,
          )
          fv5107.confirm_base!(
            base_token: fv5108,
            browser_digest: AuthAdmissionBinding.browser_digest(
              surface: fv5107.class.auth_admission_surface_name,
              entry_ref: fv5107.entry_ref,
              nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
            ),
          )
          [fv5106,
           fv5105,]
        end
      fv5103 = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
      fv5104.cookies.delete("auth_sid")
      fv5104.cookies.delete("__Host-auth_sid")
      fv5104.cookies.merge(
        "#{fv5103}=#{Rack::Utils.escape(fv5102)}",
        URI.parse("https://#{fv5043}/"),
      )
    end
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
  test "admitted bootstrap confirms a DB TOTP candidate without Auth root credentials or freshness" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_106_000_000_002, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor, root_login_established_at: Time.current)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor,
      token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, allowed_methods: [:totp], audience: "step_up:app",
        session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
        actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      ),
      return_to: "/identity/birthdate",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: token,
    )
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    begin
      fv5094 = self
      fv5100 = issuance
      fv5098 = token
      fv5091 = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      fv5101 = "app"
      fv5099 = BaseAuthAdmissionCoordinator.find_admission_binding!(
        surface: fv5101,
        reference: fv5100.reference,
      )
      _, fv5092 =
        begin
          fv5097 = fv5099
          fv5096, fv5095 = fv5097.class.auth_admission_session_class.issue!
          fv5097.attach_auth_session!(
            auth_session: fv5096,
            confirmation_ref: SecureRandom.uuid,
          )
          fv5097.confirm_base!(
            base_token: fv5098,
            browser_digest: AuthAdmissionBinding.browser_digest(
              surface: fv5097.class.auth_admission_surface_name,
              entry_ref: fv5097.entry_ref,
              nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
            ),
          )
          [fv5096,
           fv5095,]
        end
      fv5093 = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
      fv5094.cookies.delete("auth_sid")
      fv5094.cookies.delete("__Host-auth_sid")
      fv5094.cookies.merge(
        "#{fv5093}=#{Rack::Utils.escape(fv5092)}",
        URI.parse("https://#{fv5091}/"),
      )
    end
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
  # Each surface redeems its own permission and limits registration to its method matrix.
  test "COM and ORG setup admit only their actor-specific Passkey registration permission" do
    %w(com org).each do |surface|
      case surface
      when "com"
        actor = Visitor.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          id: 1_000_000_000_000 + SecureRandom.random_number(1_000_000_000),
          status_id: VisitorStatus::ACTIVE,
        )
        token = VisitorToken.create!(authentication_epoch: 0, visitor: actor, root_login_established_at: Time.current)
        auth_host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
        display_path = new_auth_com_verification_setup_path(ri: "jp")
        create_path = auth_com_verification_setup_path(ri: "jp")
        cancel_path = auth_com_verification_cancellation_path(ri: "jp")
        base_host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
      when "org"
        actor = Operator.create!(
          security_mode_id: SecurityModeConfigurable::ADVANCED,
          id: 1_000_000_000_000 + SecureRandom.random_number(1_000_000_000),
          status_id: OperatorStatus::ACTIVE,
        )
        token = OperatorToken.create!(authentication_epoch: 0, staff: actor, root_login_established_at: Time.current)
        auth_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
        display_path = new_auth_org_verification_setup_path(ri: "jp")
        create_path = auth_org_verification_setup_path(ri: "jp")
        cancel_path = auth_org_verification_cancellation_path(ri: "jp")
        base_host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
      end
      issuance = BaseStepUpAdmissionIssuer.call!(
        actor: actor,
        token: token,
        requirement: StepUpRequirement.new(
          scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
          phishing_resistant_required: false, user_verification_required: false,
          full_reauthentication_required: false, ttl: 15.minutes, allowed_methods: [:passkey],
          audience: "step_up:#{surface}",
          session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
          actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
        ),
        return_to: "/identity/birthdate",
        base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
        base_token: token,
      )
      browser = open_session
      browser.host!(auth_host)
      begin
        fv5023 = browser
        fv5089 = issuance
        fv5087 = token
        fv5081 = auth_host
        fv5090 = surface
        fv5088 = BaseAuthAdmissionCoordinator.find_admission_binding!(
          surface: fv5090,
          reference: fv5089.reference,
        )
        _, fv5082 =
          begin
            fv5086 = fv5088
            fv5085, fv5084 = fv5086.class.auth_admission_session_class.issue!
            fv5086.attach_auth_session!(
              auth_session: fv5085,
              confirmation_ref: SecureRandom.uuid,
            )
            fv5086.confirm_base!(
              base_token: fv5087,
              browser_digest: AuthAdmissionBinding.browser_digest(
                surface: fv5086.class.auth_admission_surface_name,
                entry_ref: fv5086.entry_ref,
                nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
              ),
            )
            [fv5085,
             fv5084,]
          end
        fv5083 = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        fv5023.cookies.delete("auth_sid")
        fv5023.cookies.delete("__Host-auth_sid")
        fv5023.cookies.merge(
          "#{fv5083}=#{Rack::Utils.escape(fv5082)}",
          URI.parse("https://#{fv5081}/"),
        )
      end
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
      JumpRtIssuer.stub(
        :call, ->(**args) {
                 destination = args.fetch(:url)
                 "opaque-jump"
               },
      ) do
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
  # A failure and redisplay must retain the same candidate and the same authority deadline.
  test "GET and repeated start preserve enrollment deadline and failures while cancel closes the permission" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_106_000_000_003, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor, root_login_established_at: Time.current)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor,
      token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, allowed_methods: [:totp], audience: "step_up:app",
        session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
        actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      ),
      return_to: "/identity/birthdate",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: token,
    )
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    begin
      fv5073 = self
      fv5079 = issuance
      fv5077 = token
      fv5070 = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      fv5080 = "app"
      fv5078 = BaseAuthAdmissionCoordinator.find_admission_binding!(
        surface: fv5080,
        reference: fv5079.reference,
      )
      _, fv5071 =
        begin
          fv5076 = fv5078
          fv5075, fv5074 = fv5076.class.auth_admission_session_class.issue!
          fv5076.attach_auth_session!(
            auth_session: fv5075,
            confirmation_ref: SecureRandom.uuid,
          )
          fv5076.confirm_base!(
            base_token: fv5077,
            browser_digest: AuthAdmissionBinding.browser_digest(
              surface: fv5076.class.auth_admission_surface_name,
              entry_ref: fv5076.entry_ref,
              nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
            ),
          )
          [fv5075,
           fv5074,]
        end
      fv5072 = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
      fv5073.cookies.delete("auth_sid")
      fv5073.cookies.delete("__Host-auth_sid")
      fv5073.cookies.merge(
        "#{fv5072}=#{Rack::Utils.escape(fv5071)}",
        URI.parse("https://#{fv5070}/"),
      )
    end
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
    JumpRtIssuer.stub(
      :call, ->(**args) {
               destination = args.fetch(:url)
               "opaque-jump"
             },
    ) do
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
  # This journey starts from a real Base Browser-RP session. Root issuance itself is covered by
  # the root-login integration boundary; this case focuses on bootstrap admission and completion.
  # rubocop:disable Minitest/MultipleAssertions
  test "Base begins bootstrap from its own root session and returns TOTP registration without freshness" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_106_000_000_004, status_id: ClientStatus::ACTIVE)
    actor.client_emails.create!(address: "bootstrap-http@example.com")
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    base_client = OidcClientRegistry.find!("base-app-ww")
    token = ClientToken.create!(
      authentication_epoch: 0,
      user: actor, established_authentication_method: "email",
      root_login_established_at: ClientToken.database_now,
    )
    rp_session = OpAppGrant.create!(
      authentication_epoch: 0,
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
    root_access_token = begin
      rp_headers = as_user_headers(actor, host: base_host, session_public_id: token.public_id)
      rp_host = rp_headers["Host"]
      rp_route =
        begin
          Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
        rescue ActionController::RoutingError
          nil
        end
      rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
      if %w(base warp core edit).include?(rp_family) && rp_surface == "app"
        rp_client_id =
          case rp_family
          when "base" then "base-#{rp_surface}-ww"
          when "edit" then "edit-org-ww"
          when "tech" then "tech-org-ww"
          else "#{rp_family}-#{rp_surface}-jp"
          end
        rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
        rp_client = OidcClientRegistry.find!(rp_client_id)
        rp_key = [rp_client.client_id, rp_token.public_id]
        @base_browser_rp_credentials ||= {}
        if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
            !(rp_token.device_session_id && OpAppGrant.exists?(
              device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
            ))
          rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
          rp_now = Time.current
          rp_session = OpAppGrant.create!(
            authentication_epoch: 0,
            client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
            oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
            refresh_token_expires_at: rp_now + 10.minutes,
          )
          rp_access = AuthenticationTokenService.encode(
            rp_token.actor_record, host: rp_host, resource_type: "client",
                                   session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                                   oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                   expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                   issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                   jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                   subject: OidcSubject.for(
                                     rp_token.actor_record,
                                     resource_type: "client",
                                   ), client_id: rp_client.client_id,
          )
          @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
        end
        if @base_browser_rp_credentials[rp_key]
          rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
          rp_cookie = [
            rp_headers.fetch("Cookie"),
            "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
            "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
          ].join("; ")
          rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
        end
      end
      rp_headers
    end
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
    JumpRtIssuer.stub(
      :call, ->(**args) {
               destination = args.fetch(:url)
               "opaque-jump"
             },
    ) do
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
    auth.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] = "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
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
    session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||= "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
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
    begin
      fv5064 = self
      fv5066 = "session"
      fv5065 = fv5064.response.cookies[fv5066]
      if fv5065.nil?
        fv5069 = fv5064.response.headers["Set-Cookie"] || fv5064.response.headers["set-cookie"]
        fv5068 =
          if fv5069.is_a?(String) && fv5069.start_with?("[")
            JSON.parse(fv5069)
          else
            Array(fv5069)
          end
        fv5067 =
          fv5068.flat_map { |cookie_entry| cookie_entry.to_s.split("\n") }.find do |cookie_entry|
            cookie_entry.split(";", 2).first.to_s.start_with?("#{fv5066}=")
          end
        if fv5067

          _, fv5065 = fv5067.split(";", 2).first.to_s.split("=", 2)
          fv5065 = Rack::Utils.unescape(fv5065.to_s)
        end
      end

      unless fv5065.nil?
        fv5064.cookies.delete(fv5066)
        # Rack::Test's []= uses its default host. The current request may target a
        # different surface, so install the cookie against the browser's active host.
        fv5064.cookies.merge(
          "#{fv5066}=#{Rack::Utils.escape(fv5065)}",
          URI.parse("https://#{fv5064.host}/"),
        )
      end
    end
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
    JumpRtIssuer.stub(
      :call, ->(**args) {
               destination = args.fetch(:url)
               "opaque-jump"
             },
    ) do
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
    begin
      fv5063 = auth
      fv5062 = auth_app_verification_path(ri: "jp")
      fv5061 = entry
      fv5060 = :entry_ref
      fv5059 = { ri: "jp" }
      fv5058 = auth_headers
      fv5057 = true
      fv5056 = self
      begin
        fv5004 = fv5063
        fv5011 = fv5062
        fv5054 = fv5061
        fv5055 = fv5060
        fv5020 = fv5059
        fv5013 = fv5058
        fv5042 = fv5057
        fv5041 = fv5056
        fv5016 = nil
        fv5010 = fv5020.merge(fv5055 => fv5054)
        fv5004.get(fv5011, params: fv5010, headers: fv5013)
        fv5048 =
          begin
            fv5053 = fv5004.response.body
            fv5052 = true
            fv5051 = Nokogiri::HTML(fv5053).at_css("form")
            if fv5051.nil? && fv5052
              nil
            else
              raise RuntimeError, "Auth continuation form is missing" unless fv5051

              fv5050 = fv5051.at_css("input[name='authenticity_token']")&.[]("value")
              raise RuntimeError,
                    "Auth continuation is missing its CSRF token" if fv5050.blank?

              fv5049 = fv5051.css("input[type='hidden']").to_h do |input|
                [input["name"], input["value"]]
              end.except("authenticity_token")
              [fv5051["action"], fv5050, fv5049]
            end
          end
        if fv5048

          fv5047, fv5045, fv5046 = fv5048

          fv5004.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
            "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
          fv5004.post(fv5047, params: fv5046.merge(authenticity_token: fv5045), headers: fv5013)
          fv5044 = fv5004.response.location
          if fv5044.present?

            fv5040 = URI.parse(fv5044)
            fv5039 = fv5040.host
            fv5015 =
              begin
                fv5043 = fv5039
                {
                  ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                  ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                  ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                }.fetch(fv5043)
              end
            fv5014 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
              surface: fv5015, reference: fv5040.path.split("/").fetch(-2),
            )

            if fv5042
              fv5022 = fv5041 || fv5004
              fv5022.host!(fv5039)
              fv5022.https!
              fv5022.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
              fv5038 = fv5040.request_uri
              fv5029 = fv5013.merge(
                "Host" => fv5039,
                "Origin" => "https://#{fv5039}",
                "Sec-Fetch-Site" => "same-origin",
              )
              fv5022.get(fv5038, headers: fv5029)
              fv5032, fv5030, fv5031 =
                begin
                  fv5037 = fv5022.response.body
                  fv5036 = false
                  fv5035 = Nokogiri::HTML(fv5037).at_css("form")
                  if fv5035.nil? && fv5036
                    nil
                  else
                    raise RuntimeError, "Auth continuation form is missing" unless fv5035

                    fv5034 = fv5035.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5034.blank?

                    fv5033 = fv5035.css("input[type='hidden']").to_h do |input|
                      [input["name"], input["value"]]
                    end.except("authenticity_token")
                    [fv5035["action"], fv5034, fv5033]
                  end
                end
              fv5022.post(
                fv5032,
                params: fv5031.merge(authenticity_token: fv5030),
                headers: fv5029,
              )
              begin
                fv5023 = fv5022
                fv5025 = "session"
                fv5024 = fv5023.response.cookies[fv5025]
                if fv5024.nil?
                  fv5028 = fv5023.response.headers["Set-Cookie"] || fv5023.response.headers["set-cookie"]
                  fv5027 =
                    if fv5028.is_a?(String) && fv5028.start_with?("[")
                      JSON.parse(fv5028)
                    else
                      Array(fv5028)
                    end
                  fv5026 =
                    fv5027.flat_map { |cookie_entry| cookie_entry.to_s.split("\n") }.find do |cookie_entry|
                      cookie_entry.split(";", 2).first.to_s.start_with?("#{fv5025}=")
                    end
                  if fv5026

                    _, fv5024 = fv5026.split(";", 2).first.to_s.split("=", 2)
                    fv5024 = Rack::Utils.unescape(fv5024.to_s)
                  end
                end

                unless fv5024.nil?
                  fv5023.cookies.delete(fv5025)
                  # Rack::Test's []= uses its default host. The current request may target a
                  # different surface, so install the cookie against the browser's active host.
                  fv5023.cookies.merge(
                    "#{fv5025}=#{Rack::Utils.escape(fv5024)}",
                    URI.parse("https://#{fv5023.host}/"),
                  )
                end
              end
              fv5021 = fv5022.response.location
              raise RuntimeError, "Base confirmation did not return to Auth" if fv5021.blank?

              fv5018 = URI.parse(fv5021)
              if fv5020[:ri].present?
                fv5019 = Rack::Utils.parse_nested_query(fv5018.query.to_s)
                fv5019["ri"] ||= fv5020[:ri].to_s
                fv5018.query = URI.encode_www_form(fv5019)
              end
              fv5004.host!(fv5018.host)
              fv5004.https!
              fv5017 = fv5018.request_uri
              fv5000 = fv5013.merge("Host" => fv5018.host)
              fv5004.get(fv5017, headers: fv5000)
            else
              fv5014.confirm_base!(
                base_token: fv5016,
                browser_digest: AuthAdmissionBinding.browser_digest(
                  surface: fv5015,
                  entry_ref: fv5014.entry_ref,
                  nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                ),
              )
              fv5012 = fv5004.host
              fv5004.host!(fv5012)
              fv5004.https!
              fv5000 = fv5013.merge("Host" => fv5012)
              fv5004.get(fv5011, params: fv5010, headers: fv5000)
            end
            fv5003, fv5001, fv5002 =
              begin
                fv5009 = fv5004.response.body
                fv5008 = false
                fv5007 = Nokogiri::HTML(fv5009).at_css("form")
                if fv5007.nil? && fv5008
                  nil
                else
                  raise RuntimeError, "Auth continuation form is missing" unless fv5007

                  fv5006 = fv5007.at_css("input[name='authenticity_token']")&.[]("value")
                  raise RuntimeError,
                        "Auth continuation is missing its CSRF token" if fv5006.blank?

                  fv5005 = fv5007.css("input[type='hidden']").to_h do |input|
                    [input["name"], input["value"]]
                  end.except("authenticity_token")
                  [fv5007["action"], fv5006, fv5005]
                end
              end
            fv5004.post(
              fv5003,
              params: fv5002.merge(authenticity_token: fv5001),
              headers: fv5000,
            )
          end
        end
      end
    end

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
end
