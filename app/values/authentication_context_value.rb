# typed: false
# frozen_string_literal: true

# Closed enumeration of the authentication context a session was established
# under. It answers one question -- "which sign-in ceremony produced this
# session?" -- and it is the only place that decides what an Emergency session
# may exercise.
#
# This is deliberately distinct from the session-limit "restricted" state on
# Actor::Authentication, which marks a session awaiting session-management
# remediation. A session can be normal and session-limit restricted at the same
# time; the two axes never collapse into one flag.
#
# It is also distinct from Webauthn::AuthenticationContext, which is the result
# of one WebAuthn assertion (UV flags, AAGUID, transports). This value describes
# the session, not a ceremony response.
#
# Authority: the durable value lives on the session token row
# (`operator_tokens.authentication_context`) and is re-derived into the access
# token's `authn_ctx` claim on every issue, refresh, and rotation, so a
# continuation can never silently produce a Normal session from an Emergency one.
class AuthenticationContextValue
  class UnknownContextError < StandardError; end

  # The access-token claim carrying this value. Short, because it is minted on
  # every access token; `authn_ctx` is unambiguous next to `acr`/`amr`.
  CLAIM = "authn_ctx"

  NORMAL_KEY = "normal"
  EMERGENCY_KEY = "emergency"

  # Capability vocabulary. These are session capabilities, never role grants:
  # they can only narrow what the actor's DB roles already allow.
  CAPABILITY_STEP_UP = "step_up"
  CAPABILITY_ORG_READ = "read:org"
  CAPABILITY_ORG_WRITE = "write:org"

  # The only policy rules a Restricted Mode session may reach. Read rules only:
  # Emergency Access exists to see operational state while the Entra path is
  # unavailable, not to act. Widening this list is a security decision and
  # belongs in docs/security/org-emergency-access.md.
  EMERGENCY_PERMITTED_RULES = %i(index? show?).freeze

  attr_reader :key, :capabilities

  def initialize(key, capabilities:)
    @key = key
    @capabilities = capabilities.map(&:to_s).freeze
    freeze
  end

  def normal? = key == NORMAL_KEY

  def emergency? = key == EMERGENCY_KEY

  def permits?(capability) = capabilities.include?(capability.to_s)

  # Step-Up is an authentication-context capability, not a freshness question.
  # An Emergency session is not eligible to perform Step-Up-protected
  # operations at all, however valid the Operator's Step-Up credential is.
  def step_up_permitted? = permits?(CAPABILITY_STEP_UP)

  def to_s = key

  # Default-deny capability gate consumed by ApplicationPolicy's pre-check.
  #
  # A Normal session is unconstrained here and answers to its DB roles alone.
  # Every other context is an allowlist: a rule that is not named is denied, so
  # a sensitive action added later is unavailable to a Restricted Mode session
  # by default rather than by a developer remembering to guard it.
  def permits_rule?(rule)
    return true if normal?
    return false unless emergency?

    EMERGENCY_PERMITTED_RULES.include?(rule.to_sym)
  end

  REGISTRY = {
    NORMAL_KEY => new(
      NORMAL_KEY,
      capabilities: [CAPABILITY_STEP_UP, CAPABILITY_ORG_READ, CAPABILITY_ORG_WRITE],
    ),
    EMERGENCY_KEY => new(
      EMERGENCY_KEY,
      capabilities: [CAPABILITY_ORG_READ],
    ),
  }.freeze

  KEYS = REGISTRY.keys.freeze

  # Fail-closed context for a claim value this build does not know. It carries
  # no capabilities at all, so an unrecognised or tampered-with `authn_ctx`
  # denies rather than falling through to Normal.
  UNKNOWN = new("unknown", capabilities: []).freeze

  def self.normal = REGISTRY.fetch(NORMAL_KEY)

  def self.emergency = REGISTRY.fetch(EMERGENCY_KEY)

  # Strict lookup for issue-time call sites, which must never mint a session
  # under a context this build cannot enumerate.
  def self.for(key)
    return key if key.is_a?(self)

    REGISTRY.fetch(key.to_s) do
      raise UnknownContextError,
            "Unknown authentication context: #{key.inspect} (expected one of #{KEYS.inspect})"
    end
  end

  # Lenient lookup for verification-time call sites reading an already-signed
  # token. A blank claim is a Normal session (the claim postdates existing
  # sessions); anything else unrecognised resolves to UNKNOWN, never Normal.
  def self.from_claim(value)
    return normal if value.blank?

    REGISTRY.fetch(value.to_s, UNKNOWN)
  end

  def self.from_claims(claims)
    return normal unless claims.is_a?(Hash)

    from_claim(claims[CLAIM] || claims[CLAIM.to_sym])
  end

  # Session capabilities constrain the authorization scopes a token carries;
  # they never add one that the actor's ordinary scopes did not already grant.
  def constrain_scopes(scopes)
    return Array(scopes) if normal?

    Array(scopes).select do |scope|
      !scope_capability_governed?(scope) || permits?(scope)
    end
  end

  private

  # Only the capability-named scopes are filtered. Structural scopes
  # (`authenticated`, `domain:operator`) describe what the token is, not what it
  # may do, and removing them would break audience/actor resolution.
  def scope_capability_governed?(scope)
    [CAPABILITY_ORG_READ, CAPABILITY_ORG_WRITE, "read:self", "write:self"].include?(scope.to_s)
  end
end
