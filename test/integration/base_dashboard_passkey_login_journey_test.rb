# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class BaseDashboardPasskeyLoginJourneyTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []
  fixtures :client_statuses, :client_email_statuses, :visitor_statuses, :visitor_email_statuses,
           :visitor_passkey_statuses

  setup do
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  %i(app com).each do |surface|
    test "#{surface} anonymous Dashboard returns through Auth Passkey and canonical Base login" do
      case surface
      when :app
        actor = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: "2000-01-01")
        actor.client_emails.create!(
          address: "app-dashboard@example.com", user_email_status_id: ClientEmailStatus::VERIFIED,
        )
        base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
        auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
        flow_model = ClientSignInFlow
        token_model = ClientToken
        issuer = JitSecurityJwtRegistry.surface("BASE_APP")
        entry_path = auth_app_sign_in_path(ri: "jp")
        passkey_page_path = new_auth_app_sign_in_passkey_path(ri: "jp")
        options_path = auth_app_sign_in_passkey_options_path(ri: "jp")
        verification_path = auth_app_sign_in_passkey_verification_path(ri: "jp")
        handoff_path = auth_app_sign_handoff_path(ri: "jp")
        completion_path = base_app_sign_completion_path(ri: "jp")
        selector_path = base_app_selector_path(ri: "jp")
      when :com
        actor = Visitor.create!(status_id: VisitorStatus::ACTIVE, birthdate: "2000-01-01")
        actor.visitor_emails.create!(
          address: "com-dashboard@example.com", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
        )
        base_host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
        auth_host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
        flow_model = VisitorSignInFlow
        token_model = VisitorToken
        issuer = JitSecurityJwtRegistry.surface("BASE_COM")
        entry_path = auth_com_sign_in_path(ri: "jp")
        passkey_page_path = new_auth_com_sign_in_passkey_path(ri: "jp")
        options_path = auth_com_sign_in_passkey_options_path(ri: "jp")
        verification_path = auth_com_sign_in_passkey_verification_path(ri: "jp")
        handoff_path = auth_com_sign_handoff_path(ri: "jp")
        completion_path = base_com_sign_completion_path(ri: "jp")
        selector_path = base_com_selector_path(ri: "jp")
      end

      origin = "https://#{auth_host}"
      fake = WebAuthn::FakeClient.new(origin, encoding: :base64url)
      registration = fake.create(
        challenge: Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false), user_verified: true,
      )
      relying_party = WebAuthn::RelyingParty.new(id: auth_host, allowed_origins: [origin], encoding: :base64url)
      credential = WebAuthn::Credential.from_create(registration, relying_party: relying_party)
      case surface
      when :app
        actor.client_passkeys.create!(
          webauthn_id: credential.id, public_key: credential.public_key, sign_count: 0,
          status_id: ClientPasskeyStatus::ACTIVE, description: "Dashboard journey",
        )
      when :com
        actor.visitor_passkeys.create!(
          webauthn_id: credential.id, public_key: credential.public_key, sign_count: 0,
          status_id: VisitorPasskeyStatus::ACTIVE, description: "Dashboard journey",
        )
      end

      host!(base_host)
      https!
      assert_no_difference(-> { flow_model.count }) do
        get("/dashboard", params: { ri: "jp" })
        follow_redirect!
      end
      assert_response :success
      csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      post(
        "/sign", params: { ri: "jp", authenticity_token: csrf }, headers: {
          "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
        },
      )
      gateway = URI.parse(response.location)
      rt = Rack::Utils.parse_query(gateway.query).fetch("rt")
      payload, = JWT.decode(
        rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
        algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
        verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
      )
      target = URI.parse(payload.fetch("url"))

      assert_equal auth_host, target.host
      entry_ref = Rack::Utils.parse_query(target.query).fetch("entry_ref")
      flow = flow_model.find_by!(public_id: entry_ref)
      browser = open_session
      browser.host!(auth_host)
      browser.https!
      browser.get(target.request_uri)
      csrf = Nokogiri::HTML(browser.response.body).at_css('input[name="authenticity_token"]')["value"]
      browser.post(
        entry_path, params: { entry_ref: entry_ref, authenticity_token: csrf }, headers: {
          "Origin" => origin, "Sec-Fetch-Site" => "same-origin",
        },
      )

      assert_equal 303, browser.response.status
      browser.get(passkey_page_path)
      csrf = Nokogiri::HTML(browser.response.body).at_css('meta[name="csrf-token"]')["content"]
      headers = { "X-CSRF-Token" => csrf, "Origin" => origin, "Sec-Fetch-Site" => "same-origin" }
      browser.post(options_path, params: { "cf-turnstile-response" => "synthetic" }, headers: headers, as: :json)

      assert_equal 200, browser.response.status
      options = browser.response.parsed_body
      assertion = fake.get(
        challenge: options.fetch("options").fetch("challenge"),
        user_present: true, user_verified: true, sign_count: 1,
      )
      assert_no_difference(-> { token_model.count }) do
        browser.post(
          verification_path, params: {
            challenge_id: options.fetch("challenge_id"), credential: assertion,
          }, headers: headers, as: :json,
        )
      end
      assert_equal 200, browser.response.status
      browser.get(browser.response.parsed_body.fetch("redirect_url"))
      browser.follow_redirect!
      csrf = Nokogiri::HTML(browser.response.body).at_css('input[name="authenticity_token"]')["value"]
      browser.post(
        handoff_path, params: { authenticity_token: csrf }, headers: {
          "Origin" => origin, "Sec-Fetch-Site" => "same-origin",
        },
      )

      assert_equal 200, browser.response.status
      result = Nokogiri::HTML(browser.response.body).at_css('input[name="result"]')["value"]
      assert_difference(-> { token_model.count }, 1) do
        post(
          completion_path, params: { result: result, transaction_ref: flow.public_id }, headers: {
            "Origin" => origin, "Sec-Fetch-Site" => "same-site",
          },
        )
      end
      assert_response :see_other
      token = flow.reload.token

      assert_equal "passkey", token.established_authentication_method
      assert_not_nil token.root_login_established_at
      assert_not_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
      assert_nil browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
      follow_redirect!

      assert_redirected_to selector_path
      follow_redirect!

      if surface == :app
        assert_redirected_to base_app_dashboard_path(ri: "jp")
        follow_redirect!
      else
        assert_response :success
        assert_equal "selected", response.parsed_body.fetch("status")
        get(response.parsed_body.fetch("next"))
      end

      assert_response :success
    end
  end
end
