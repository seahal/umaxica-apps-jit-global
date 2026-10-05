# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "webauthn/fake_client"

class BaseOrgDashboardLocalLoginJourneyTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []
  fixtures :operators, :operator_statuses, :operator_passkey_statuses

  setup do
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    @previous_omniauth_test_mode = OmniAuth.config.test_mode
    ActionController::Base.allow_forgery_protection = true
    OmniAuth.config.test_mode = false
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    OmniAuth.config.test_mode = @previous_omniauth_test_mode
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "anonymous org Dashboard completes Entra and Passkey on Auth then establishes its Base session" do
    base_host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    actor = Operator.create!(
      status_id: OperatorStatus::ACTIVE,
      mfa_level_id: OperatorMfaLevel::NOTHING, mfa_status_id: OperatorMfaStatus::UNCONFIGURED,
    )
    tenant = "11111111-2222-3333-4444-555555555555"
    audience = "22222222-3333-4444-5555-666666666666"
    object_id = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    OrganizationEntraConnectionState.ensure_defaults!
    OperatorEntraIdentityState.ensure_defaults!
    OperatorEntraIdentity.create!(
      operator_id: actor.id, entra_tenant_id: tenant, entra_object_id: object_id,
      status_id: OperatorEntraIdentityState::ACTIVE,
    )

    origin = "https://#{auth_host}"
    fake = WebAuthn::FakeClient.new(origin, encoding: :base64url)
    registration = fake.create(
      challenge: Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false), user_verified: true,
    )
    relying_party = WebAuthn::RelyingParty.new(id: auth_host, allowed_origins: [origin], encoding: :base64url)
    credential = WebAuthn::Credential.from_create(registration, relying_party: relying_party)
    actor.operator_passkeys.create!(
      webauthn_id: credential.id, public_key: credential.public_key, sign_count: 0,
      status_id: OperatorPasskeyStatus::ACTIVE, description: "Dashboard journey",
    )

    host!(base_host)
    https!
    assert_no_difference("OperatorSignInFlow.count") do
      get(base_org_dashboard_path(ri: "jp"))
      follow_redirect!
    end
    assert_response :success
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    assert_difference("OperatorSignInFlow.count", 1) do
      post(
        base_org_sign_show_path(ri: "jp"), params: { authenticity_token: csrf }, headers: {
          "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
        },
      )
    end
    gateway = URI.parse(response.location)
    rt = Rack::Utils.parse_query(gateway.query).fetch("rt")
    issuer = JitSecurityJwtRegistry.surface("BASE_ORG")
    payload, = JWT.decode(
      rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
      algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
      verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
    )
    target = URI.parse(payload.fetch("url"))

    assert_equal auth_host, target.host
    entry_ref = Rack::Utils.parse_query(target.query).fetch("entry_ref")
    flow = OperatorSignInFlow.find_by!(public_id: entry_ref)
    browser = open_session
    browser.host!(auth_host)
    browser.https!
    browser.get(target.request_uri)
    csrf = Nokogiri::HTML(browser.response.body).at_css('input[name="authenticity_token"]')["value"]
    browser.post(
      auth_org_sign_in_path, params: { ri: "jp", entry_ref: entry_ref, authenticity_token: csrf },
                             headers: { "Origin" => origin, "Sec-Fetch-Site" => "same-origin" },
    )

    assert_equal 303, browser.response.status

    registry = ExternalAuthentication::ProviderRegistry
    registry.stub(:tenant_id, tenant) do
      registry.stub(:audience, audience) do
        registry.stub(:issuer_for, "https://login.microsoftonline.com/#{tenant}/v2.0") do
          browser.get(new_auth_org_social_entra_session_path(ri: "jp"))

          assert_equal 200, browser.response.status
          csrf = Nokogiri::HTML(browser.response.body).at_css('meta[name="csrf-token"]')["content"]
          browser.post(
            "/social/entra", params: { ri: "jp", authenticity_token: csrf },
                             headers: { "Origin" => origin, "Sec-Fetch-Site" => "same-origin" },
          )

          assert_equal 302, browser.response.status
          authorize_query = Rack::Utils.parse_query(URI.parse(browser.response.location).query)
          private_key = OpenSSL::PKey::RSA.generate(2048)
          jwk = JWT::JWK.new(private_key, { "kid" => "dashboard-local-entra" })
          now = Time.now.to_i
          id_token = JWT.encode(
            { "iss" => "https://login.microsoftonline.com/#{tenant}/v2.0",
              "aud" => audience,
              "tid" => tenant,
              "oid" => object_id,
              "sub" => "dashboard-operator",
              "acct" => 0,
              "ver" => "2.0",
              "nonce" => authorize_query.fetch("nonce"),
              "iat" => now,
              "exp" => now + 3600, },
            private_key, "RS256", { "kid" => "dashboard-local-entra" },
          )
          # Substitute the third-party HTTP transport, retaining real OAuth request construction
          # and the strategy's signature, issuer, audience, nonce and Entra claim verification.
          captured = nil
          token_response = Struct.new(:status, :body).new(
            200, { "token_type" => "Bearer",
                   "access_token" => "synthetic-entra-access",
                   "id_token" => id_token,
                   "expires_in" => 3600, },
          )
          transport = Minitest::Mock.new
          transport.expect(:post, token_response) do |uri, params, _headers|
            captured = { uri: uri, params: params }
            true
          end
          key_source = Minitest::Mock.new
          key_source.expect(:loader, ->(_options) { { "keys" => [jwk.export] } })
          assert_no_difference("OperatorToken.count") do
            Rack::OAuth2.stub(:http_client, transport) do
              ExternalSignIn::EntraJwksCache.stub(:new, key_source) do
                browser.get(
                  "/social/entra/callback", params: {
                    state: authorize_query.fetch("state"), code: "synthetic-authorization-code",
                  },
                )
              end
            end
          end
          transport.verify
          key_source.verify

          assert_equal "login.microsoftonline.com", URI.parse(captured.fetch(:uri)).host
          assert_predicate captured.fetch(:params).fetch(:code_verifier), :present?
          assert_equal 303, browser.response.status
        end
      end
    end

    browser.follow_redirect!
    csrf = Nokogiri::HTML(browser.response.body).at_css('meta[name="csrf-token"]')["content"]
    browser.post(
      auth_org_sign_in_passkey_options_path(ri: "jp"),
      params: { "cf-turnstile-response" => "synthetic" },
      headers: { "X-CSRF-Token" => csrf, "Origin" => origin, "Sec-Fetch-Site" => "same-origin" }, as: :json,
    )

    assert_equal 200, browser.response.status
    options = browser.response.parsed_body
    assertion = fake.get(
      challenge: options.fetch("options").fetch("challenge"),
      user_present: true, user_verified: true, sign_count: 1,
    )
    assert_no_difference("OperatorToken.count") do
      browser.post(
        auth_org_sign_in_passkey_verification_path(ri: "jp"), params: {
          challenge_id: options.fetch("challenge_id"), credential: assertion,
        }, headers: { "X-CSRF-Token" => csrf, "Origin" => origin, "Sec-Fetch-Site" => "same-origin" }, as: :json,
      )
    end
    assert_equal 200, browser.response.status
    browser.get(browser.response.parsed_body.fetch("redirect_url"))
    browser.follow_redirect!
    csrf = Nokogiri::HTML(browser.response.body).at_css('input[name="authenticity_token"]')["value"]
    browser.post(
      auth_org_sign_handoff_path(ri: "jp"), params: { authenticity_token: csrf },
                                            headers: { "Origin" => origin, "Sec-Fetch-Site" => "same-origin" },
    )

    assert_equal 200, browser.response.status
    result = Nokogiri::HTML(browser.response.body).at_css('input[name="result"]')["value"]

    assert_predicate flow.reload, :sign_in_session_issuance_pending?
    assert_difference("OperatorToken.count", 1) do
      post(
        base_org_sign_completion_path(ri: "jp"), params: { result: result, transaction_ref: flow.public_id },
                                                 headers: { "Origin" => origin, "Sec-Fetch-Site" => "same-site" },
      )
    end
    assert_response :see_other
    token = flow.reload.token

    assert_equal "passkey", token.established_authentication_method
    assert_not_nil token.root_login_established_at
    assert_nil browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    follow_redirect!

    assert_redirected_to base_org_selector_path(ri: "jp")
    follow_redirect!

    assert_response :success
    assert_equal "selected", response.parsed_body.fetch("status")
    get(response.parsed_body.fetch("next"))

    assert_response :success
  end
end
