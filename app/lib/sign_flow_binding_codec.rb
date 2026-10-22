# typed: false
# frozen_string_literal: true

# Binds a phase-bound request to the flow instance its page was rendered for.
#
# The browser's session locator only names the flow that is current now. A page rendered for an
# earlier flow would otherwise be applied to whichever flow the locator names when the request
# arrives. The binding travels in Rails-generated step URLs so the server can tell which flow a
# request presumes without trusting a client-supplied id.
#
# It is not an authority: it carries the surface, flow kind, flow public id, the phase and
# checkpoint generation for the rendered page, and the flow expiry. The session locator nonce still
# decides whether this browser may act on the flow. It is never reused as `pt`, an OAuth `state`, or
# a CSRF token, and the locator nonce is never part of it.
class SignFlowBindingCodec
  VERIFIER_NAME = :sign_flow_binding
  PURPOSE = "sign_flow_binding"
  KINDS = %w(sign_up).freeze
  SURFACES = %w(app com).freeze
  MAX_LENGTH = 512

  Binding = Data.define(:kind, :surface, :flow_public_id, :phase, :generation, :expires_at)

  private_constant :VERIFIER_NAME, :PURPOSE, :MAX_LENGTH

  def self.encode(flow:, surface:, kind: "sign_up")
    phase = flow.respond_to?(:step) ? flow.step.to_s : flow[:step].to_s
    generation = flow.respond_to?(:checkpoint_version) ? flow.checkpoint_version : 0
    expires_at = flow.respond_to?(:expires_at) ? flow.expires_at : flow[:expires_at]
    expires_at = expires_at.to_i if expires_at.respond_to?(:to_i)
    unless phase.present? && generation.is_a?(Integer) && generation >= 0 &&
        expires_at.is_a?(Integer) && expires_at.positive?
      raise ArgumentError, "sign flow binding requires a persisted phase, generation, and expiry"
    end

    payload = { "k" => checked!(kind, KINDS, "kind"),
                "s" => checked!(surface, SURFACES, "surface"),
                "f" => flow.public_id,
                "p" => phase,
                "g" => generation,
                "e" => expires_at, }
    Rails.application.message_verifier(VERIFIER_NAME).generate(payload, purpose: PURPOSE)
  end
  public_class_method :encode

  # Returns nil for anything that is not a binding this application signed: a missing, empty,
  # oversized, tampered, or differently purposed value.
  def self.decode(value)
    return nil unless valid_encoded_value?(value)

    payload = Rails.application.message_verifier(VERIFIER_NAME).verified(value, purpose: PURPOSE)
    return nil unless payload.is_a?(Hash)

    kind, surface, flow_public_id, phase, generation, expires_at = payload.values_at("k", "s", "f", "p", "g", "e")
    generation = integer_value(generation)
    expires_at = integer_value(expires_at)
    return nil unless valid_payload?(kind, surface, flow_public_id, phase, generation, expires_at)

    Binding.new(
      kind: kind,
      surface: surface,
      flow_public_id: flow_public_id,
      phase: phase,
      generation: generation,
      expires_at: expires_at,
    )
  rescue ArgumentError, TypeError, JSON::ParserError
    nil
  end
  public_class_method :decode

  def self.valid_encoded_value?(value)
    value.is_a?(String) && value.length.between?(1, MAX_LENGTH)
  end
  private_class_method :valid_encoded_value?

  def self.integer_value(value)
    return value if value.is_a?(Integer)
    return unless value.is_a?(String) && value.match?(/\A\d+\z/)

    Integer(value, 10)
  end
  private_class_method :integer_value

  def self.valid_payload?(kind, surface, flow_public_id, phase, generation, expires_at)
    KINDS.include?(kind) && SURFACES.include?(surface) && flow_public_id.is_a?(String) &&
      flow_public_id.present? && phase.is_a?(String) && phase.present? && generation.is_a?(Integer) &&
      generation >= 0 && expires_at.is_a?(Integer) && expires_at.positive?
  end
  private_class_method :valid_payload?

  def self.checked!(value, allowed, label)
    normalized = value.to_s
    return normalized if allowed.include?(normalized)

    raise ArgumentError, "unsupported sign flow binding #{label}: #{value.inspect}"
  end
  private_class_method :checked!
end
