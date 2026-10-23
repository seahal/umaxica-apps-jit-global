# typed: false
# frozen_string_literal: true

require "test_helper"

class ActorTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup { Actor.reset }
  teardown { Actor.reset }

  test "stores actor state in current attributes" do
    user = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 123)
    Actor.actor = user
    Actor.actor_type = :client

    assert_equal user, Actor.actor
    assert_equal :client, Actor.actor_type
    assert_equal user, Actor.client
    assert_predicate Actor, :client?
    assert_predicate Actor, :authenticated?
  end

  test "stores request context values in current attributes" do
    preference = Actor::Preference.new(language: "en", theme: "dr")
    Actor.account = "account-1"
    Actor.tenant = "tenant-1"
    Actor.tld = :app
    Actor.install_context!(
      authn: Actor::Authentication.new(
        login_public_id: "session-1",
        access_claims: { "sub" => "123" },
      ),
    )
    Actor.install_context!(preferences: preference)
    Actor.trace_id = "trace-1"
    Actor.span_id = "span-1"

    assert_equal "account-1", Actor.account
    assert_equal "tenant-1", Actor.tenant
    assert_equal :app, Actor.tld
    assert_equal "session-1", Actor.authn.login_public_id
    assert_equal({ "sub" => "123" }, Actor.authn.access_claims)
    assert_equal preference, Actor.preferences
    assert_equal "trace-1", Actor.trace_id
    assert_equal "span-1", Actor.span_id
  end

  test "old authentication and preference compatibility readers are removed" do
    assert_not_respond_to Actor, :authentication
    assert_not_respond_to Actor, :authentication=
    assert_not_respond_to Actor, :preference
    assert_not_respond_to Actor, :preference=
  end

  test "install context does not accept old authentication and preference keys" do
    assert_raises(ArgumentError) do
      Actor.install_context!(authentication: Actor::Authentication::NULL)
    end

    assert_raises(ArgumentError) do
      Actor.install_context!(preference: Actor::Preference::NULL)
    end
  end

  test "whoami aliases actor type" do
    Actor.actor_type = :visitor

    assert_equal :visitor, Actor.whoami
  end

  test "tld stores surface label" do
    Actor.tld = :dev

    assert_equal :dev, Actor.tld
  end

  test "context updates replace immutable snapshot" do
    original = Actor.context

    Actor.actor_type = :client

    assert_instance_of Actor::Context, original
    assert_instance_of Actor::Context, Actor.context
    assert_not_same original, Actor.context
    assert_equal :unauthenticated, original.actor_type
    assert_equal :client, Actor.context.actor_type
  end

  test "clear empties current actor context" do
    Actor.actor = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 123)
    Actor.actor_type = :client
    Actor.install_context!(
      authn: Actor::Authentication.new(
        login_public_id: "session-1",
        access_claims: { "sub" => "123" },
      ),
    )
    Actor.configuration = Actor::Configuration.new(foo: "bar")
    Actor.install_context!(preferences: Actor::Preference.new(language: "en"))
    Actor.trace_id = "trace-1"
    Actor.span_id = "span-1"

    Actor.clear

    assert_same Unauthenticated.instance, Actor.actor
    assert_equal :unauthenticated, Actor.actor_type
    assert_equal Actor::Authentication::NULL, Actor.authn
    assert_equal Actor::Configuration::NULL, Actor.configuration
    assert_equal Actor::Preference::NULL, Actor.preferences
    assert_nil Actor.trace_id
    assert_nil Actor.span_id
  end

  test "authentication access claims are recursively frozen" do
    Actor.install_context!(
      authn: Actor::Authentication.new(
        access_claims: { "scp" => ["read:self"], "prf" => { "lx" => "ja" } },
      ),
    )

    assert_predicate Actor.authn.access_claims, :frozen?
    assert_predicate Actor.authn.access_claims["scp"], :frozen?
    assert_predicate Actor.authn.access_claims["prf"], :frozen?
  end

  test "anonymous aliases the unauthenticated state" do
    assert_predicate Actor, :anonymous?
    assert_not_predicate Actor, :user?
    assert_not_predicate Actor, :staff?

    Actor.actor_type = :client

    assert_not_predicate Actor, :anonymous?
  end

  test "user predicate aliases client actor" do
    Actor.actor_type = :client

    assert_predicate Actor, :user?
    assert_not_predicate Actor, :staff?
  end

  test "staff predicate aliases operator actor" do
    Actor.actor_type = :operator

    assert_predicate Actor, :staff?
    assert_not_predicate Actor, :user?
  end

  test "step up null returns true for NULL and false for non-null" do
    assert_predicate Actor::StepUp::NULL, :null?
    assert_not Actor::StepUp::NULL.with(scope: "email").null?
    assert_not Actor::StepUp::NULL.with(satisfied: true).null?
  end

  test "step up predicates are false when no step up is required" do
    assert_equal Actor::StepUp::NULL, Actor.step_up
    assert_not_predicate Actor, :step_up_fresh?
    assert_not_predicate Actor, :requires_step_up?
  end

  test "requires step up is true when a scope is required but unsatisfied" do
    Actor.install_context!(
      step_up: Actor::StepUp::NULL.with(scope: "settings_email", satisfied: false),
    )

    assert_predicate Actor, :requires_step_up?
    assert_not_predicate Actor, :step_up_fresh?
  end

  test "step up fresh is true and requires step up is false when satisfied" do
    Actor.install_context!(
      step_up: Actor::StepUp::NULL.with(scope: "settings_email", satisfied: true),
    )

    assert_predicate Actor, :step_up_fresh?
    assert_not_predicate Actor, :requires_step_up?
  end

  test "current returns the empty context before any install" do
    assert_equal ActorValuesContext.empty, Actor.current
    assert_equal :unauthenticated, Actor.current.actor_type
  end

  test "install_context! installs a full ActorValuesContext positionally" do
    context = ActorValuesContext.empty.with(actor_type: :client, tld: :app, surface: :sign)
    Actor.install_context!(context)

    assert_same context, Actor.context
    assert_equal :app, Actor.tld
    assert_equal :sign, Actor.surface
  end

  test "install_context! rejects passing both a context and attributes" do
    assert_raises(ArgumentError) do
      Actor.install_context!(ActorValuesContext.empty, tld: :app)
    end
  end

  test "clear and reset! both empty the current context" do
    Actor.actor_type = :client
    Actor.tld = :app

    Actor.reset!

    assert_equal ActorValuesContext.empty, Actor.current

    Actor.actor_type = :operator
    Actor.clear

    assert_equal ActorValuesContext.empty, Actor.current
  end

  test "subject and actor are the same compatibility slot" do
    user = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 7)
    Actor.actor = user

    assert_equal user, Actor.subject
    assert_equal user, Actor.actor
  end

  test "compatibility setters update the installed context" do
    user = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 8)

    Actor.subject = user
    Actor.authn = Actor::Authentication.new(login_public_id: "session-8")
    Actor.authz = nil
    Actor.preferences = nil
    Actor.selection = nil
    Actor.step_up = nil

    assert_equal user, Actor.subject
    assert_equal user, Actor.actor
    assert_equal Actor::Authz::NULL, Actor.authz
    assert_equal Actor::Preference::NULL, Actor.preferences
    assert_equal Actor::SelectedContext::NULL, Actor.selection
    assert_equal Actor::StepUp::NULL, Actor.step_up
  end

  test "surface is a separate axis from tld" do
    Actor.install_context!(tld: :app, surface: :sign)

    assert_equal :app, Actor.tld
    assert_equal :sign, Actor.surface
    assert_not_equal Actor.tld, Actor.surface
  end

  test "channel drives browser and native predicates" do
    Actor.install_context!(channel: :browser)

    assert_predicate Actor, :browser?
    assert_not_predicate Actor, :native?

    Actor.install_context!(channel: :native)

    assert_predicate Actor, :native?
    assert_not_predicate Actor, :browser?
  end

  test "transport drives cookie and bearer predicates" do
    Actor.install_context!(transport: :cookie)

    assert_predicate Actor, :cookie?
    assert_not_predicate Actor, :bearer?

    Actor.install_context!(transport: :bearer)

    assert_predicate Actor, :bearer?
    assert_not_predicate Actor, :cookie?
  end

  test "browser channel does not imply cookie transport" do
    Actor.install_context!(channel: :browser, transport: :bearer)

    assert_predicate Actor, :browser?
    assert_not_predicate Actor, :cookie?
  end

  test "invalid surface transport or channel fails fast at construction" do
    assert_raises(ArgumentError) { ActorValuesContext.empty.with(surface: :bogus) }
    assert_raises(ArgumentError) { ActorValuesContext.empty.with(transport: :bogus) }
    assert_raises(ArgumentError) { ActorValuesContext.empty.with(channel: :bogus) }
    assert_raises(ArgumentError) { ActorValuesContext.empty.with(tld: :bogus) }
  end

  test "Actor::Context is an alias of ActorValuesContext" do
    assert_same ActorValuesContext, Actor::Context
    assert_instance_of Actor::Context, Actor.current
  end

  test "coerce returns an ActorValuesContext as-is" do
    context = ActorValuesContext.empty.with(actor_type: :client, tld: :app, surface: :sign)

    assert_same context, ActorValuesContext.coerce(context)
  end

  test "coerce converts nil to the empty context" do
    result = ActorValuesContext.coerce(nil)

    assert_equal ActorValuesContext.empty, result
    assert_predicate result, :unauthenticated?
  end

  test "coerce merges a hash onto the empty baseline" do
    result = ActorValuesContext.coerce(actor_type: :client, tld: :app, surface: :sign)

    assert_equal :client, result.actor_type
    assert_equal :app, result.tld
    assert_equal :sign, result.surface
  end

  test "coerce merges a to_h-able object onto the empty baseline" do
    obj = Struct.new(:actor_type, :tld, :surface, :transport, :channel).new(:visitor, :com, :acme, :cookie, :browser)

    result = ActorValuesContext.coerce(obj)

    assert_equal :visitor, result.actor_type
    assert_equal :com, result.tld
    assert_equal :acme, result.surface
    assert_predicate result, :cookie?
    assert_predicate result, :browser?
  end

  test "coerce raises ArgumentError for objects that do not respond to to_h" do
    assert_raises(ArgumentError) { ActorValuesContext.coerce(42) }
    assert_raises(ArgumentError) { ActorValuesContext.coerce("string") }
  end
end
