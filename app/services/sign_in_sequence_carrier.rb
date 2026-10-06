# typed: false
# frozen_string_literal: true

class SignInSequenceCarrier
  KEY = :sign_in_sequence
  SURFACE_KEYS = {
    app: :app_sign_in_sequence,
    com: :com_sign_in_sequence,
    org: :org_sign_in_sequence,
  }.freeze
  TTL = 15.minutes

  def initialize(session, surface: nil)
    @session = session
    @surface = surface&.to_sym
  end

  def current
    SignInSequence.new(current_payload || {})
  end

  def start!(surface:, actor:, method:, state:, participant:, pt: nil, **refs)
    surface = normalize_surface(surface)
    raise ArgumentError, "unsupported sign-in sequence surface" unless surface
    raise ArgumentError, "unsupported sign-in sequence state" unless SignInSequence::STATES.include?(state.to_s)
    raise ArgumentError, "unsupported sign-in sequence participant" unless SignInSequence::PARTICIPANTS.include?(participant.to_s)

    now = Time.current
    payload = {
      "id" => SecureRandom.uuid,
      "surface" => surface.to_s,
      "actor_type" => actor.class.name,
      "actor_id" => actor.id,
      "entry_method" => method.to_s,
      "method" => method.to_s,
      "state" => state.to_s,
      "participant" => participant.to_s,
      "safe_pt_path" => pt.presence,
      "safe_return_path" => pt.presence,
      "pt" => pt.presence,
      "expires_at" => TTL.from_now.iso8601,
      "terminal_state" => nil,
      "created_at" => now.iso8601,
      "updated_at" => now.iso8601,
    }.merge(reference_payload(refs))

    @session[key_for(surface)] = payload
    @session.delete(KEY) unless key_for(surface) == KEY
    SignInSequence.new(payload)
  end

  def advance!(state:, participant:, **refs)
    sequence = current
    return sequence if sequence.blank?
    return sequence if sequence.terminal?
    raise ArgumentError, "unsupported sign-in sequence state" unless SignInSequence::STATES.include?(state.to_s)
    raise ArgumentError, "unsupported sign-in sequence participant" unless SignInSequence::PARTICIPANTS.include?(participant.to_s)

    payload = sequence.payload.merge(
      "state" => state.to_s,
      "participant" => participant.to_s,
      "expires_at" => TTL.from_now.iso8601,
      "updated_at" => Time.current.iso8601,
    ).merge(reference_payload(refs))
    @session[key_for(sequence.surface)] = payload
    SignInSequence.new(payload)
  end

  def expire!
    finish!(terminal_state: "EXPIRED")
  end

  def halt!
    finish!(terminal_state: "HALTED")
  end

  def complete!
    finish!(terminal_state: "COMPLETED")
  end

  def clear!
    surface = normalize_surface(@surface)
    @session.delete(key_for(surface)) if surface
    @session.delete(KEY)
  end

  def finish!(terminal_state:)
    sequence = current
    return sequence if sequence.blank?
    unless %w(COMPLETED EXPIRED HALTED).include?(terminal_state.to_s)
      raise ArgumentError, "unsupported sign-in sequence terminal state"
    end

    payload = sequence.payload.merge(
      "state" => terminal_state.to_s,
      "terminal_state" => terminal_state.to_s,
      "participant" => nil,
      "updated_at" => Time.current.iso8601,
    )
    @session[key_for(sequence.surface)] = payload
    SignInSequence.new(payload)
  end

  private

  def current_payload
    surface_key = key_for(@surface)
    payload = @session[surface_key] if surface_key.present?
    payload.presence || compatible_payload
  end

  def compatible_payload
    payload = @session[KEY]
    return unless payload.is_a?(Hash)
    return if @surface.present? && payload["surface"].to_s != @surface.to_s
    return unless key_for(payload["surface"])

    @session[key_for(payload["surface"])] = payload
    @session.delete(KEY)
    payload
  end

  def key_for(surface)
    SURFACE_KEYS[normalize_surface(surface)]
  end

  def normalize_surface(surface)
    value = surface&.to_sym || @surface
    return value if SURFACE_KEYS.key?(value)

    nil
  end

  def reference_payload(refs)
    {
      "mfa_challenge_id" => refs[:mfa_challenge_id].presence,
      "session_limit_gate_id" => refs[:session_limit_gate_id].presence,
      "restricted_login_public_id" => refs[:restricted_login_public_id].presence,
    }.compact
  end
end
