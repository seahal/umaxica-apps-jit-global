# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::Omniauth::OmniauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  # Rate-limit counters are a NullStore by default in test so unrelated tests
  # cannot accumulate them; this file asserts real limiting behavior, so it
  # opts into a deterministic MemoryStore.
  rate_limit_counters!

  TENANT_ID = "11111111-2222-3333-4444-555555555555"
  CLIENT_ID = "22222222-3333-4444-5555-666666666666"
  OBJECT_ID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

  # The strategy reads tenant and client from ProviderRegistry, which reads the
  # deployment's credentials. They are replaced with fixed test values for the
  # duration of each test so the suite never depends on, or asserts against,
  # real credential values. Swapped as singleton methods rather than with a
  # `stub` block because the strategy runs inside the request, outside any
  # block this test could wrap.
  def stub_configured_tenant!
    registry = ExternalAuthentication::ProviderRegistry
    @registry_originals =
      %i(tenant_id audience issuer_for).index_with do |name|
        registry.method(name)
      end
    tenant = TENANT_ID
    client = CLIENT_ID
    registry.define_singleton_method(:tenant_id) { |_provider| tenant }
    registry.define_singleton_method(:audience) { |_provider| client }
    registry.define_singleton_method(:issuer_for) { |_provider| "https://login.microsoftonline.com/#{tenant}/v2.0" }
  end

  def restore_configured_tenant!
    registry = ExternalAuthentication::ProviderRegistry
    @registry_originals&.each { |name, method| registry.define_singleton_method(name, method) }
  end

  setup do
    # Other suites (e.g. test/integration/social_auth_login_test.rb) set
    # OmniAuth.config.test_mode = true and never restore it. Left on, OmniAuth
    # short-circuits the request phase into a mocked callback, so the real
    # strategy under test here never runs.
    @previous_omniauth_test_mode = OmniAuth.config.test_mode
    OmniAuth.config.test_mode = false

    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
    Rails.configuration.x.rate_limit.fetch(:store).clear
    OrganizationEntraConnectionState.ensure_defaults!
    OperatorEntraIdentityState.ensure_defaults!
    stub_configured_tenant!
  end

  teardown do
    restore_configured_tenant!
    Rails.configuration.x.rate_limit.fetch(:store).clear
    OmniAuth.config.test_mode = @previous_omniauth_test_mode
  end

  test "GET /social/entra/session/new is routable and renders the start form" do
    get new_auth_org_social_entra_session_path(ri: "jp")

    assert_response :success
  end

  test "POST /social/entra redirects to the tenant-fixed Microsoft authorize endpoint" do
    post "/social/entra", params: {}

    assert_response :found
    uri = URI.parse(response.location)

    assert_equal "login.microsoftonline.com", uri.host
    assert_equal "/#{TENANT_ID}/oauth2/v2.0/authorize", uri.path

    query = Rack::Utils.parse_nested_query(uri.query)

    assert_equal "openid profile", query.fetch("scope")
    assert_equal "S256", query.fetch("code_challenge_method")
    assert_not_includes uri.query, "common"
    assert_not_includes uri.query, "organizations"
  end

  test "full round trip: request phase then callback establishes an operator session for a pre-provisioned identity" do
    operator = operators(:one)
    OperatorEntraIdentity.create!(
      operator_id: operator.id,
      connection_id: nil,
      entra_tenant_id: TENANT_ID,
      entra_object_id: OBJECT_ID,
      status_id: OperatorEntraIdentityState::ACTIVE,
    )

    post "/social/entra", params: {}

    assert_response :found
    authorize_uri = URI.parse(response.location)
    authorize_query = Rack::Utils.parse_nested_query(authorize_uri.query)
    state = authorize_query.fetch("state")
    nonce = authorize_query.fetch("nonce")

    private_key = OpenSSL::PKey::RSA.generate(2048)
    jwk = JWT::JWK.new(private_key, { "kid" => "test-kid-round-trip" })
    jwks_loader = ->(_opts) { { "keys" => [jwk.export] } }
    now = Time.now.to_i
    id_token = JWT.encode(
      {
        "iss" => "https://login.microsoftonline.com/#{TENANT_ID}/v2.0",
        "aud" => CLIENT_ID,
        "tid" => TENANT_ID,
        "oid" => OBJECT_ID,
        "sub" => "pairwise-sub",
        "acct" => 0,
        "ver" => "2.0",
        "nonce" => nonce,
        "iat" => now,
        "exp" => now + 3600,
      },
      private_key, "RS256", { "kid" => "test-kid-round-trip" },
    )

    stub_entra_access_token(id_token) do
      ExternalSignIn::EntraJwksCache.stub(
        :new, ->(**) {
                loader_double = Object.new
                loader_double.define_singleton_method(:loader) { jwks_loader }
                loader_double
              },
      ) do
        get "/social/entra/callback", params: { state: state, code: "authorization-code" }
      end
    end

    assert_response :redirect
    assert_not response.location.to_s.include?("/social/entra/failure")
  end

  test "callback fails closed when no OperatorEntraIdentity is provisioned (no JIT)" do
    post "/social/entra", params: {}
    authorize_query = Rack::Utils.parse_nested_query(URI.parse(response.location).query)
    state = authorize_query.fetch("state")
    nonce = authorize_query.fetch("nonce")

    private_key = OpenSSL::PKey::RSA.generate(2048)
    jwk = JWT::JWK.new(private_key, { "kid" => "test-kid-no-identity" })
    jwks_loader = ->(_opts) { { "keys" => [jwk.export] } }
    now = Time.now.to_i
    id_token = JWT.encode(
      {
        "iss" => "https://login.microsoftonline.com/#{TENANT_ID}/v2.0",
        "aud" => CLIENT_ID,
        "tid" => TENANT_ID,
        "oid" => OBJECT_ID,
        "sub" => "pairwise-sub",
        "acct" => 0,
        "ver" => "2.0",
        "nonce" => nonce,
        "iat" => now,
        "exp" => now + 3600,
      },
      private_key, "RS256", { "kid" => "test-kid-no-identity" },
    )

    stub_entra_access_token(id_token) do
      ExternalSignIn::EntraJwksCache.stub(
        :new, ->(**) {
                loader_double = Object.new
                loader_double.define_singleton_method(:loader) { jwks_loader }
                loader_double
              },
      ) do
        get "/social/entra/callback", params: { state: state, code: "authorization-code" }
      end
    end

    assert_response :unprocessable_content
  end

  # Both callbacks end in 422, so the status alone cannot tell "consumed the
  # state, then failed later" apart from "rejected at the state check". The
  # failure reason carried on the redirect is what actually distinguishes them,
  # and is therefore what this asserts.
  test "callback rejects a replayed state" do
    post "/social/entra", params: {}
    state = Rack::Utils.parse_nested_query(URI.parse(response.location).query).fetch("state")

    # First callback: the state is valid, so the ceremony gets past the CSRF
    # check and fails at the token exchange instead.
    stub_entra_token_exchange_error(:invalid_grant) do
      get "/social/entra/callback", params: { state: state, code: "authorization-code" }
    end

    assert_response :found
    assert_equal "invalid_grant", failure_message_from(response.location)
    follow_redirect!

    assert_response :unprocessable_content

    # Replay: the state was consumed by the first callback, so this one is
    # rejected at the CSRF check and never reaches the token exchange.
    get "/social/entra/callback", params: { state: state, code: "authorization-code" }

    assert_response :found
    assert_equal "csrf_detected", failure_message_from(response.location)
    follow_redirect!

    assert_response :unprocessable_content
  end

  test "app-surface OmniAuth providers are rejected on the org host" do
    post "/social/google", params: {}

    assert_response :not_found
  end

  # Phase 14: OmniAuth.config.allowed_request_methods = [:post] is set
  # globally in config/initializers/omniauth.rb and applies to every
  # mounted strategy, including Entra -- there is no per-provider override
  # to verify separately.
  test "GET /social/entra (request phase) is rejected; only POST starts the ceremony" do
    get "/social/entra", params: {}

    assert_response :not_found
  end

  # --- parity with the legacy Auth::Org::Sign::In::Entra::* suite ---

  test "session/new is unreachable from the app surface host" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")

    get new_auth_org_social_entra_session_path(ri: "jp")

    assert_response :not_found
  end

  test "session/new is unreachable from the com surface host" do
    host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")

    get new_auth_org_social_entra_session_path(ri: "jp")

    assert_response :not_found
  end

  test "POST /social/entra is unreachable from the app surface host" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")

    post "/social/entra", params: {}

    assert_response :not_found
  end

  test "POST /social/entra is unreachable from the com surface host" do
    host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")

    post "/social/entra", params: {}

    assert_response :not_found
  end

  test "GET /social/entra/callback is unreachable from the app surface host" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")

    get "/social/entra/callback", params: { state: "irrelevant", code: "irrelevant" }

    assert_response :not_found
  end

  test "GET /social/entra/callback is unreachable from the com surface host" do
    host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")

    get "/social/entra/callback", params: { state: "irrelevant", code: "irrelevant" }

    assert_response :not_found
  end

  test "request phase fails closed when the Entra provider is unavailable" do
    disabled = Object.new
    disabled.define_singleton_method(:start_decision) { |**|
      ExternalAuthentication::AvailabilityDecision.new(
        state: :disabled, source: "test", configuration_version: nil, reason_code: "test_disabled",
        incident_id: nil, observed_at: Time.current,
      )
    }

    # Stubs the availability factory rather than mutating real ENV, so this
    # test cannot leak state into other tests under parallel execution.
    ExternalAuthentication::ProviderAvailabilityFactory.stub(:current, disabled) do
      post("/social/entra", params: {})
    end

    assert_response :found
    assert_match %r{\A/social/entra/failure}, response.location
  end

  test "callback renders error when the operator's entra method is locked by an in-force method_protection case" do
    operator = operators(:one)
    admin_operator = operators(:two)
    OperatorEntraIdentity.create!(
      operator_id: operator.id,
      connection_id: nil,
      entra_tenant_id: TENANT_ID,
      entra_object_id: OBJECT_ID,
      status_id: OperatorEntraIdentityState::ACTIVE,
    )
    the_case = OrgEnforcementCase.new(
      kind: "method_protection",
      duration_mode: "indefinite",
      visibility: "visible",
      release_mode: "operator",
      effective_at: Time.current,
      reason_code: "security_incident",
      principal_public_id: operator.public_id,
      applied_by_operator_public_id: admin_operator.public_id,
    )
    the_case.authentication_method_effects.build(
      principal_public_id: operator.public_id,
      authentication_method: "entra",
      effect: "unusable",
      effective_at: Time.current,
    )
    EnforcementCaseApplyOperation.call(enforcement_case: the_case)

    post "/social/entra", params: {}
    authorize_query = Rack::Utils.parse_nested_query(URI.parse(response.location).query)
    state = authorize_query.fetch("state")
    nonce = authorize_query.fetch("nonce")

    private_key = OpenSSL::PKey::RSA.generate(2048)
    jwk = JWT::JWK.new(private_key, { "kid" => "test-kid-locked" })
    jwks_loader = ->(_opts) { { "keys" => [jwk.export] } }
    now = Time.now.to_i
    id_token = JWT.encode(
      {
        "iss" => "https://login.microsoftonline.com/#{TENANT_ID}/v2.0",
        "aud" => CLIENT_ID,
        "tid" => TENANT_ID,
        "oid" => OBJECT_ID,
        "sub" => "pairwise-sub",
        "acct" => 0,
        "ver" => "2.0",
        "nonce" => nonce,
        "iat" => now,
        "exp" => now + 3600,
      },
      private_key, "RS256", { "kid" => "test-kid-locked" },
    )

    # With a matching state/nonce and an active identity + active operator,
    # this would otherwise succeed -- the 422 here proves the authentication
    # method lock check fires, not an earlier verification failure.
    stub_entra_access_token(id_token) do
      ExternalSignIn::EntraJwksCache.stub(
        :new, ->(**) {
                loader_double = Object.new
                loader_double.define_singleton_method(:loader) { jwks_loader }
                loader_double
              },
      ) do
        get "/social/entra/callback", params: { state: state, code: "authorization-code" }
      end
    end

    assert_response :unprocessable_content
  end

  test "failure endpoint renders the classified error for a known message" do
    get "/social/entra/failure", params: { message: "connection_not_found" }

    assert_response :unprocessable_content
  end

  test "failure endpoint classifies an unknown message and keeps it out of the response" do
    injected = "attacker-supplied-marker-9f3c"

    get "/social/entra/failure", params: { message: injected }

    assert_response :unprocessable_content
    assert_not_includes response.body, injected
  end

  # Asserted against the application event this controller emits, not the whole
  # buffer: Rails' own request logger always echoes the request URL and
  # parameters for every endpoint, which is generic framework behavior. The
  # boundary under test is the callback_failure event
  # (adr/application-logging-boundary.md).
  test "failure endpoint never emits the raw message parameter in its failure event" do
    injected = "attacker-supplied-marker-9f3c"

    logs =
      capture_logs do
        get("/social/entra/failure", params: { message: injected })
      end

    event = entra_callback_failure_event(logs)

    assert_not_includes event, injected
    assert_equal "entra_error", JSON.parse(event).fetch("data").fetch("message")
  end

  test "failure endpoint emits the allowlisted classification for a known message" do
    logs =
      capture_logs do
        get("/social/entra/failure", params: { message: "pkce_verifier_missing" })
      end

    event = entra_callback_failure_event(logs)

    assert_equal "pkce_verifier_missing", JSON.parse(event).fetch("data").fetch("message")
  end

  test "the failure endpoint serves requests below its limit and 429s above it" do
    with_rate_limit_counters do
      20.times do |attempt|
        get "/social/entra/failure", params: { message: "connection_not_found" }

        assert_response :unprocessable_content, "request #{attempt + 1} should still be inside the budget"
      end

      get "/social/entra/failure", params: { message: "connection_not_found" }

      assert_response :too_many_requests
      assert_equal "60", response.headers["Retry-After"]
    end
  end

  # The two limits must not share a counter: failure traffic must not consume the
  # callback budget, or an attacker could lock a staff member out of a legitimate
  # callback by hammering the public, unauthenticated failure endpoint.
  #
  # Asserted on the counter keys rather than by driving the callback: the
  # OmniAuth middleware answers /social/entra/callback for an unverified request
  # and the controller's callback limiter is never reached, so a request-level
  # test would pass whether or not the buckets are shared.
  test "the failure limit and the callback limit use separate counters" do
    store = ActiveSupport::Cache::MemoryStore.new

    with_rate_limit_counters(store) do
      get "/social/entra/failure", params: { message: "connection_not_found" }
    end

    keys = memory_store_keys(store)

    assert_includes keys, "rate-limit:auth_org_sign_in_entra_failure:omniauth_failure_ip_burst:127.0.0.1"
    assert_not(
      keys.any? { |key| key.include?("omniauth_callback_ip_burst") },
      "the failure endpoint must not increment the callback counter, got #{keys.inspect}",
    )
    assert_not(
      keys.any? { |key| key.include?(":auth_org_sign_in_entra:") },
      "the failure endpoint must not share the callback scope, got #{keys.inspect}",
    )
  end

  private

  # Both Rails.logger and ActionController::Base.logger are swapped: the
  # controller logs through Rails.logger, but request logging goes through the
  # controller logger, and an unswapped one would let the raw parameter reach
  # the real log without the assertion noticing.
  def capture_logs
    buffer = StringIO.new
    capture_logger = ActiveSupport::Logger.new(buffer)
    previous_rails_logger = Rails.logger
    previous_controller_logger = ActionController::Base.logger
    Rails.logger = capture_logger
    ActionController::Base.logger = capture_logger

    yield

    buffer.string
  ensure
    Rails.logger = previous_rails_logger
    ActionController::Base.logger = previous_controller_logger
  end

  def entra_callback_failure_event(logs)
    line = logs.lines.find { |candidate| candidate.include?("sign.org.authentication.entra.callback_failure") }

    assert_not_nil line, "expected a callback_failure event in the captured log"
    line
  end

  def failure_message_from(location)
    Rack::Utils.parse_nested_query(URI.parse(location).query).fetch("message", nil)
  end

  # MemoryStore has no public key enumeration; the rate-limit assertions above
  # need the counter names the request actually wrote.
  def memory_store_keys(store)
    store.instance_variable_get(:@data).keys.map(&:to_s)
  end

  # Fails the token exchange without contacting Microsoft. The unstubbed path
  # posts the real client id and secret to login.microsoftonline.com on every
  # run, which makes the suite depend on outbound network reachability and on
  # Microsoft returning a particular error for a fabricated code.
  def stub_entra_token_exchange_error(reason, &)
    strategy_class = OmniAuth::Strategies::UmaxicaEntra
    original = strategy_class.instance_method(:access_token)
    strategy_class.define_method(:access_token) do
      raise OmniAuth::Strategies::UmaxicaEntra::Error, reason
    end
    yield
  ensure
    strategy_class.define_method(:access_token, original)
  end

  def stub_entra_access_token(id_token, &)
    strategy_class = OmniAuth::Strategies::UmaxicaEntra
    original = strategy_class.instance_method(:access_token)
    strategy_class.define_method(:access_token) do
      verify_id_token!(id_token)
      OpenStruct.new(id_token: id_token)
    end
    yield
  ensure
    strategy_class.define_method(:access_token, original)
  end
end
