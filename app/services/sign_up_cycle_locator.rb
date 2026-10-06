# typed: false
# frozen_string_literal: true

class SignUpCycleLocator
  SESSION_KEYS = {
    app: :app_sign_up_flow_locator,
    com: :com_sign_up_flow_locator,
  }.freeze

  CYCLE_CLASSES = {
    app: ClientSignUpFlow,
    com: VisitorSignUpFlow,
  }.freeze

  NONCE_BYTES = 32

  def initialize(session, surface:, cycle_class: nil)
    @session = session
    @surface = normalize_surface(surface)
    @cycle_class = cycle_class || CYCLE_CLASSES.fetch(@surface)
  end

  def current
    payload = current_payload
    return nil unless payload

    cycle = cycle_class.current.find_by(public_id: payload.fetch("public_id"))
    return nil unless cycle
    return nil unless cycle.nonce_matches?(payload.fetch("nonce"))
    return nil if terminal?(cycle)

    cycle
  rescue KeyError
    nil
  end

  def issue!(cycle, nonce: new_nonce)
    ensure_supported_cycle!(cycle)
    cycle.class.connection_class_for_self.connected_to(role: :writing) do
      cycle.update!(nonce_digest: cycle.class.digest_nonce(nonce))
    end
    session[session_key] = {
      "public_id" => cycle.public_id,
      "nonce" => nonce,
    }
    cycle
  end

  def clear!
    session.delete(session_key)
  end

  private

  attr_reader :session, :surface, :cycle_class

  def current_payload
    payload = session[session_key]
    return payload.stringify_keys if payload.is_a?(Hash)

    nil
  end

  def terminal?(cycle)
    %w(COMPLETED FAILED EXPIRED CANCELLED HALTED).any? do |status_name|
      cycle.status_id == cycle.status_id_for(status_name)
    end
  end

  def ensure_supported_cycle!(cycle)
    return if cycle.is_a?(cycle_class)

    raise ArgumentError, "unsupported sign-up cycle"
  end

  def session_key
    SESSION_KEYS.fetch(surface)
  end

  def normalize_surface(value)
    normalized = value&.to_sym
    return normalized if SESSION_KEYS.key?(normalized)

    raise ArgumentError, "unsupported sign-up cycle surface"
  end

  def new_nonce
    SecureRandom.urlsafe_base64(NONCE_BYTES)
  end
end
