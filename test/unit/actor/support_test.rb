# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ActorSupportTest < ActiveSupport::TestCase
  # Minimal test host that includes the concern, simulating a controller.
  class Host
    include ActiveSupport::Callbacks

    define_callbacks :action

    # Stub controller callback macros expected by ActorSupport.
    def self.after_action(*, **) = nil

    def self.before_action(*, **) = nil

    def self.prepend_before_action(*, **) = nil

    include ActorSupport

    # Expose private methods for testing.
    public :set_current_observability, :resolved_resource_preference
    public :resolved_current_session, :resolved_current_token, :resolved_current_preference
    public :resolved_current_restricted_session?, :resolved_current_step_up
    public :current_policy_user, :resolved_current_step_up_scope, :resolved_current_step_up_required_aal
  end

  setup do
    Actor.reset
    @host = Host.new
  end

  teardown { Actor.reset }

  # --- set_current_observability ---

  test "set_current_observability is no-op when OpenTelemetry is not loaded" do
    @host.set_current_observability

    assert_nil Actor.trace_id
    assert_nil Actor.span_id
  end

  test "set_current_observability does not mutate unrelated Actor attributes" do
    Actor.actor = "existing_actor"
    Actor.tld = :app

    @host.set_current_observability

    assert_equal "existing_actor", Actor.actor
    assert_equal :app, Actor.tld
  end

  test "set_current_observability keeps trace correlation when performant cookie is not consented" do
    # Default preference has performant? == false
    assert_not Actor.preferences.cookie.performant?

    hex_trace_id = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4"
    span_context = Minitest::Mock.new
    span_context.expect(:valid?, true)
    span_context.expect(:hex_trace_id, hex_trace_id)

    span = Minitest::Mock.new
    span.expect(:context, span_context)

    otel_trace = Module.new
    otel_trace.define_singleton_method(:current_span) { span }

    stub_const(:OpenTelemetry, Module.new { const_set(:Trace, otel_trace) }) do
      @host.set_current_observability
    end

    assert_equal hex_trace_id, Actor.trace_id
    assert_nil Actor.span_id, "span_id must not be set without performant consent"
  end

  test "set_current_observability sets trace_id and span_id when performant is consented" do
    cookie = Actor::Preference::Cookie.new(
      consented: true, functional: true, performant: true,
      targetable: false, consent_version: "1", consented_at: Time.current,
    )
    Actor.install_context!(preferences: Actor::Preference.new(cookie: cookie))

    hex_trace_id = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4"
    hex_span_id = "f1e2d3c4b5a6f1e2"

    span_context = Minitest::Mock.new
    span_context.expect(:valid?, true)
    span_context.expect(:hex_trace_id, hex_trace_id)
    span_context.expect(:hex_span_id, hex_span_id)

    span = Minitest::Mock.new
    span.expect(:context, span_context)

    otel_trace = Module.new
    otel_trace.define_singleton_method(:current_span) { span }

    stub_const(:OpenTelemetry, Module.new { const_set(:Trace, otel_trace) }) do
      @host.set_current_observability
    end

    assert_equal hex_trace_id, Actor.trace_id
    assert_equal hex_span_id, Actor.span_id

    span_context.verify
    span.verify
  end

  test "set_current_observability skips when span context is invalid" do
    cookie = Actor::Preference::Cookie.new(
      consented: true, functional: true, performant: true,
      targetable: false, consent_version: "1", consented_at: Time.current,
    )
    Actor.install_context!(preferences: Actor::Preference.new(cookie: cookie))

    span_context = Minitest::Mock.new
    span_context.expect(:valid?, false)

    span = Minitest::Mock.new
    span.expect(:context, span_context)

    otel_trace = Module.new
    otel_trace.define_singleton_method(:current_span) { span }

    stub_const(:OpenTelemetry, Module.new { const_set(:Trace, otel_trace) }) do
      @host.set_current_observability
    end

    assert_nil Actor.trace_id
    assert_nil Actor.span_id

    span_context.verify
    span.verify
  end

  test "set_current_observability can be overridden by subclass" do
    custom_host_class =
      Class.new(Host) do
        define_method(:set_current_observability) do
          Actor.trace_id = "custom_trace"
        end
      end

    custom_host_class.new.set_current_observability

    assert_equal "custom_trace", Actor.trace_id
  end

  # --- resolved_resource_preference does NOT call set_current_observability ---

  test "resolved_resource_preference does not call set_current_observability" do
    called = false
    host_class =
      Class.new(Host) do
        define_method(:set_current_observability) do
          called = true
        end
      end

    resource = Object.new
    resource.define_singleton_method(:user_preference) { nil }

    host_class.new.resolved_resource_preference(resource)

    assert_not called, "set_current_observability must not be called during preference resolution"
  end

  test "resolved_resource_preference does not memoize nil results" do
    preference = Object.new
    resource = Object.new
    current_preference = nil
    resource.define_singleton_method(:user_preference) { current_preference }

    assert_nil @host.resolved_resource_preference(resource)

    current_preference = preference

    assert_same preference, @host.resolved_resource_preference(resource)
    assert_not @host.instance_variable_defined?(resolved_resource_preference_memo_name)
  end

  test "resolved_resource_preference resets loaded Active Record association before reading" do
    user = Client.create!(
      status_id: ClientStatus::ACTIVE,
      public_id: SecureRandom.hex(10),
      created_at: Time.current,
      updated_at: Time.current,
    )
    preference = ClientPreference.create!(
      user: user,
      language: "ja",
      region: "jp",
      timezone: "Asia/Tokyo",
      theme: "sy",
    )

    assert_equal "ja", user.user_preference.language
    assert_predicate user.association(:user_preference), :loaded?

    ClientPreference.find(preference.id).update!(language: "en")

    assert_equal "en", @host.resolved_resource_preference(user).language
    assert_not @host.instance_variable_defined?(resolved_resource_preference_memo_name)
  end

  test "safe_current_resource resolves controller resource when current actor is unauthenticated singleton" do
    host_class =
      Class.new(Host) do
        define_method(:current_resource) do
          :resolved_resource
        end

        public :safe_current_resource
      end

    Actor.actor = Unauthenticated.instance

    assert_equal :resolved_resource, host_class.new.safe_current_resource
  end

  test "safe_current_resource resolves from current_resource instead of existing Actor state" do
    host_class =
      Class.new(Host) do
        define_method(:current_resource) do
          :resolved_resource
        end

        public :safe_current_resource
      end

    Actor.actor = :existing_actor

    assert_equal :resolved_resource, host_class.new.safe_current_resource
  end

  test "resolved_current_session ignores existing Actor authentication cache" do
    Actor.install_context!(authn: Actor::Authentication.new(login_public_id: "existing-session"))
    @host.define_singleton_method(:access_token_payload) do
      { "sid" => "token-session" }
    end

    assert_equal "token-session", @host.resolved_current_session
  end

  test "resolved_current_session falls back to request session public id" do
    @host.instance_variable_set(:@current_session_public_id, "header-session")

    assert_equal "header-session", @host.resolved_current_session
  end

  test "resolved_current_session falls back to token sid" do
    @host.define_singleton_method(:access_token_payload) do
      { "sid" => "token-session" }
    end

    assert_equal "token-session", @host.resolved_current_session
  end

  test "resolved_current_token prefers access_token_payload over existing authentication claims" do
    Actor.install_context!(authn: Actor::Authentication.new(access_claims: { "sid" => "existing-cache" }))
    @host.define_singleton_method(:access_token_payload) do
      { "sid" => "from-access", "prf" => { "lx" => "en" } }
    end

    assert_equal({ "sid" => "from-access", "prf" => { "lx" => "en" } }, @host.resolved_current_token)
  end

  test "resolved_current_token falls back to load_access_token_payload" do
    @host.define_singleton_method(:load_access_token_payload) do
      { "sid" => "from-load" }
    end

    assert_equal({ "sid" => "from-load" }, @host.resolved_current_token)
  end

  test "resolved_current_token ignores non-hash payloads" do
    @host.define_singleton_method(:access_token_payload) { "not-a-hash" }

    assert_nil @host.resolved_current_token
  end

  test "resolved_current_token raises resolution errors" do
    @host.define_singleton_method(:access_token_payload) do
      raise StandardError, "boom"
    end

    error =
      assert_raises(ActorSupport::ResolutionError) do
        @host.resolved_current_token
      end

    assert_match "Actor access_token resolution failed", error.message
    assert_equal "boom", error.cause.message
  end

  test "safe_current_resource raises resolution errors" do
    host_class =
      Class.new(Host) do
        define_method(:current_resource) do
          raise StandardError, "boom"
        end

        public :safe_current_resource
      end

    error =
      assert_raises(ActorSupport::ResolutionError) do
        host_class.new.safe_current_resource
      end

    assert_match "Actor current_resource resolution failed", error.message
  end

  test "resolved_current_restricted_session raises resolution errors" do
    @host.define_singleton_method(:current_session_restricted?) do
      raise StandardError, "boom"
    end
    error =
      assert_raises(ActorSupport::ResolutionError) do
        @host.resolved_current_restricted_session?
      end

    assert_match "Actor restricted_session resolution failed", error.message
  end

  test "resolved_current_step_up raises resolution errors" do
    @host.define_singleton_method(:current_session_token) do
      raise StandardError, "boom"
    end
    error =
      assert_raises(ActorSupport::ResolutionError) do
        @host.resolved_current_step_up
      end

    assert_match "Actor step_up resolution failed", error.message
  end

  test "current_policy_user reads actor authz before controller fallback" do
    Actor.install_context!(authz: Actor::Authz.new(policy_user: :actor_policy_user, token_claims: {}, surface: "app"))
    @host.define_singleton_method(:current_resource) { :controller_resource }

    assert_equal :actor_policy_user, @host.current_policy_user
  end

  test "current_policy_user falls back to current resource" do
    @host.define_singleton_method(:current_resource) { :controller_resource }

    assert_equal :controller_resource, @host.current_policy_user
  end

  test "resolved_current_step_up uses required verification scope and aal" do
    @host.define_singleton_method(:verification_required?) { true }
    @host.define_singleton_method(:verification_scope) { "settings_secret_credential" }
    @host.define_singleton_method(:verification_required_aal) { :aal3 }

    assert_equal "settings_secret_credential", @host.resolved_current_step_up_scope
    assert_equal :aal3, @host.resolved_current_step_up_required_aal
  end

  test "resolved_current_preference ignores database preference record without jwt prf" do
    user = Client.create!(
      status_id: ClientStatus::ACTIVE,
      public_id: SecureRandom.hex(10),
      created_at: Time.current,
      updated_at: Time.current,
    )
    ClientPreference.create!(
      user: user,
      language: "en",
      region: "us",
      timezone: "America/New_York",
      theme: "dr",
      currency: "usd",
      date_format: "mdy",
      time_format: "hour_12",
      motion: "reduced",
      density: "compact",
      page_size: "50",
      consented: true,
      functional: true,
      performant: false,
      targetable: true,
      consent_version: SecureRandom.uuid,
      consented_at: Time.current,
    )

    preference = @host.resolved_current_preference(user)

    assert_not preference.null?
    assert_equal "ja", preference.language
    assert_equal "jp", preference.region
    assert_equal "Asia/Tokyo", preference.timezone
    assert_equal "sy", preference.theme
    assert_equal Actor::Preference::NULL_COOKIE, preference.cookie
  end

  test "resolved_current_preference ignores auth prf claim when no preference record exists" do
    @host.define_singleton_method(:access_token_payload) do
      {
        "prf" => {
          "lx" => "en",
          "ri" => "us",
          "tz" => "America/New_York",
          "ct" => "dr",
          "cu" => "usd",
          "df" => "mdy",
          "tf" => "hour_12",
          "mo" => "reduced",
          "dn" => "compact",
          "ps" => "50",
        },
      }
    end

    preference = @host.resolved_current_preference(nil)

    # prf is dead transport: with no Preference JWT payload, hydration falls back
    # to the default preference values rather than reading the prf claim.
    assert_not preference.null?
    assert_equal "ja", preference.language
    assert_equal "jp", preference.region
    assert_equal "Asia/Tokyo", preference.timezone
    assert_equal "sy", preference.theme
    assert_equal "jpy", preference.currency
    assert_equal "iso", preference.date_format
    assert_equal "24", preference.time_format
    assert_equal "standard", preference.motion
    assert_equal "standard", preference.density
    assert_equal "infinity", preference.page_size
    assert_equal Actor::Preference::NULL_COOKIE, preference.cookie
  end

  test "resolved_current_preference hydrates from the preference payload" do
    # Actor.preferences is hydrated from the Preference JWT payload (the signed
    # projection of the DB SSoT), with the explicit-fields marker preserved.
    @host.define_singleton_method(:preference_payload_preferences) do
      {
        "lx" => "en",
        "ri" => "us",
        "tz" => "America/New_York",
        "ct" => "dr",
        "explicit" => ["language"],
      }
    end

    preference = @host.resolved_current_preference(nil)

    assert_not preference.null?
    assert_predicate preference, :language_explicit?
    assert_equal "en", preference.language
    assert_equal "us", preference.region
    assert_equal "America/New_York", preference.timezone
    assert_equal "dr", preference.theme
  end

  test "resolved_current_preference falls back to default preference values" do
    preference = @host.resolved_current_preference(nil)

    assert_not preference.null?
    assert_equal "ja", preference.language
    assert_equal "jp", preference.region
    assert_equal "Asia/Tokyo", preference.timezone
    assert_equal "sy", preference.theme
    assert_equal Actor::Preference::NULL_COOKIE, preference.cookie
  end

  private

  # Temporarily define a top-level constant for the duration of the block.
  def stub_const(name, value)
    existed = Object.const_defined?(name)
    old_value = existed ? resolve_const(name) : nil
    Object.const_set(name, value)
    yield
  ensure
    if existed
      Object.send(:remove_const, name)
      Object.const_set(name, old_value)
    else
      Object.send(:remove_const, name)
    end
  end

  def resolve_const(name)
    case name
    when :OpenTelemetry then OpenTelemetry
    end
  end

  def resolved_resource_preference_memo_name
    :"@resolved_resource_#{"preference"}"
  end
end
