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

  # Capability gate consumed by ApplicationPolicy's pre-check.
  #
  # An Emergency session is fully authenticated, so it answers to the same
  # policy rules as a Normal one. Its restriction is that Step-Up is unavailable
  # (step_up_permitted?), so an operation is withheld from it by giving that
  # operation a Step-Up gate. An unrecognised context still denies every rule
  # rather than falling through to Normal.
  def permits_rule?(_rule)
    normal? || emergency?
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
