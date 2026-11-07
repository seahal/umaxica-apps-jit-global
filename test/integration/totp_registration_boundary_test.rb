# frozen_string_literal: true

require "test_helper"

class TotpRegistrationBoundaryTest < ActionDispatch::IntegrationTest
  NAVIGATION_HEADERS = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }.freeze

  self.fixture_table_names = []

  fixtures :clients, :client_statuses, :client_email_statuses, :operator_statuses

  setup do
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "registration pages reject missing continuity and ordinary step-up admission" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    https!
    get new_auth_app_settings_totp_path(ri: "jp")

    assert_response :bad_request
    get new_auth_app_verification_setup_path(ri: "jp")

    assert_response :bad_request
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_106_000_000_000, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor, root_login_established_at: Time.current)
    ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    token.rotate_refresh_token! unless token.device_session_record.current_refresh_token_id
    client = OidcClientRegistry.find!("base-app-ww")
    now = OpBaseAppRecord.database_now
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch,
      client_token: token,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now - 1.hour,
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
    verifier = SecureRandom.urlsafe_base64(32)
    params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
      scope: grant.oidc_scope,
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false),
      code_challenge_method: "S256",
      prompt: "login",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    }
    validated_request = OidcAuthorizeRequestResolver.call(params:, resource: actor, resource_type: "client")
    issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "app", actor:, token:, client:, params:, validated_request:,
    )

    assert_equal :issued, issuance.outcome
    get new_auth_app_verification_setup_path(ri: "jp", entry_ref: issuance.entry_ref), headers: NAVIGATION_HEADERS

    assert_response :bad_request
    assert_no_difference("IdentityTotpCeremonyCandidate.count") do
      get new_auth_app_settings_totp_path(ri: "jp")

      assert_response :bad_request
    end
    assert_equal "pending", issuance.ticket.reload.status
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
    https!
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
    get new_auth_app_verification_setup_path(ri: "jp", entry_ref: issuance.reference), headers: NAVIGATION_HEADERS

    assert_response :see_other
    assert_equal new_auth_app_settings_totp_path(ri: "jp"), URI.parse(response.location).request_uri
    admitted_auth_session = ClientAuthCeremonySession.find_by!(
      step_up_ceremony_transaction_ref: issuance.transaction.transaction_id,
    )

    assert_predicate admitted_auth_session, :admitted?
    assert_equal "bootstrap_handoff", admitted_auth_session.admission_purpose
    follow_redirect!

    assert_response :success
    csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")

    assert_nil props.fetch("qr_code_image")
    assert_no_difference("ClientTotpCredential.count") do
      post props.fetch("start").fetch("action"), params: { authenticity_token: csrf },
                                                 headers: same_origin_headers(
                                                   ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), csrf: csrf,
                                                 )
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
        }, headers: same_origin_headers(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), csrf: csrf)
      end
    end

    assert_redirected_to auth_app_settings_totps_handoff_path(ri: "jp")
    follow_redirect!
    post auth_app_settings_totps_handoff_path(ri: "jp"), params: { authenticity_token: csrf },
                                                         headers: same_origin_headers(
                                                           ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), csrf: csrf,
                                                         )

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
  test "ORG setup admits only its actor-specific Passkey registration permission" do
    %w(org).each do |surface|
      case surface
      when "org"
        actor = Operator.create!(
          security_mode_id: SecurityModeConfigurable::ADVANCED,
          id: 1_000_000_000_000 + SecureRandom.random_number(1_000_000_000),
          status_id: OperatorStatus::ACTIVE,
        )
        token = OperatorToken.create!(authentication_epoch: 0, staff: actor, root_login_established_at: Time.current)
        auth_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
        display_path = new_auth_org_verification_setup_path(ri: "jp")
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
      browser.https!
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
      browser.get(display_path, params: { entry_ref: issuance.reference }, headers: NAVIGATION_HEADERS)

      assert_equal 303, browser.response.status
      browser.follow_redirect!

      assert_equal 200, browser.response.status
      browser.get(new_auth_org_verification_registration_passkey_path(ri: "jp"))

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
      csrf = Nokogiri::HTML(browser.response.body).at_css('meta[name="csrf-token"]')["content"]

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
          browser.post(
            cancel_path, params: { authenticity_token: csrf }, headers: same_origin_headers(auth_host, csrf: csrf),
          )
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
    https!
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
    get new_auth_app_verification_setup_path(ri: "jp", entry_ref: issuance.reference), headers: NAVIGATION_HEADERS

    assert_response :see_other
    assert_equal new_auth_app_settings_totp_path(ri: "jp"), URI.parse(response.location).request_uri
    follow_redirect!
    csrf_meta = response.parsed_body.at_css('meta[name="csrf-token"]')

    assert csrf_meta, "Auth settings page must expose its CSRF meta tag (#{response.media_type} #{request.path})"
    csrf = csrf_meta["content"]
    assert_no_difference("IdentityTotpCeremonyCandidate.count") do
      get new_auth_app_settings_totp_path(ri: "jp")
      get new_auth_app_settings_totp_path(ri: "jp")
    end
    post auth_app_settings_totps_enrollment_path(ri: "jp"), params: { authenticity_token: csrf },
                                                            headers: same_origin_headers(
                                                              ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), csrf: csrf,
                                                            )
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
      }, headers: same_origin_headers(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), csrf: csrf)

      assert_response :unprocessable_content
      assert_equal index + 1, record.reload.attempt_count
      post auth_app_settings_totps_enrollment_path(ri: "jp"), params: { authenticity_token: csrf },
                                                              headers: same_origin_headers(
                                                                ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), csrf: csrf,
                                                              )

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
        delete auth_app_settings_totps_enrollment_path(ri: "jp"), params: { authenticity_token: csrf },
                                                                  headers: same_origin_headers(
                                                                    ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), csrf: csrf,
                                                                  )
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

  private

  def same_origin_headers(host, csrf: nil)
    headers = { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
    headers["X-CSRF-Token"] = csrf if csrf.present?
    headers
  end
end
