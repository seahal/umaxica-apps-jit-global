# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class OrgRootLoginEstablishmentTest < ActionDispatch::IntegrationTest
  teardown do
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
  end

  # Provider HTTP is simulated; state, nonce, JWT signature, WebAuthn and Base issuance are real.
  # rubocop:disable Minitest/MultipleAssertions
  test "Entra and Passkey establish Normal root credentials only on Base" do
    operator = Operator.create!
    tenant = SecureRandom.uuid
    audience = SecureRandom.uuid
    object_id = SecureRandom.uuid
    issuer = "https://login.microsoftonline.com/#{tenant}/v2.0"
    OperatorEntraIdentityState.ensure_defaults!
    identity = OperatorEntraIdentity.create!(
      operator_id: operator.id, entra_tenant_id: tenant, entra_object_id: object_id,
      status_id: OperatorEntraIdentityState::ACTIVE,
    )
    auth_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    base_host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    fake = WebAuthn::FakeClient.new("https://#{auth_host}", encoding: :base64url)
    registration = fake.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
    relying_party = WebAuthn::RelyingParty.new(
      id: auth_host, allowed_origins: [fake.origin], encoding: :base64url,
    )
    credential = WebAuthn::Credential.from_create(registration, relying_party: relying_party)
    operator.staff_passkeys.create!(webauthn_id: credential.id, public_key: credential.public_key, sign_count: 0)
    https!
    host!(base_host)
    destination = nil
    JumpRtIssuer.stub(:call, ->(**args) { destination = args.fetch(:url); "opaque-jump" }) do
      RedirectsJumpGatewayUrl.stub(
        :call, ->(_code) { RedirectsTargetResult.ok(kind: :external, source: :test, value: destination) },
      ) do
        post(base_org_sign_show_path, params: { ri: "jp" })
      end
    end

    assert_response :see_other
    reference = Rack::Utils.parse_nested_query(URI.parse(destination).query).fetch("entry_ref")
    flow = OperatorSignInFlow.find_by!(public_id: reference)
    auth_browser = open_session
    auth_browser.https!
    auth_browser.host!(auth_host)
    auth_browser.get(auth_org_sign_in_path, params: { entry_ref: reference, ri: "jp" })
    csrf = Nokogiri::HTML(auth_browser.response.body).at_css('input[name="authenticity_token"]')["value"]
    auth_browser.post(auth_org_sign_in_path, params: { entry_ref: reference, authenticity_token: csrf, ri: "jp" })

    previous_test_mode = OmniAuth.config.test_mode
    OmniAuth.config.test_mode = false
    registry = ExternalAuthentication::ProviderRegistry
    registry.stub(:tenant_id, tenant) do
      registry.stub(:audience, audience) do
        registry.stub(:issuer_for, issuer) do
          auth_browser.post("/social/entra", params: { ri: "jp" })

          assert_equal 302, auth_browser.response.status
          query = Rack::Utils.parse_nested_query(URI.parse(auth_browser.response.location).query)

          assert_equal "S256", query.fetch("code_challenge_method")
          key = OpenSSL::PKey::RSA.generate(2048)
          kid = SecureRandom.hex(8)
          jwk = JWT::JWK.new(key, { "kid" => kid })
          now = Time.current.to_i
          id_token = JWT.encode(
            { "iss" => issuer,
              "aud" => audience,
              "tid" => tenant,
              "oid" => object_id,
              "sub" => "pairwise-#{operator.public_id}",
              "acct" => 0,
              "ver" => "2.0",
              "nonce" => query.fetch("nonce"),
              "iat" => now,
              "exp" => now + 3600, },
            key, "RS256", { "kid" => kid },
          )
          token_stubs =
            Faraday::Adapter::Test::Stubs.new do |stub|
              stub.post("/#{tenant}/oauth2/v2.0/token") do
                [200, { "Content-Type" => "application/json" },
                 JSON.generate(
                   access_token: "offline-access-token", token_type: "Bearer", expires_in: 3600,
                   id_token: id_token,
                 ),]
              end
            end
          token_http =
            Faraday.new(url: "https://login.microsoftonline.com") do |http|
              http.request(:url_encoded)
              http.response(:json)
              http.adapter(:test, token_stubs)
            end
          jwks_stubs =
            Faraday::Adapter::Test::Stubs.new do |stub|
              stub.get("/#{tenant}/discovery/v2.0/keys") do
                [200, { "Content-Type" => "application/json" }, JSON.generate(keys: [jwk.export])]
              end
            end
          jwks_http = Faraday.new(url: "https://login.microsoftonline.com") { |http| http.adapter(:test, jwks_stubs) }
          Rack::OAuth2.stub(:http_client, token_http) do
            OutboundHttp::Connection.stub(:build, jwks_http) do
              Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
                TestSupport::OutboundHttpGuard.allow do
                  auth_browser.get(
                    "/social/entra/callback",
                    params: { state: query.fetch("state"), code: "offline-code" },
                  )
                end
              end
            end
          end
          token_stubs.verify_stubbed_calls
          jwks_stubs.verify_stubbed_calls
        end
      end
    end

    assert_equal 303, auth_browser.response.status
    assert_not_nil identity.reload.last_authenticated_at
    assert_equal 0, OperatorToken.where(staff_id: operator.id).count
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    auth_browser.post(auth_org_sign_in_passkey_options_path, params: { "cf-turnstile-response" => "t", :ri => "jp" })

    assert_equal 200, auth_browser.response.status
    options = auth_browser.response.parsed_body
    assertion = fake.get(challenge: options.fetch("options").fetch("challenge"), user_verified: true, sign_count: 2)
    auth_browser.post(
      auth_org_sign_in_passkey_verification_path,
      params: { credential: assertion, challenge_id: options.fetch("challenge_id"), ri: "jp" }, as: :json,
    )

    assert_equal 200, auth_browser.response.status
    assert_equal "ok", auth_browser.response.parsed_body.fetch("status")
    assert_no_difference(-> { OperatorToken.where(staff_id: operator.id).count }) do
      auth_browser.get(auth_browser.response.parsed_body.fetch("redirect_url"))
      auth_browser.follow_redirect!
      auth_browser.post(auth_org_sign_handoff_path, params: { ri: "jp" })
    end

    assert_equal 200, auth_browser.response.status
    assert_nil auth_browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil auth_browser.cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    document = Nokogiri::HTML(auth_browser.response.body)
    result = document.at_css('input[name="result"]')["value"]
    assert_difference(-> { OperatorToken.where(staff_id: operator.id).count }, 1) do
      post(
        base_org_sign_completion_path,
        params: { result: result, transaction_ref: flow.public_id, ri: "jp" },
        headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-site" },
      )
    end

    assert_response :see_other
    token = OperatorToken.find_by!(staff_id: operator.id)

    assert_equal AuthenticationContextValue::NORMAL_KEY, token.authentication_context
    assert_not_nil token.root_login_established_at
    assert_not_nil flow.reload.base_finalized_at
    assert_equal token.id, flow.token_id
    assert_predicate cookies[AuthenticationBase::ACCESS_COOKIE_KEY].to_s, :present?
    established_at = token.root_login_established_at
    assert_no_difference(-> { OperatorToken.where(staff_id: operator.id).count }) do
      post(
        base_org_sign_completion_path,
        params: { result: result, transaction_ref: flow.public_id, ri: "jp" },
        headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-site" },
      )
    end

    assert_equal established_at, token.reload.root_login_established_at
    assert_no_difference(-> { OperatorSignInFlow.count }) do
      post(base_org_sign_show_path, params: { ri: "jp" })
    end

    assert_response :forbidden
    get(base_org_identity_birthdate_path(ri: "jp"))

    assert_response :redirect
    assert_equal "settings_birthdate", Rack::Utils.parse_query(URI.parse(response.location).query).fetch("scope")
    assert_nil session[:flash]
    get(response.location)

    assert_response :success
    form = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props").fetch("form")
    post(base_org_verification_path(ri: "jp"), params: { scope: form.fetch("scope"), pt: form.fetch("pt") })

    assert_response :see_other
    gateway = URI.parse(response.location)
    jump_payload, = JWT.decode(Rack::Utils.parse_nested_query(gateway.query).fetch("rt"), nil, false)
    auth_location = jump_payload.fetch("url")
    step_up_reference = Rack::Utils.parse_query(URI.parse(auth_location).query).fetch("entry_ref")
    auth_browser.get(auth_location)
    admission_form = Nokogiri::HTML(auth_browser.response.body).at_css("form")
    csrf = admission_form.at_css('input[name="authenticity_token"]')["value"]
    auth_browser.post(
      auth_org_verification_path(ri: "jp"),
      params: { entry_ref: step_up_reference, authenticity_token: csrf },
    )

    assert_equal 303, auth_browser.response.status
    auth_browser.get(new_auth_org_verification_passkey_path(ri: "jp"))
    page = Nokogiri::HTML(auth_browser.response.body)
    panel = JSON.parse(page.at_css("script[data-page='app']").text).fetch("props").fetch("panel")
    auth_browser.post(
      panel.fetch("options_url"), params: { "cf-turnstile-response" => "test-only" },
                                  headers: { "X-CSRF-Token" => csrf }, as: :json,
    )

    assert_equal 200, auth_browser.response.status
    options = auth_browser.response.parsed_body
    assertion = fake.get(challenge: options.fetch("options").fetch("challenge"), user_verified: true, sign_count: 3)
    auth_browser.post(
      panel.fetch("verification_url"),
      params: { credential: assertion, challenge_id: options.fetch("challenge_id") },
      headers: { "X-CSRF-Token" => csrf }, as: :json,
    )

    assert_equal 200, auth_browser.response.status
    assert_nil token.reload.last_step_up_at
    auth_browser.get(auth_browser.response.parsed_body.fetch("redirect_url"))
    handoff_form = Nokogiri::HTML(auth_browser.response.body).at_css("form")
    auth_browser.post(
      handoff_form["action"],
      params: { authenticity_token: handoff_form.at_css('input[name="authenticity_token"]')["value"] },
    )

    assert_equal 200, auth_browser.response.status
    assert_nil auth_browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil auth_browser.cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    result_form = Nokogiri::HTML(auth_browser.response.body).at_css("form")
    transaction_ref = result_form.at_css('input[name="transaction_ref"]')["value"]
    transaction = OperatorStepUpCeremonyTransaction.find_by!(transaction_id: transaction_ref)
    post(
      result_form["action"],
      params: { result: result_form.at_css('input[name="result"]')["value"], transaction_ref: transaction_ref },
      headers: { "Origin" => fake.origin, "Sec-Fetch-Site" => "same-site" },
    )

    assert_response :see_other
    assert_equal "consumed", transaction.reload.status
    assert_equal transaction.verified_at, token.reload.last_step_up_at
    assert_equal "settings_birthdate", token.last_step_up_scope
    assert_equal established_at, token.root_login_established_at
    follow_redirect!

    assert_response :success
    assert_equal 1, OperatorToken.where(staff_id: operator.id).count
  ensure
    OmniAuth.config.test_mode = previous_test_mode unless previous_test_mode.nil?
  end
  # rubocop:enable Minitest/MultipleAssertions
end
