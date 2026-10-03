# frozen_string_literal: true

require "test_helper"
require "support/webauthn_fake_client_helper"

class LocalAuthenticationBoundaryTest < ActionDispatch::IntegrationTest
  include WebauthnFakeClientHelper

  fixtures :clients, :client_statuses, :client_email_statuses, :visitors, :visitor_statuses, :visitor_email_statuses

  setup do
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
  end

  test "a redeemed local sign in admission cannot open the sign up ceremony" do
    issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(surface: "app", intent: "sign_in")
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    get auth_app_sign_in_path, params: { entry_ref: issuance.reference, ri: "jp" }
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_sign_in_path, params: { entry_ref: issuance.reference, authenticity_token: csrf, ri: "jp" }

    assert_response :see_other
    get auth_app_sign_up_path, params: { ri: "jp" }

    assert_response :bad_request
    assert_nil issuance.transaction.reload.principal_id
  end

  test "email delivery refuses missing admission before changing the credential" do
    actor = clients(:one)
    email = actor.client_emails.create!(address: "missing-admission@example.com")
    counter = email.otp_counter
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    post auth_app_sign_in_email_path,
         params: { :user_email => { address: email.address }, "cf-turnstile-response" => "t", :ri => "jp" }

    assert_response :bad_request
    assert_equal counter, email.reload.otp_counter
    assert_nil session[:user_email_authentication_id]
  end

  test "local sign up admission refuses a direct sign in credential endpoint" do
    issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(surface: "app", intent: "sign_up")
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    get auth_app_sign_up_path, params: { entry_ref: issuance.reference, ri: "jp" }
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_sign_up_path, params: { entry_ref: issuance.reference, authenticity_token: csrf, ri: "jp" }

    assert_response :see_other
    post auth_app_sign_in_email_path,
         params: { :user_email => { address: "unexpected@example.com" }, "cf-turnstile-response" => "t", :ri => "jp" }

    assert_response :bad_request
    assert_nil issuance.transaction.reload.principal_id
  end

  test "Auth records local email evidence on the admitted Base flow and issues no root credential" do
    actor = clients(:one)
    email = actor.client_emails.create!(address: "local-boundary@example.com")
    issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(surface: "app", intent: "sign_in")
    original_nonce_digest = issuance.transaction.nonce_digest
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    get auth_app_sign_in_path, params: { entry_ref: issuance.reference, ri: "jp" }

    assert_response :success
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_sign_in_path, params: { entry_ref: issuance.reference, authenticity_token: csrf, ri: "jp" }

    assert_response :see_other

    post auth_app_sign_in_email_path,
         params: { :user_email => { address: email.address }, "cf-turnstile-response" => "t" }

    assert_response :redirect
    key = "JBSWY3DPEHPK3PXP"
    email.reload.store_otp(key, 7, 5.minutes.from_now.to_i)
    before_count = ClientSignInFlow.count
    assert_no_difference("ClientToken.count") do
      patch auth_app_sign_in_email_path,
            params: { :user_email => { pass_code: ROTP::HOTP.new(key).at(7).to_s }, "cf-turnstile-response" => "t" }
    end
    assert_response :redirect
    assert_equal before_count, ClientSignInFlow.count
    flow = issuance.transaction.reload

    assert_equal actor.id, flow.principal_id
    assert_equal "email", flow.authentication_method
    assert_not_nil flow.authentication_event_at
    assert_equal original_nonce_digest, flow.nonce_digest
    assert_nil flow.token_id
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
  end

  test "Base finalizes a local email ceremony once and rejects its result in another browser" do
    actor = clients(:one)
    email = actor.client_emails.create!(address: "local-roundtrip@example.com")
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    destination = nil
    JumpRtIssuer.stub(:call, ->(**args) { destination = args.fetch(:url); "opaque-jump" }) do
      RedirectsJumpGatewayUrl.stub(
        :call, ->(_code) { RedirectsTargetResult.ok(kind: :external, source: :test, value: destination) },
      ) do
        post base_app_sign_show_path, params: { ri: "jp" }
      end
    end

    assert_response :see_other
    entry_ref = Rack::Utils.parse_nested_query(URI.parse(destination).query).fetch("entry_ref")
    flow = ClientSignInFlow.find_by!(public_id: entry_ref)
    browser = open_session
    browser.host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    browser.get(auth_app_sign_in_path, params: { ri: "jp", entry_ref: entry_ref })

    assert_equal 200, browser.response.status
    csrf = Nokogiri::HTML(browser.response.body).at_css('input[name="authenticity_token"]')["value"]
    browser.post(auth_app_sign_in_path, params: { ri: "jp", entry_ref: entry_ref, authenticity_token: csrf })
    browser.post(
      auth_app_sign_in_email_path,
      params: { :ri => "jp", :user_email => { address: email.address }, "cf-turnstile-response" => "t" },
    )

    assert_equal 302, browser.response.status
    key = "JBSWY3DPEHPK3PXP"
    email.reload.store_otp(key, 7, 5.minutes.from_now.to_i)
    assert_no_difference("ClientToken.count") do
      browser.patch(
        auth_app_sign_in_email_path,
        params: { :ri => "jp",
                  :user_email => { pass_code: ROTP::HOTP.new(key).at(7).to_s },
                  "cf-turnstile-response" => "t", },
      )
      browser.follow_redirect!

      assert_equal 303, browser.response.status
      assert_equal "/sign/handoff", URI.parse(browser.response.location).path
      browser.follow_redirect!

      assert_equal 200, browser.response.status
      browser.post(auth_app_sign_handoff_path, params: { ri: "jp" })

      assert_equal 200, browser.response.status
    end
    document = Nokogiri::HTML(browser.response.body)
    result = document.at_css('input[name="result"]')["value"]
    completion_params = { ri: "jp", result: result, transaction_ref: flow.public_id }
    headers = { "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-site" }
    other_browser = open_session
    other_browser.host!(ENV.fetch("PUBLIC_BASE_SERVICE_URL"))
    assert_no_difference("ClientToken.count") do
      other_browser.post(base_app_sign_completion_path, params: completion_params, headers: headers)
    end
    assert_equal 400, other_browser.response.status

    assert_difference("ClientToken.count", 1) do
      post base_app_sign_completion_path, params: completion_params, headers: headers
    end
    assert_response :see_other
    assert_not_nil flow.reload.base_finalized_at
    assert_equal "email", flow.token.established_authentication_method
    assert_equal flow.authentication_event_at, flow.token.authentication_event_at
    assert_not_nil flow.token.root_login_established_at
    assert_not_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil browser.cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_no_difference("ClientToken.count") do
      post base_app_sign_completion_path, params: completion_params, headers: headers
    end
    assert_response :see_other

    # Continue from the root session actually established on Base. Only the external Jump
    # transport and Turnstile service are substituted; the Passkey assertion uses real crypto.
    fake = webauthn_fake_client(origin: "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}")
    actor.client_passkeys.create!(fake_credential_record_attrs(fake))
    token = flow.token.reload
    path = base_app_identity_birthdate_path(ri: "jp")
    verifier = ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("path_target_token", 32),
      digest: "SHA256", serializer: JSON, url_safe: true,
    )
    pt = verifier.generate(
      { "flow" => "step_up.bootstrap",
        "surface" => "app",
        "session_nonce" => token.device_session.public_id,
        "pt" => path, },
      purpose: :path_target, expires_in: 15.minutes,
    )
    JumpRtIssuer.stub(:call, ->(**args) { destination = args.fetch(:url); "opaque-jump" }) do
      RedirectsJumpGatewayUrl.stub(
        :call, ->(_code) { RedirectsTargetResult.ok(kind: :external, source: :test, value: destination) },
      ) do
        post base_app_verification_path(ri: "jp"), params: { scope: "settings_birthdate", pt: pt }
      end
    end

    assert_response :see_other
    entry = Rack::Utils.parse_nested_query(URI.parse(destination).query).fetch("entry_ref")
    browser.get(auth_app_verification_path, params: { ri: "jp", entry_ref: entry })

    assert_equal 200, browser.response.status
    csrf = Nokogiri::HTML(browser.response.body).at_css('input[name="authenticity_token"]')["value"]
    browser.post(auth_app_verification_path, params: { ri: "jp", entry_ref: entry, authenticity_token: csrf })

    assert_equal 303, browser.response.status
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    browser.post(
      auth_app_verification_passkey_options_path(ri: "jp"),
      params: { "cf-turnstile-response" => "test-only" }, headers: { "X-CSRF-Token" => csrf }, as: :json,
    )

    assert_equal 200, browser.response.status
    reference = browser.response.parsed_body.fetch("challenge_id")
    record = ClientStepUpSession.find_by!(passkey_challenge_ref: reference)
    assertion = fake_assertion(fake, challenge: record.passkey_challenge, sign_count: 3)
    browser.post(
      auth_app_verification_passkey_path(ri: "jp"),
      params: { challenge_id: reference, credential: assertion },
      headers: { "X-CSRF-Token" => csrf }, as: :json,
    )

    assert_equal 200, browser.response.status
    assert_nil token.reload.last_step_up_at
    browser.get(browser.response.parsed_body.fetch("redirect_url"))

    assert_equal 200, browser.response.status
    browser.post(auth_app_verification_handoff_path(ri: "jp"), params: { authenticity_token: csrf })

    assert_equal 200, browser.response.status
    document = Nokogiri::HTML(browser.response.body)
    post base_app_verification_completion_path(ri: "jp"), params: {
      result: document.at_css('input[name="result"]')["value"],
      transaction_ref: record.step_up_ceremony_transaction_ref,
    }, headers: headers

    assert_response :see_other
    assert_equal path, URI.parse(response.location).request_uri
    assert_equal "consumed", ClientStepUpCeremonyTransaction.find_by!(
      transaction_id: record.step_up_ceremony_transaction_ref,
    ).status
    assert_equal "passkey", token.reload.last_step_up_method
    assert_nil browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    follow_redirect!

    assert_response :success
  end

  test "COM Base finalizes a local email ceremony once and rejects its result in another browser" do
    actor = Visitor.create!(status_id: VisitorStatus::ACTIVE, birthdate: "2000-01-01")
    email = actor.visitor_emails.create!(address: "com-local-roundtrip@example.com")
    host! ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    destination = nil
    JumpRtIssuer.stub(:call, ->(**args) { destination = args.fetch(:url); "opaque-jump" }) do
      RedirectsJumpGatewayUrl.stub(
        :call, ->(_code) { RedirectsTargetResult.ok(kind: :external, source: :test, value: destination) },
      ) do
        post base_com_sign_show_path, params: { ri: "jp" }
      end
    end

    assert_response :see_other
    entry_ref = Rack::Utils.parse_nested_query(URI.parse(destination).query).fetch("entry_ref")
    flow = VisitorSignInFlow.find_by!(public_id: entry_ref)
    browser = open_session
    browser.host!(ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"))
    browser.get(auth_com_sign_in_path, params: { ri: "jp", entry_ref: entry_ref })

    assert_equal 200, browser.response.status
    csrf = Nokogiri::HTML(browser.response.body).at_css('input[name="authenticity_token"]')["value"]
    browser.post(auth_com_sign_in_path, params: { ri: "jp", entry_ref: entry_ref, authenticity_token: csrf })
    browser.post(
      auth_com_sign_in_email_path,
      params: { :ri => "jp", :user_email => { address: email.address }, "cf-turnstile-response" => "t" },
    )

    assert_equal 302, browser.response.status
    key = "JBSWY3DPEHPK3PXP"
    email.reload.store_otp(key, 7, 5.minutes.from_now.to_i)
    assert_no_difference("VisitorToken.count") do
      browser.patch(
        auth_com_sign_in_email_path,
        params: { :ri => "jp",
                  :user_email => { pass_code: ROTP::HOTP.new(key).at(7).to_s },
                  "cf-turnstile-response" => "t", },
      )

      assert_equal "/sign/in/check", URI.parse(browser.response.location).path
      assert_equal "jp", Rack::Utils.parse_nested_query(URI.parse(browser.response.location).query)["ri"]
      browser.follow_redirect!

      assert_equal 303, browser.response.status
      assert_equal "/sign/handoff", URI.parse(browser.response.location).path
      browser.follow_redirect!

      assert_equal 200, browser.response.status
      browser.post(auth_com_sign_handoff_path, params: { ri: "jp" })

      assert_equal 200, browser.response.status
    end
    document = Nokogiri::HTML(browser.response.body)
    result = document.at_css('input[name="result"]')["value"]
    completion_params = { ri: "jp", result: result, transaction_ref: flow.public_id }
    headers = { "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")}", "Sec-Fetch-Site" => "same-site" }
    other_browser = open_session
    other_browser.host!(ENV.fetch("PUBLIC_BASE_CORPORATE_URL"))
    assert_no_difference("VisitorToken.count") do
      other_browser.post(base_com_sign_completion_path, params: completion_params, headers: headers)
    end
    assert_equal 400, other_browser.response.status

    assert_difference("VisitorToken.count", 1) do
      post base_com_sign_completion_path, params: completion_params, headers: headers
    end
    assert_response :see_other
    assert_not_nil flow.reload.base_finalized_at
    assert_equal "email", flow.token.established_authentication_method
    assert_equal flow.authentication_event_at, flow.token.authentication_event_at
    assert_not_nil flow.token.root_login_established_at
    assert_not_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil browser.cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_no_difference("VisitorToken.count") do
      post base_com_sign_completion_path, params: completion_params, headers: headers
    end
    assert_response :see_other
  end
end
