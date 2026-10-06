# typed: false
# frozen_string_literal: true

class SignInCycleLocator
  SESSION_KEYS = {
    app: :app_sign_in_flow_locator,
    com: :com_sign_in_flow_locator,
    org: :org_sign_in_flow_locator,
  }.freeze

  CYCLE_CLASSES = {
    app: ClientSignInFlow,
    com: VisitorSignInFlow,
    org: OperatorSignInFlow,
  }.freeze

  ACTOR_CLASSES = {
    app: Client,
    com: Visitor,
    org: Operator,
  }.freeze

  TOKEN_CLASSES = {
    app: ClientToken,
    com: VisitorToken,
    org: OperatorToken,
  }.freeze

  NONCE_BYTES = 32

  def initialize(session, surface:, cycle_class: nil, actor: nil, token: nil, allow_principal_without_token: false)
    @session = session
    @surface = normalize_surface(surface)
    @cycle_class = cycle_class || CYCLE_CLASSES.fetch(@surface)
    @actor = actor
    @token = token
    @allow_principal_without_token = allow_principal_without_token
  end

  def current
    payload = current_payload
    return nil unless payload

    cycle = cycle_class.current.find_by(public_id: payload.fetch("public_id"))
    return nil unless cycle
    return nil unless cycle.nonce_matches?(payload.fetch("nonce"))
    return nil unless actor_binding_valid?(cycle)
    return nil unless token_binding_valid?(cycle)
    return nil if terminal?(cycle)

    cycle
  rescue KeyError
    nil
  end

  def issue!(cycle, nonce: new_nonce)
    ensure_supported_cycle!(cycle)
    persist_nonce!(cycle, nonce)
    store!(cycle: cycle, nonce: nonce)
    cycle
  end

  def rotate!(cycle)
    issue!(cycle)
  end

  def clear!
    session.delete(session_key)
  end

  private

  attr_reader :session, :surface, :cycle_class, :actor, :token

  def current_payload
    payload = session[session_key]
    return payload.stringify_keys if payload.is_a?(Hash)

    nil
  end

  def store!(cycle:, nonce:)
    session[session_key] = {
      "public_id" => cycle.public_id,
      "nonce" => nonce,
    }
  end

  def persist_nonce!(cycle, nonce)
    cycle.update!(nonce_digest: cycle.class.digest_nonce(nonce))
  end

  def actor_binding_valid?(cycle)
    return true if cycle.principal_id.blank?

    if actor.blank?
      # Without an authenticated actor, only an OIDC-started ceremony can be
      # resumed through the nonce this browser's session holds. Session-limit
      # continuation is authorized by its durable child transaction instead.
      return false if cycle.token_id.present?

      return @allow_principal_without_token
    end
    return false unless actor.is_a?(ACTOR_CLASSES.fetch(surface))

    actor.id == cycle.principal_id
  end

  def token_binding_valid?(cycle)
    return true if cycle.token_id.blank?
    return false unless token.is_a?(TOKEN_CLASSES.fetch(surface))

    token.id == cycle.token_id
  end

  def terminal?(cycle)
    cycle.sign_in_completed? || cycle.sign_in_failed?
  end

  def ensure_supported_cycle!(cycle)
    return if cycle.is_a?(cycle_class)

    raise ArgumentError, "unsupported sign-in cycle"
  end

  def session_key
    SESSION_KEYS.fetch(surface)
  end

  def normalize_surface(value)
    normalized = value&.to_sym
    return normalized if SESSION_KEYS.key?(normalized)

    raise ArgumentError, "unsupported sign-in cycle surface"
  end

  def new_nonce
    SecureRandom.urlsafe_base64(NONCE_BYTES)
  end
end
