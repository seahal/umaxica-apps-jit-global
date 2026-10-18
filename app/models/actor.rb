# typed: false
# frozen_string_literal: true

# Actor is a request-lifecycle read facade over an already-installed
# ActorValuesContext snapshot.
#
# It is push-based: the controller/authentication pipeline resolves
# authentication, authorization, preference, selection, and step-up, then calls
# Actor.install_context!. Actor never rebuilds auth state from the request and
# never performs token decode, DB lookup, transparent refresh, DPoP/DBSC
# verification, preference hydration, or policy-user construction. It is a
# snapshot reader only.
#
# Actor.current / Actor.context return ActorValuesContext.empty when no context
# is installed, so they never raise merely because no request is bound.
class Actor < ActiveSupport::CurrentAttributes
  # Compatibility alias: ActionPolicy (ApplicationPolicy#actor_context) and
  # existing tests reference Actor::Context as the authorization context type.
  # ActorValuesContext is now the canonical class for that context.
  Context = ActorValuesContext

  attribute :context

  resets do
    self.context = ActorValuesContext.empty
  end

  class << self
    CONTEXT_KEY_ALIASES = { actor: :subject }.freeze

    delegate :account, to: :context

    delegate :tenant, to: :context

    delegate :tld, to: :context

    # Route/product surface axis, distinct from tld. See ActorValuesContext.
    delegate :surface, to: :context

    # Credential transport axis (cookie/bearer/none/unknown).
    delegate :transport, to: :context

    # Caller channel axis (browser/native/server/unknown).
    delegate :channel, to: :context

    delegate :trace_id, to: :context

    delegate :span_id, to: :context

    # Role predicates delegate to the installed context. They are role
    # predicates, not authorization gates: protected behavior must still go
    # through ActionPolicy / policy enforcement.
    delegate :client?, :operator?, :visitor?, :unauthenticated?, :authenticated?, to: :context

    # Transport/channel predicates. browser?/native? read channel; cookie?/
    # bearer? read transport. The two axes are not conflated.
    delegate :browser?, :native?, :cookie?, :bearer?, to: :context

    def context
      super || ActorValuesContext.empty
    end

    # The currently installed snapshot, or the empty context when nothing is
    # bound. Safe for bare paths, jobs, mailers, and tests.
    def current = context

    # Push-based lifecycle installer and the only supported write path.
    #
    # Accepts a full ActorValuesContext (positional) or a partial set of
    # attributes (keywords) merged onto the current snapshot. The keyword form
    # preserves the existing incremental-install behavior used across the
    # authentication pipeline. Must stay inside reviewed request lifecycle
    # boundaries (see actor_context_invariant_test).
    def install_context!(context = nil, **attributes)
      if context
        raise ArgumentError, "provide either a context or attributes, not both" if attributes.any?

        self.context = ActorValuesContext.coerce(context)
      else
        update(**attributes)
      end
    end

    def update(**attributes)
      self.context = context.with(**normalize_context_attributes(attributes))
    end

    def clear
      reset
    end

    # Alias for clear, for callers that prefer the reset! spelling.
    def reset! = clear

    def subject = context.subject || Unauthenticated.instance

    # Historical alias for subject, kept for lifecycle and policy compatibility.
    alias_method :actor, :subject

    def subject=(value)
      update(subject: value)
    end

    def actor=(value)
      update(subject: value)
    end

    def actor_type = context.actor_type || :unauthenticated

    def actor_type=(value)
      update(actor_type: value)
    end

    def whoami = actor_type

    def account=(value)
      update(account: value)
    end

    def tenant=(value)
      update(tenant: value)
    end

    def tld=(value)
      update(tld: value)
    end

    def authn = context.authn || Actor::Authentication::NULL

    def authn=(value)
      update(authn: value)
    end

    def authz = context.authz || Actor::Authz::NULL

    def authz=(value)
      update(authz: value)
    end

    def configuration = context.configuration || Actor::Configuration::NULL

    def configuration=(value)
      update(configuration: value)
    end

    def preferences = context.preferences || Actor::Preference::NULL

    def preferences=(value)
      update(preferences: value)
    end

    def selection = context.selection || Actor::SelectedContext::NULL

    def selection=(value)
      update(selection: value)
    end

    def step_up = context.step_up || Actor::StepUp::NULL

    def step_up=(value)
      update(step_up: value)
    end

    def trace_id=(value)
      update(trace_id: value)
    end

    def span_id=(value)
      update(span_id: value)
    end

    alias_method :signed_in?, :authenticated?

    def signed_up?
      return false unless authenticated?
      return true if actor.respond_to?(:persisted?) && actor.persisted?

      actor.respond_to?(:id) && actor.id.present?
    end

    # Spec-facing predicate aliases. The canonical names in this codebase are
    # unauthenticated?/client?/operator?; these mirror the actor-context vocabulary
    # (anonymous/user/staff) without introducing new state.
    def anonymous? = unauthenticated?

    def user? = client?

    def staff? = operator?

    # Step-up freshness, derived from the resolved step_up context. StepUpResolver
    # already enforces TTL + scope/aal/binding, so a satisfied step_up is a fresh one.
    def step_up_fresh? = step_up.satisfied?

    # True when the current request demands a step-up that is not yet satisfied.
    # When verification is not required, step_up is Actor::StepUp::NULL (scope nil),
    # so this is false.
    def requires_step_up?
      step_up.scope.present? && !step_up.satisfied?
    end

    def client
      actor if client?
    end

    def operator
      actor if operator?
    end

    def visitor
      actor if visitor?
    end

    private

    # Map legacy attribute keys onto canonical context fields and coerce blank
    # typed sub-values to their NULL objects. Unknown keys (e.g. the removed
    # :authentication / :preference keys) intentionally flow through to
    # Data#with, which raises ArgumentError.
    def normalize_context_attributes(attributes)
      attributes.each_with_object({}) do |(key, value), normalized|
        normalized_key = CONTEXT_KEY_ALIASES.fetch(key, key)
        normalized[normalized_key] = normalize_context_value(normalized_key, value)
      end
    end

    def normalize_context_value(key, value)
      case key
      when :preferences
        value || Actor::Preference::NULL
      when :authn
        value || Actor::Authentication::NULL
      when :authz
        value || Actor::Authz::NULL
      when :step_up
        value || Actor::StepUp::NULL
      when :configuration
        value || Actor::Configuration::NULL
      when :selection
        value || Actor::SelectedContext::NULL
      else
        value
      end
    end
  end
end
