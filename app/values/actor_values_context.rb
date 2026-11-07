# typed: false
# frozen_string_literal: true

# ActorValuesContext is the immutable value object that carries one request's
# resolved actor state. It is the canonical Actor context type: the controller
# /authentication pipeline resolves authentication, authorization, preference,
# selection, and step-up, builds (or merges into) an ActorValuesContext, and
# pushes it into Actor via Actor.install_context!.
#
# It is a pure value object. It performs no token decode, DB lookup, transparent
# refresh, DPoP/DBSC verification, or policy-user construction. Those belong to
# the request lifecycle, not to the snapshot.
#
# Axes:
#   tld       - app/com/org/net/dev tier axis. Kept distinct from surface.
#   surface   - acme/sign/core/base/palm/help/docs/news route/product surface.
#   transport - cookie/bearer/none/unknown credential transport axis.
#   channel   - browser/native/server/unknown caller channel axis.
#
# browser?/native? read channel; cookie?/bearer? read transport. These two axes
# are intentionally not conflated: a browser caller is not necessarily a cookie
# transport, and a native caller is not necessarily a bearer transport.
class ActorValuesContext < Data.define(
  :subject,
  :actor_type,
  :account,
  :tenant,
  :tld,
  :surface,
  :transport,
  :channel,
  :authn,
  :authz,
  :configuration,
  :preferences,
  :selection,
  :step_up,
  :trace_id,
  :span_id,
)
  TLDS = %i(app com org net dev).freeze
  SURFACES = %i(acme sign core base palm help docs news unknown).freeze
  TRANSPORTS = %i(cookie bearer none unknown).freeze
  CHANNELS = %i(browser native server unknown).freeze

  # Actor role predicates depend on actor_type. These are role predicates, not
  # authorization gates -- protected behavior must still go through ActionPolicy.
  ACTOR_TYPES = %i(client operator unauthenticated).freeze
  ROLE_TYPES = %i(client operator).freeze

  class << self
    # The safe baseline context for unbound paths: BareController, jobs,
    # mailers, tests, and any request before the lifecycle installs state.
    def empty
      new(
        subject: Unauthenticated.instance,
        actor_type: :unauthenticated,
        account: nil,
        tenant: nil,
        tld: nil,
        surface: :unknown,
        transport: :none,
        channel: :unknown,
        authn: Actor::Authentication::NULL,
        authz: Actor::Authz::NULL,
        configuration: Actor::Configuration::NULL,
        preferences: Actor::Preference::NULL,
        selection: Actor::SelectedContext::NULL,
        step_up: Actor::StepUp::NULL,
        trace_id: nil,
        span_id: nil,
      )
    end

    # Normalize an installed value into an ActorValuesContext. Accepts an
    # existing ActorValuesContext (returned as-is), nil (the empty context), or
    # an attribute hash / to_h-able object merged onto the empty baseline.
    # Unknown keys raise ArgumentError via Data#with.
    def coerce(context)
      case context
      when ActorValuesContext
        context
      when nil
        empty
      when Hash
        empty.with(**context)
      else
        unless context.respond_to?(:to_h)
          raise ArgumentError, "cannot coerce #{context.class} into ActorValuesContext"
        end

        empty.with(**context.to_h)
      end
    end
  end

  # Validate the enum axes at construction so invalid values fail fast rather
  # than silently flowing through policies and logs.
  def initialize(tld:, surface:, transport:, channel:, **rest)
    validate_axis!(:actor_type, rest.fetch(:actor_type), ACTOR_TYPES)
    validate_axis!(:tld, tld, TLDS, allow_nil: true)
    validate_axis!(:surface, surface, SURFACES)
    validate_axis!(:transport, transport, TRANSPORTS)
    validate_axis!(:channel, channel, CHANNELS)
    super
  end

  # subject is the canonical authenticated-principal slot. `actor` is the
  # historical alias retained for ActionPolicy and lifecycle compatibility.
  alias_method :actor, :subject

  def authenticated? = ROLE_TYPES.include?(actor_type)

  def unauthenticated? = actor_type == :unauthenticated

  def anonymous? = unauthenticated?

  def operator? = actor_type == :operator

  def client? = actor_type == :client

  def browser? = channel == :browser

  def native? = channel == :native

  def cookie? = transport == :cookie

  def bearer? = transport == :bearer

  private

  def validate_axis!(name, value, allowed, allow_nil: false)
    return if allow_nil && value.nil?
    return if allowed.include?(value)

    permitted = allowed.map(&:inspect).join(", ")
    permitted += ", nil" if allow_nil
    raise ArgumentError, "invalid #{name}: #{value.inspect} (allowed: #{permitted})"
  end
end
