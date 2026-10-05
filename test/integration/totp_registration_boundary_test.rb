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
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_birthdate", purpose: "step_up", allowed_methods: [:totp], audience: "step_up:app",
        session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
      ), return_to: "/identity/birthdate",
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
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
        allowed_methods: [:totp], audience: "step_up:app",
        session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
      ), return_to: "/identity/birthdate",
    )
    Auth::App::Verification::SetupsController.allow_forgery_protection = true
    host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    https!
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
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
        allowed_methods: [:totp], audience: "step_up:app",
        session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
      ), return_to: "/identity/birthdate",
    )
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
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

    assert_response :success
    document = response.parsed_body
    credential = IdentityTotpEnrollmentFinalCommitter.call!(
      actor: actor, token: token, transaction: issuance.transaction,
      raw_result: document.at_css('input[name="result"]')["value"],
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
      issuance = BaseStepUpAdmissionIssuer.call!(
        actor: actor, token: token,
        requirement: StepUpRequirement.new(
          scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
          allowed_methods: [:passkey], audience: "step_up:#{surface}",
          session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
        ), return_to: "/identity/birthdate",
      )
      browser = open_session
      browser.host!(auth_host)
      browser.get(display_path, params: { entry_ref: issuance.reference })
      csrf = Nokogiri::HTML(browser.response.body).at_css('input[name="authenticity_token"]')["value"]
      browser.post(create_path, params: { entry_ref: issuance.reference, authenticity_token: csrf })

      assert_equal 303, browser.response.status
      browser.follow_redirect!

      assert_equal 200, browser.response.status
      props = JSON.parse(Nokogiri::HTML(browser.response.body).at_css("script[data-page='app']").text).fetch("props")

      assert_equal ["passkey"], props.fetch("methods").pluck("key")
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
      assert_equal base_host, URI.parse(destination).host
      assert_equal "canceled", issuance.transaction.reload.status
    end
  end
  # rubocop:enable Minitest/MultipleAssertions

  # A failure and redisplay must retain the same candidate and the same authority deadline.
  # rubocop:disable Minitest/MultipleAssertions
  test "GET and repeated start preserve enrollment deadline and failures while cancel closes the permission" do
    actor = Client.create!(id: 9_106_000_000_003, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
        allowed_methods: [:totp], audience: "step_up:app",
        session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
      ), return_to: "/identity/birthdate",
    )
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
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

  # This journey obtains its root cookie from the real Base completion endpoint.
  # rubocop:disable Minitest/MultipleAssertions
  test "Base begins bootstrap from its own root session and returns TOTP registration without freshness" do
    actor = Client.create!(id: 9_106_000_000_004, status_id: ClientStatus::ACTIVE)
    email = actor.client_emails.create!(address: "bootstrap-http@example.com")
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    destination = nil
    JumpRtIssuer.stub(:call, ->(**args) { destination = args.fetch(:url); "opaque-jump" }) do
      RedirectsJumpGatewayUrl.stub(
        :call, ->(_code) { RedirectsTargetResult.ok(kind: :external, source: :test, value: destination) },
      ) do
        post base_app_sign_show_path, params: { ri: "jp" }
      end
    end
    entry = Rack::Utils.parse_nested_query(URI.parse(destination).query).fetch("entry_ref")
    flow = ClientSignInFlow.find_by!(public_id: entry)
    auth = open_session
    auth.host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    auth.get(auth_app_sign_in_path, params: { ri: "jp", entry_ref: entry })
    csrf = Nokogiri::HTML(auth.response.body).at_css('input[name="authenticity_token"]')["value"]
    auth.post(auth_app_sign_in_path, params: { ri: "jp", entry_ref: entry, authenticity_token: csrf })
    auth.post(
      auth_app_sign_in_email_path,
      params: { :ri => "jp", :user_email => { address: email.address }, "cf-turnstile-response" => "test-only" },
    )
    key = "JBSWY3DPEHPK3PXP"
    email.reload.store_otp(key, 7, 5.minutes.from_now.to_i)
    auth.patch(
      auth_app_sign_in_email_path,
      params: { :ri => "jp",
                :user_email => { pass_code: ROTP::HOTP.new(key).at(7).to_s },
                "cf-turnstile-response" => "test-only", },
    )
    auth.follow_redirect!
    auth.follow_redirect!
    auth.post(auth_app_sign_handoff_path(ri: "jp"), params: { authenticity_token: csrf })
    document = Nokogiri::HTML(auth.response.body)
    headers = { "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-site" }
    post base_app_sign_completion_path(ri: "jp"), params: {
      result: document.at_css('input[name="result"]')["value"],
      transaction_ref: flow.public_id,
    }, headers: headers

    assert_response :see_other
    assert_not_nil cookies[AuthenticationCookieName.access]
    token = flow.reload.token
    get base_app_identity_birthdate_path(ri: "jp")

    assert_response :redirect
    assert_equal "/verification", URI.parse(response.location).path
    follow_redirect!

    assert_response :success
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    post props.fetch("form").fetch("action"), params: props.fetch("form").slice("scope", "pt")

    # No authenticator yet: Base shows its own method choice and has issued nothing so far.
    assert_response :see_other
    assert_equal base_app_verification_setup_path, URI.parse(response.location).path
    assert_equal 0, ClientStepUpCeremonyTransaction.where(session_ref: token.public_id).count
    follow_redirect!

    assert_response :success
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
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
    assert_nil auth.cookies[AuthenticationCookieName.access]
    entry = Rack::Utils.parse_nested_query(URI.parse(destination).query).fetch("entry_ref")
    auth.get(new_auth_app_verification_setup_path(ri: "jp", entry_ref: entry))
    csrf = Nokogiri::HTML(auth.response.body).at_css('input[name="authenticity_token"]')["value"]
    auth.post(auth_app_verification_setup_path(ri: "jp"), params: { entry_ref: entry, authenticity_token: csrf })
    auth.get(new_auth_app_settings_totp_path(ri: "jp"))
    auth.post(auth_app_settings_totps_enrollment_path(ri: "jp"), params: { authenticity_token: csrf })
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
    document = Nokogiri::HTML(auth.response.body)
    completion = {
      result: document.at_css('input[name="result"]')["value"],
      transaction_ref: document.at_css('input[name="transaction_ref"]')["value"],
    }
    stranger = open_session
    stranger.host!(ENV.fetch("PUBLIC_BASE_SERVICE_URL"))
    assert_no_difference("ClientTotpCredential.count") do
      stranger.post(base_app_verification_completion_path(ri: "jp"), params: completion, headers: headers)
    end

    assert_equal 302, stranger.response.status
    assert_difference("ClientTotpCredential.count", 1) do
      post base_app_verification_completion_path(ri: "jp"), params: completion, headers: headers
    end

    assert_response :see_other
    assert_equal "/identity/birthdate", URI.parse(response.location).path
    assert_nil token.reload.last_step_up_at
    assert_no_difference("ClientTotpCredential.count") do
      post base_app_verification_completion_path(ri: "jp"), params: completion, headers: headers
    end

    assert_response :see_other
    follow_redirect!

    assert_response :redirect
    assert_equal "/verification", URI.parse(response.location).path
    follow_redirect!
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
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
    auth.get(auth_app_verification_path(ri: "jp", entry_ref: entry))
    csrf = Nokogiri::HTML(auth.response.body).at_css('input[name="authenticity_token"]')["value"]
    auth.post(auth_app_verification_path(ri: "jp"), params: { entry_ref: entry, authenticity_token: csrf })
    auth.get(new_auth_app_verification_totp_path(ri: "jp"))
    props = JSON.parse(Nokogiri::HTML(auth.response.body).at_css("script[data-page='app']").text).fetch("props")
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
          document = Nokogiri::HTML(auth.response.body)
          post base_app_verification_completion_path(ri: "jp"), params: {
            result: document.at_css('input[name="result"]')["value"],
            transaction_ref: document.at_css('input[name="transaction_ref"]')["value"],
          }, headers: headers

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
end
