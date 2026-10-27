# typed: false
# frozen_string_literal: true

require "test_helper"

class AcceptanceWu29SignEntrySentryBlockedTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  REALMS = [
    {
      surface: "app",
      auth_host_env: "PUBLIC_AUTH_SERVICE_URL",
      client_id: "core-app-jp",
      binding_class: ClientAuthAdmissionBinding,
      ceremony_class: ClientAuthCeremonySession,
      sign_in_flow_class: ClientSignInFlow,
      sign_up_flow_class: ClientSignUpFlow,
      actor_class: Client,
      posts: [
        ["/sign/in/email", { client_email: { raw_address: "blocked@example.test" } }, false],
        ["/sign/in/secret", { identifier: "blocked@example.test", secret: "a" * 32 }, false],
        ["/sign/in/passkey/options", { "cf-turnstile-response" => "test" }, true],
      ],
      callback: ["/social/google/session", "/social/google/callback", :google],
    },
    {
      surface: "com",
      auth_host_env: "PUBLIC_AUTH_CORPORATE_URL",
      client_id: "core-com-jp",
      binding_class: VisitorAuthAdmissionBinding,
      ceremony_class: VisitorAuthCeremonySession,
      sign_in_flow_class: VisitorSignInFlow,
      sign_up_flow_class: VisitorSignUpFlow,
      actor_class: Visitor,
      posts: [
        ["/sign/in/email", { visitor_email: { raw_address: "blocked@example.test" } }, false],
        ["/sign/in/passkey/options", { "cf-turnstile-response" => "test" }, true],
      ],
    },
    {
      surface: "org",
      auth_host_env: "PUBLIC_AUTH_STAFF_URL",
      client_id: "core-org-jp",
      binding_class: OperatorAuthAdmissionBinding,
      ceremony_class: OperatorAuthCeremonySession,
      sign_in_flow_class: OperatorSignInFlow,
      sign_up_flow_class: OperatorSignUpFlow,
      actor_class: Operator,
      posts: [["/sign/in/passkey/options", { "cf-turnstile-response" => "test" }, true]],
      callback: ["/social/entra/session", "/social/entra/callback", :entra],
    },
  ].freeze

  setup do
    @previous_sign_in_flags =
      %w(app com org).to_h do |surface|
        feature = FeatureFlags::REGISTRY.fetch(:"sign_in_available_#{surface}").name
        [feature, Flipper.enabled?(feature)]
      end
    @previous_omniauth_mode = OmniAuth.config.test_mode
    @previous_mock_auth = { google: OmniAuth.config.mock_auth[:google], entra: OmniAuth.config.mock_auth[:entra] }
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(provider: "google", uid: "blocked-google")
    OmniAuth.config.mock_auth[:entra] = OmniAuth::AuthHash.new(provider: "entra", uid: "blocked-entra")
  end

  teardown do
    @previous_sign_in_flags.each do |feature, enabled|
      enabled ? Flipper.enable(feature) : Flipper.disable(feature)
    end
    OmniAuth.config.test_mode = @previous_omniauth_mode
    @previous_mock_auth.each do |provider, value|
      value.nil? ? OmniAuth.config.mock_auth.delete(provider) : OmniAuth.config.mock_auth[provider] = value
    end
  end

  test "A29-4: BLOCKED refuses admitted entries and each available sign-in continuation without allocating state" do
    observed = []
    changed_state = []
    navigation = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }

    REALMS.each do |realm|
      surface = realm.fetch(:surface)
      feature = FeatureFlags::REGISTRY.fetch(:"sign_in_available_#{surface}").name
      auth_host = ENV.fetch(realm.fetch(:auth_host_env))

      Flipper.enable(feature)
      client_id = realm.fetch(:client_id)
      client = OidcClientRegistry.find!(client_id)
      transaction = OidcAuthorizationTransactionCoordinator.issue!(
        surface:,
        intent: "sign_in",
        params: {
          response_type: "code",
          client_id:,
          redirect_uri: client.redirect_uris_by_realm.fetch(client.resource_type).first,
          code_challenge: SecureRandom.urlsafe_base64(32),
          code_challenge_method: "S256",
          scope: "openid profile",
          state: SecureRandom.urlsafe_base64(24),
          nonce: SecureRandom.urlsafe_base64(24),
        },
      ).transaction
      issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
        transaction:, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
      )
      binding = realm.fetch(:binding_class).find_by!(entry_ref: issuance.reference)
      direct_browser = open_session
      direct_browser.host!(auth_host)
      direct_browser.https!
      before_direct = [
        binding.reload.attributes,
        realm.fetch(:ceremony_class).order(:id).map(&:attributes),
        realm.fetch(:sign_in_flow_class).order(:id).map(&:attributes),
        realm.fetch(:sign_up_flow_class).order(:id).map(&:attributes),
        realm.fetch(:actor_class).order(:id).map(&:attributes),
        direct_browser.cookies.to_hash,
      ]
      Flipper.disable(feature)

      direct_browser.get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" })
      redirect_hops = 0
      if direct_browser.response.redirect?
        redirect_hops += 1

        assert_equal 303, direct_browser.response.status
        assert_equal "/ceremony_bindings", URI.parse(direct_browser.response.location).path
        direct_browser.get(direct_browser.response.location, headers: navigation)
      end

      assert_operator redirect_hops, :<=, 1, "#{surface} blocked entry uses at most one stateless hop"
      assert_equal 503, direct_browser.response.status
      assert_not direct_browser.response.redirect?
      assert_equal "no-store", direct_browser.response.headers["Cache-Control"]
      observed << [surface, "GET /sign/in", direct_browser.response.status,
                   direct_browser.response.location && URI.parse(direct_browser.response.location).path,]
      direct_after = [
        binding.reload.attributes,
        realm.fetch(:ceremony_class).order(:id).map(&:attributes),
        realm.fetch(:sign_in_flow_class).order(:id).map(&:attributes),
        realm.fetch(:sign_up_flow_class).order(:id).map(&:attributes),
        realm.fetch(:actor_class).order(:id).map(&:attributes),
        direct_browser.cookies.to_hash,
      ]
      changed_state << [surface, "GET /sign/in", before_direct != direct_after]

      before_attachment = [
        binding.reload.attributes,
        realm.fetch(:ceremony_class).order(:id).map(&:attributes),
        realm.fetch(:sign_in_flow_class).order(:id).map(&:attributes),
        realm.fetch(:sign_up_flow_class).order(:id).map(&:attributes),
        realm.fetch(:actor_class).order(:id).map(&:attributes),
        direct_browser.cookies.to_hash,
      ]
      direct_browser.get("/ceremony_bindings", params: { entry_ref: issuance.reference, ri: "jp" })
      observed << [surface, "GET /ceremony_bindings", direct_browser.response.status,
                   direct_browser.response.location && URI.parse(direct_browser.response.location).path,]
      attachment_after = [
        binding.reload.attributes,
        realm.fetch(:ceremony_class).order(:id).map(&:attributes),
        realm.fetch(:sign_in_flow_class).order(:id).map(&:attributes),
        realm.fetch(:sign_up_flow_class).order(:id).map(&:attributes),
        realm.fetch(:actor_class).order(:id).map(&:attributes),
        direct_browser.cookies.to_hash,
      ]
      changed_state << [surface, "GET /ceremony_bindings", before_attachment != attachment_after]

      before_sign_in_post = [
        binding.reload.attributes,
        realm.fetch(:ceremony_class).order(:id).map(&:attributes),
        realm.fetch(:sign_in_flow_class).order(:id).map(&:attributes),
        realm.fetch(:sign_up_flow_class).order(:id).map(&:attributes),
        realm.fetch(:actor_class).order(:id).map(&:attributes),
        direct_browser.cookies.to_hash,
      ]
      direct_browser.post("/sign/in", params: { ri: "jp" })
      observed << [surface, "POST /sign/in", direct_browser.response.status,
                   direct_browser.response.location && URI.parse(direct_browser.response.location).path,]
      after_sign_in_post = [
        binding.reload.attributes,
        realm.fetch(:ceremony_class).order(:id).map(&:attributes),
        realm.fetch(:sign_in_flow_class).order(:id).map(&:attributes),
        realm.fetch(:sign_up_flow_class).order(:id).map(&:attributes),
        realm.fetch(:actor_class).order(:id).map(&:attributes),
        direct_browser.cookies.to_hash,
      ]
      changed_state << [surface, "POST /sign/in", before_sign_in_post != after_sign_in_post]

      before_binding_post = [
        binding.reload.attributes,
        realm.fetch(:ceremony_class).order(:id).map(&:attributes),
        realm.fetch(:sign_in_flow_class).order(:id).map(&:attributes),
        realm.fetch(:sign_up_flow_class).order(:id).map(&:attributes),
        realm.fetch(:actor_class).order(:id).map(&:attributes),
        direct_browser.cookies.to_hash,
      ]
      direct_browser.post("/ceremony_bindings", params: { entry_ref: issuance.reference, ri: "jp" })
      observed << [surface, "POST /ceremony_bindings", direct_browser.response.status,
                   direct_browser.response.location && URI.parse(direct_browser.response.location).path,]
      after_binding_post = [
        binding.reload.attributes,
        realm.fetch(:ceremony_class).order(:id).map(&:attributes),
        realm.fetch(:sign_in_flow_class).order(:id).map(&:attributes),
        realm.fetch(:sign_up_flow_class).order(:id).map(&:attributes),
        realm.fetch(:actor_class).order(:id).map(&:attributes),
        direct_browser.cookies.to_hash,
      ]
      changed_state << [surface, "POST /ceremony_bindings", before_binding_post != after_binding_post]

      realm.fetch(:posts).each do |path, params, json|
        Flipper.enable(feature)
        continuation_transaction = OidcAuthorizationTransactionCoordinator.issue!(
          surface:,
          intent: "sign_in",
          params: {
            response_type: "code",
            client_id:,
            redirect_uri: client.redirect_uris_by_realm.fetch(client.resource_type).first,
            code_challenge: SecureRandom.urlsafe_base64(32),
            code_challenge_method: "S256",
            scope: "openid profile",
            state: SecureRandom.urlsafe_base64(24),
            nonce: SecureRandom.urlsafe_base64(24),
          },
        ).transaction
        continuation_issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
          transaction: continuation_transaction,
          base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
        )
        browser = open_session
        browser.host!(auth_host)
        browser.https!
        browser.get("/sign/in", params: { entry_ref: continuation_issuance.reference, ri: "jp" })

        assert_equal 303, browser.response.status
        assert_equal "/ceremony_bindings", URI.parse(browser.response.location).path
        browser.get(browser.response.location)

        assert_equal 303, browser.response.status
        binding = realm.fetch(:binding_class).find_by!(entry_ref: continuation_issuance.reference)
        binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
        browser.get("/sign/in", params: { entry_ref: continuation_issuance.reference, ri: "jp" })

        assert_equal 303, browser.response.status
        browser.get("/sign/in", params: { ri: "jp" })
        csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')&.[]("content")
        headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" }
        headers["X-CSRF-Token"] = csrf if csrf
        Flipper.disable(feature)
        before = [
          binding.reload.attributes,
          realm.fetch(:ceremony_class).order(:id).map(&:attributes),
          realm.fetch(:sign_in_flow_class).order(:id).map(&:attributes),
          realm.fetch(:sign_up_flow_class).order(:id).map(&:attributes),
          realm.fetch(:actor_class).order(:id).map(&:attributes),
        ]

        if json
          browser.post(path, params: params.merge(ri: "jp"), headers:, as: :json)
        else
          browser.post(path, params: params.merge(ri: "jp"), headers:)
        end

        observed << [surface, "POST #{path}", browser.response.status,
                     browser.response.location && URI.parse(browser.response.location).path,]
        after = [
          binding.reload.attributes,
          realm.fetch(:ceremony_class).order(:id).map(&:attributes),
          realm.fetch(:sign_in_flow_class).order(:id).map(&:attributes),
          realm.fetch(:sign_up_flow_class).order(:id).map(&:attributes),
          realm.fetch(:actor_class).order(:id).map(&:attributes),
        ]
        changed_state << [surface, "POST #{path}", before != after]
        assert_equal "no-store", browser.response.headers["Cache-Control"] if browser.response.status == 503
      end

      callback = realm[:callback]
      next if callback.nil?

      start_path, callback_path, provider = callback
      Flipper.enable(feature)
      callback_transaction = OidcAuthorizationTransactionCoordinator.issue!(
        surface:,
        intent: "sign_in",
        params: {
          response_type: "code",
          client_id:,
          redirect_uri: client.redirect_uris_by_realm.fetch(client.resource_type).first,
          code_challenge: SecureRandom.urlsafe_base64(32),
          code_challenge_method: "S256",
          scope: "openid profile",
          state: SecureRandom.urlsafe_base64(24),
          nonce: SecureRandom.urlsafe_base64(24),
        },
      ).transaction
      callback_issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
        transaction: callback_transaction,
        base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
      )
      browser = open_session
      browser.host!(auth_host)
      browser.https!
      browser.get("/sign/in", params: { entry_ref: callback_issuance.reference, ri: "jp" })

      assert_equal 303, browser.response.status
      assert_equal "/ceremony_bindings", URI.parse(browser.response.location).path
      browser.get(browser.response.location)

      assert_equal 303, browser.response.status
      binding = realm.fetch(:binding_class).find_by!(entry_ref: callback_issuance.reference)
      binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
      browser.get("/sign/in", params: { entry_ref: callback_issuance.reference, ri: "jp" })

      assert_equal 303, browser.response.status
      browser.get("/sign/in", params: { ri: "jp" })
      csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')&.[]("content")
      headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" }
      headers["X-CSRF-Token"] = csrf if csrf
      browser.post(start_path, params: { ri: "jp" }, headers:)

      assert_equal 307, browser.response.status, "#{provider} provider request must start while ALLOWED"
      request_phase = URI.parse(browser.response.location)
      OmniAuth.config.test_mode = false if provider == :entra
      browser.post(request_phase.request_uri, params: { ri: "jp" }, headers:)
      OmniAuth.config.test_mode = true
      state_key = (provider == :entra) ? "omniauth.state" : SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY
      state = browser.session[state_key]
      state_location = URI.parse(browser.response.location) if browser.response.location

      assert_predicate state, :present?,
                       "#{provider} request phase must store callback state; HTTP #{browser.response.status}, " \
                       "location #{state_location&.host}#{state_location&.path}, " \
                       "session keys: #{browser.session.to_hash.keys.inspect}"
      binding = realm.fetch(:binding_class).find_by!(entry_ref: callback_issuance.reference)
      before = [
        binding.reload.attributes,
        realm.fetch(:ceremony_class).order(:id).map(&:attributes),
        realm.fetch(:sign_in_flow_class).order(:id).map(&:attributes),
        realm.fetch(:sign_up_flow_class).order(:id).map(&:attributes),
        realm.fetch(:actor_class).order(:id).map(&:attributes),
      ]
      Flipper.disable(feature)

      browser.get(callback_path, params: { state:, code: "blocked-provider-code", ri: "jp" })

      observed << [surface, "GET #{callback_path}", browser.response.status,
                   browser.response.location && URI.parse(browser.response.location).path,]
      after = [
        binding.reload.attributes,
        realm.fetch(:ceremony_class).order(:id).map(&:attributes),
        realm.fetch(:sign_in_flow_class).order(:id).map(&:attributes),
        realm.fetch(:sign_up_flow_class).order(:id).map(&:attributes),
        realm.fetch(:actor_class).order(:id).map(&:attributes),
      ]
      changed_state << [surface, "GET #{callback_path}", before != after]
      assert_equal "no-store", browser.response.headers["Cache-Control"] if browser.response.status == 503
    end

    assert_equal [], changed_state.select { |_surface, _request, changed| changed }
    expected_statuses =
      observed.map do |surface, request, _status, _location|
        [surface, request, ["POST /sign/in", "POST /ceremony_bindings"].include?(request) ? 404 : 503]
      end
    actual_statuses = observed.map { |surface, request, status, _location| [surface, request, status] }

    assert_equal expected_statuses,
                 actual_statuses,
                 "BLOCKED Sentry response matrix (locations: #{observed.map { |row| row.drop(1) }.inspect})"
  end
end
