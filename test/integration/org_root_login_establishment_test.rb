# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class OrgRootLoginEstablishmentTest < ActionDispatch::IntegrationTest
  teardown do
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
  end

  # Provider HTTP is simulated; state, nonce, JWT signature, WebAuthn and Visa issuance are real.
  # rubocop:disable Minitest/MultipleAssertions
  test "Entra and Passkey establish Normal root credentials only on Visa" do
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
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
    visa_host = ENV.fetch("PUBLIC_VISA_STAFF_URL")
    fake = WebAuthn::FakeClient.new("https://#{auth_host}", encoding: :base64url)
    registration = fake.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
    relying_party = WebAuthn::RelyingParty.new(
      id: auth_host, allowed_origins: [fake.origin], encoding: :base64url,
    )
    credential = WebAuthn::Credential.from_create(registration, relying_party: relying_party)
    operator.staff_passkeys.create!(webauthn_id: credential.id, public_key: credential.public_key, sign_count: 0)
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: operator)
    base_issuer = JitSecurityJwtRegistry.surface("BASE_ORG")
    visa_issuer = JitSecurityJwtRegistry.surface("VISA_ORG")
    jump_host = URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host
    base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
    auth_headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" }
    https!
    host!(base_host)
    get(base_org_sign_show_path(ri: "jp", pt: "/dashboard?ri=jp"))
    form = response.parsed_body.at_css("form")
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    post(form["action"], params: fields, headers: base_headers)
    target = URI.parse(response.location)
    # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
    unless target.host == base_host
      rt = Rack::Utils.parse_query(target.query).fetch("rt")
      payload, = JWT.decode(
        rt, JitSecurityJwtRegistry.public_key_for(base_issuer.id, base_issuer.current_kid), true,
        algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
        verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
      )
      target = URI.parse(payload.fetch("url"))
    end

    assert_equal visa_host, target.host
    auth_browser = open_session
    current_browser = self
    current_host = visa_host
    entry_ref = nil
    12.times do
      current_browser.host!(current_host)
      current_browser.https!
      current_browser.get(target.request_uri, headers: oidc_navigation_headers(current_host))
      break unless current_browser.response.redirect?

      target = URI.parse(current_browser.response.location.to_s)
      target = URI.parse("https://#{current_host}#{target}") if target.host.blank?
      target = URI.parse(jump_rt_url_from_location_for_test(target.to_s)) if target.host == jump_host
      entry_ref ||= Rack::Utils.parse_query(target.query)["entry_ref"] if target.query.to_s.present?
      current_host = target.host
      current_browser =
        case current_host
        when visa_host then self
        when auth_host then auth_browser
        else raise "unexpected OIDC admission host: #{current_host.inspect}"
        end
    end

    raise "OIDC admission did not reach Auth" unless current_browser.equal?(auth_browser) &&
      auth_browser.response.successful?

    raise "OIDC admission entry reference is missing" if entry_ref.blank?

    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "org", reference: entry_ref)
    flow = authorization_transaction_for_test(binding)

    assert_predicate binding.reload, :redeemed?
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
    passkey_binding = Rack::Utils.parse_nested_query(
      URI.parse(auth_browser.response.location).query.to_s,
    ).fetch("fb")

    assert_not_nil identity.reload.last_authenticated_at
    assert_equal 0, OperatorToken.where(staff_id: operator.id).count
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    auth_browser.post(
      auth_org_sign_in_passkey_options_path(fb: passkey_binding, ri: "jp"),
      params: { "cf-turnstile-response" => "t" },
    )

    assert_equal 200, auth_browser.response.status
    options = auth_browser.response.parsed_body
    assertion = fake.get(challenge: options.fetch("options").fetch("challenge"), user_verified: true, sign_count: 2)
    auth_browser.post(
      auth_org_sign_in_passkey_verification_path(fb: passkey_binding, ri: "jp"),
      params: { credential: assertion, challenge_id: options.fetch("challenge_id") }, as: :json,
    )

    assert_equal 200, auth_browser.response.status
    assert_equal "ok", auth_browser.response.parsed_body.fetch("status")
    assert_no_difference(-> { OperatorToken.where(staff_id: operator.id).count }) do
      auth_browser.get(auth_browser.response.parsed_body.fetch("redirect_url"))
      auth_browser.follow_redirect!
      auth_browser.get(
        auth_org_sign_oidc_handoff_path(ri: "jp"),
        headers: oidc_navigation_headers(auth_host),
      )
    end

    assert_equal 303, auth_browser.response.status
    assert_nil auth_browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil auth_browser.cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    target = URI.parse(auth_browser.response.location)
    callback_uri = nil
    host!(visa_host)
    assert_difference(-> { OperatorToken.where(staff_id: operator.id).count }, 1) do
      get(target.request_uri, headers: oidc_navigation_headers(visa_host))
    end

    assert_response :see_other
    token = OperatorToken.find_by!(staff_id: operator.id)

    assert_equal AuthenticationContextValue::NORMAL_KEY, token.authentication_context
    assert_not_nil token.root_login_established_at
    assert_predicate flow.reload, :consumed?
    assert_equal token.public_id, flow.browser_session_ref
    assert_predicate cookies[AuthenticationBase::ACCESS_COOKIE_KEY].to_s, :present?
    established_at = token.root_login_established_at
    callback_uri = URI.parse(response.location)
    assert_no_difference(-> { OperatorToken.where(staff_id: operator.id).count }) do
      get(target.request_uri, headers: oidc_navigation_headers(visa_host))
    end
    # WU-27/D-104: the finalized result is terminal and cannot issue a second
    # callback or Root Session.
    assert_response :bad_request
    assert_equal token.public_id, flow.reload.browser_session_ref
    assert_equal established_at, token.reload.root_login_established_at
    # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
    unless callback_uri.host == visa_host
      callback_rt = Rack::Utils.parse_query(callback_uri.query).fetch("rt")
      callback_payload, = JWT.decode(
        callback_rt, JitSecurityJwtRegistry.public_key_for(visa_issuer.id, visa_issuer.current_kid), true,
        algorithms: ["ES384"], verify_iss: true, iss: "https://#{visa_host}",
        verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
      )
      callback_uri = URI.parse(callback_payload.fetch("url"))
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
        assert_equal visa_host, args.fetch(:url).host
        connection
      },
    ) do
      TestSupport::OutboundHttpGuard.allow do
        host!(callback_uri.host)
        get(callback_uri.request_uri)
      end
    end

    assert_response :redirect
    assert_predicate cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s, :present?
    assert_predicate cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s, :present?
    transport.verify_stubbed_calls
    assert_no_difference(-> { OperatorSignInFlow.count }) do
      post(base_org_sign_show_path, params: { ri: "jp" })
    end

    assert_response :redirect
    assert_equal "/identity/passkeys/new", URI.parse(response.location).path
    get(base_org_identity_birthdate_path(ri: "jp"))

    assert_response :redirect
    continuation_query = Rack::Utils.parse_query(URI.parse(response.location).query)

    assert_equal "settings_birthdate", continuation_query["scope"], response.location
    assert_nil session[:flash]
    get(response.location)

    assert_response :success
    form = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props").fetch("form")
    post(base_org_verification_path(ri: "jp"), params: { scope: form.fetch("scope"), pt: form.fetch("pt") })

    assert_response :see_other
    gateway = URI.parse(response.location)
    jump_payload, = JWT.decode(Rack::Utils.parse_nested_query(gateway.query).fetch("rt"), nil, false)
    auth_location = jump_payload.fetch("url")
    Rack::Utils.parse_query(URI.parse(auth_location).query).fetch("entry_ref")
    auth_browser.get(auth_location)
    3.times do |index|
      sender = (index == 1) ? self : auth_browser
      form = Nokogiri::HTML(sender.response.body).at_css("form")
      fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      sender.post(form["action"], params: fields, headers: (index == 1) ? base_headers : auth_headers)

      assert_equal 303, sender.response.status
      next if index == 2

      receiver = index.zero? ? self : auth_browser
      receiver.get(URI.parse(sender.response.location).request_uri)
    end
    csrf = nil
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

    assert_equal 303, auth_browser.response.status
    assert_nil auth_browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil auth_browser.cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    target = URI.parse(auth_browser.response.location)
    get(target.request_uri)
    result_form = response.parsed_body.at_css("form")
    fields = result_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    transaction = OperatorStepUpCeremonyTransaction.find_by!(transaction_id: fields.fetch("transaction_ref"))
    post(result_form["action"], params: fields, headers: base_headers)

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

  private

  def oidc_navigation_headers(host)
    {
      "Host" => host,
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => "cross-site",
    }
  end

  # rubocop:enable Minitest/MultipleAssertions
end
