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
      security_mode_id: SecurityModeConfigurable::NORMAL, mfa_status_id: OperatorMfaStatus::UNCONFIGURED,
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

    BaseSelectorBootstrapAuthority.call(surface: :org, principal: actor)
    host!(base_host)
    https!
    assert_no_difference("OperatorOidcAuthorizationTransaction.count") do
      get(base_org_dashboard_path(ri: "jp"))
      follow_redirect!
    end
    assert_response :success
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    assert_no_difference("OperatorSignInFlow.count") do
      post(
        base_org_sign_show_path(ri: "jp"), params: { authenticity_token: csrf }, headers: {
          "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
        },
      )
    end
    issuer = JitSecurityJwtRegistry.surface("BASE_ORG")
    target = URI.parse(response.location)
    # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
    unless target.host == base_host
      rt = Rack::Utils.parse_query(target.query).fetch("rt")
      payload, = JWT.decode(
        rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
        algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
        verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
      )
      target = URI.parse(payload.fetch("url"))
    end

    assert_equal base_host, target.host
    get(target.request_uri)
    form = response.parsed_body.at_css("form#base-authorization-ceremony-start-form")
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    post(
      form["action"], params: fields, headers: {
        "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
      },
    )
    target = URI.parse(response.location)
    # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
    unless target.host == base_host
      target = target
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless target.host == base_host
        handoff_rt = Rack::Utils.parse_query(target.query).fetch("rt")
        handoff_payload, = JWT.decode(
          handoff_rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        target = URI.parse(handoff_payload.fetch("url"))
      end
    end

    assert_equal auth_host, target.host
    entry_ref = Rack::Utils.parse_query(target.query).fetch("entry_ref")
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "org", reference: entry_ref)
    flow = authorization_transaction_for_test(binding)
    browser = open_session
    browser.host!(auth_host)
    browser.https!
    browser.get(target.request_uri)
    3.times do |index|
      sender = (index == 1) ? self : browser
      form = Nokogiri::HTML(sender.response.body).at_css("form")
      fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      sender.post(
        form["action"], params: fields, headers: {
          "Origin" => "https://#{(index == 1) ? base_host : auth_host}", "Sec-Fetch-Site" => "same-origin",
        },
      )
      raise RuntimeError, "Admission failed at step #{index}" unless sender.response.status == 303
      next if index == 2

      receiver = index.zero? ? self : browser
      receiver.get(URI.parse(sender.response.location).request_uri)
    end

    assert_predicate binding.reload, :redeemed?
    passkey_binding = nil
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
          passkey_binding = Rack::Utils.parse_nested_query(
            URI.parse(browser.response.location).query.to_s,
          ).fetch("fb")
        end
      end
    end

    browser.follow_redirect!
    csrf = Nokogiri::HTML(browser.response.body).at_css('meta[name="csrf-token"]')["content"]
    browser.post(
      auth_org_sign_in_passkey_options_path(fb: passkey_binding, ri: "jp"),
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
        auth_org_sign_in_passkey_verification_path(fb: passkey_binding, ri: "jp"), params: {
          challenge_id: options.fetch("challenge_id"), credential: assertion,
        }, headers: { "X-CSRF-Token" => csrf, "Origin" => origin, "Sec-Fetch-Site" => "same-origin" }, as: :json,
      )
    end
    assert_equal 200, browser.response.status
    browser.get(browser.response.parsed_body.fetch("redirect_url"))
    browser.follow_redirect!
    csrf = Nokogiri::HTML(browser.response.body).at_css('input[name="authenticity_token"]')["value"]
    browser.post(
      auth_org_sign_oidc_handoff_path(ri: "jp"), params: { authenticity_token: csrf },
                                                 headers: { "Origin" => origin, "Sec-Fetch-Site" => "same-origin" },
    )

    assert_equal 303, browser.response.status
    assert_predicate flow.reload, :authenticated?
    get(URI.parse(browser.response.location).request_uri)
    form = response.parsed_body.at_css("form")
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    assert_difference("OperatorToken.count", 1) do
      post(
        form["action"], params: fields, headers: {
          "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
        },
      )
    end
    assert_response :see_other
    token = OperatorToken.find_by!(public_id: flow.reload.browser_session_ref)

    assert_equal ["passkey", true, nil],
                 [token.established_authentication_method, token.root_login_established_at.present?,
                  browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY],]
    callback_uri = URI.parse(response.location)
    # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
    unless callback_uri.host == base_host
      callback_uri = callback_uri
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless callback_uri.host == base_host
        callback_rt = Rack::Utils.parse_query(callback_uri.query).fetch("rt")
        callback_payload, = JWT.decode(
          callback_rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        callback_uri = URI.parse(callback_payload.fetch("url"))
      end
    end
    protocol_browser = open_session
    protocol_browser.host!(base_host)
    protocol_browser.https!
    # Substitute network transport only: the token and UserInfo requests still run
    # through their real public controllers, including PKCE and client authentication.
    transport =
      Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post(/.*/) do |env|
          # The nested Rack executor must not complete the in-flight callback.
          outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
          outer_actor = Actor.context
          executor_key = Rails.application.executor.active_key
          outer_execution = ActiveSupport::IsolatedExecutionState.delete(executor_key)
          begin
            protocol_browser.host!(env.url.authority)
            protocol_browser.https!(env.url.scheme == "https")
            protocol_browser.post(
              env.url.request_uri, params: Rack::Utils.parse_query(env.body),
                                   headers: { "Accept" => "application/json" },
            )
          ensure
            ActiveSupport::IsolatedExecutionState[executor_key] = outer_execution
          end

          assert_withheld { ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(outer_controller) }
          assert_withheld { Actor.context.equal?(outer_actor) }
          assert_equal 200, protocol_browser.response.status
          [protocol_browser.response.status, { "Content-Type" => "application/json" },
           protocol_browser.response.body,]
        end
        stub.get(/.*/) do |env|
          outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
          outer_actor = Actor.context
          executor_key = Rails.application.executor.active_key
          outer_execution = ActiveSupport::IsolatedExecutionState.delete(executor_key)
          begin
            protocol_browser.host!(env.url.authority)
            protocol_browser.https!(env.url.scheme == "https")
            protocol_browser.get(
              env.url.request_uri, headers: { "Authorization" => env.request_headers.fetch("Authorization"),
                                              "Accept" => "application/json", },
            )
          ensure
            ActiveSupport::IsolatedExecutionState[executor_key] = outer_execution
          end

          assert_withheld { ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(outer_controller) }
          assert_withheld { Actor.context.equal?(outer_actor) }
          assert_equal 200, protocol_browser.response.status
          [protocol_browser.response.status, { "Content-Type" => "application/json" },
           protocol_browser.response.body,]
        end
      end
    connection =
      Faraday.new do |builder|
        builder.request(:url_encoded)
        builder.adapter(:test, transport)
      end
    OutboundHttp::Connection.stub(
      :build, ->(**args) {
        assert_equal base_host, args.fetch(:url).host
        connection
      },
    ) do
      TestSupport::OutboundHttpGuard.allow do
        get callback_uri.request_uri
      end
    end

    assert_equal [true, true, true],
                 [response.redirect?, cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.present?,
                  cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.present?,]
    transport.verify_stubbed_calls
    get(base_org_selector_path(ri: "jp"))

    assert_response :success
    assert_equal "selected", response.parsed_body.fetch("status")
    get(response.parsed_body.fetch("next"))

    assert_response :success
  end
end
