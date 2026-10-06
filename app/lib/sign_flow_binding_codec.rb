# typed: false
# frozen_string_literal: true

# Binds a phase-bound request to the flow instance its page was rendered for.
#
# The browser's session locator only names the flow that is current now. A page rendered for an
# earlier flow would otherwise be applied to whichever flow the locator names when the request
# arrives. The binding travels in Rails-generated step URLs so the server can tell which flow a
# request presumes without trusting a client-supplied id.
#
# It is not an authority: it carries only the surface, the flow kind, and the flow public id, and
# the session locator nonce still decides whether this browser may act on the flow. It is never
# reused as `pt`, an OAuth `state`, or a CSRF token, and the locator nonce is never part of it.
class SignFlowBindingCodec
  VERIFIER_NAME = :sign_flow_binding
  PURPOSE = "sign_flow_binding"
  KINDS = %w(sign_up).freeze
  SURFACES = %w(app com).freeze
  MAX_LENGTH = 512

  Binding = Data.define(:kind, :surface, :flow_public_id)

  private_constant :VERIFIER_NAME, :PURPOSE, :MAX_LENGTH

  def self.encode(flow:, surface:, kind: "sign_up")
    payload = { "k" => checked!(kind, KINDS, "kind"),
                "s" => checked!(surface, SURFACES, "surface"),
                "f" => flow.public_id, }
    Rails.application.message_verifier(VERIFIER_NAME).generate(payload, purpose: PURPOSE)
  end
  public_class_method :encode

  # Returns nil for anything that is not a binding this application signed: a missing, empty,
  # oversized, tampered, or differently purposed value.
  def self.decode(value)
    return nil unless value.is_a?(String) && value.length.between?(1, MAX_LENGTH)

    payload = Rails.application.message_verifier(VERIFIER_NAME).verified(value, purpose: PURPOSE)
    return nil unless payload.is_a?(Hash)

    kind = payload["k"]
    surface = payload["s"]
    flow_public_id = payload["f"]
    return nil unless KINDS.include?(kind) && SURFACES.include?(surface) && flow_public_id.is_a?(String) &&
      flow_public_id.present?

    Binding.new(kind: kind, surface: surface, flow_public_id: flow_public_id)
  end
  public_class_method :decode

  def self.checked!(value, allowed, label)
    normalized = value.to_s
    return normalized if allowed.include?(normalized)

    raise ArgumentError, "unsupported sign flow binding #{label}: #{value.inspect}"
  end
  private_class_method :checked!
end
