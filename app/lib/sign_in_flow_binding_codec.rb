# typed: false
# frozen_string_literal: true

# Signs the instance and phase that a sign-in page was rendered for.
#
# The binding is request context, not authentication authority. The browser's sign-in locator,
# actor/token binding, and the database flow lock remain separate checks. In particular, this value
# never contains the locator nonce and is not interchangeable with OAuth state, PKCE, CSRF, or `pt`.
class SignInFlowBindingCodec
  VERIFIER_NAME = :sign_in_flow_binding
  PURPOSE = "sign_in_flow_binding"
  KIND = "sign_in"
  SURFACES = %w(app com org).freeze
  MAX_LENGTH = 768
  TTL = 15.minutes

  Binding = Data.define(:kind, :surface, :flow_public_id, :phase, :generation, :expires_at)

  private_constant :VERIFIER_NAME, :PURPOSE, :KIND, :MAX_LENGTH, :TTL

  class << self
    public

    def encode(flow:, surface:, phase:)
      normalized_surface = checked_surface(surface)
      normalized_phase = checked_phase(flow, phase)
      generation = generation_for(flow)
      expires_at = expiry_for(flow)

      Rails.application.message_verifier(VERIFIER_NAME).generate(
        {
          "k" => KIND,
          "s" => normalized_surface,
          "f" => flow.public_id.to_s,
          "p" => normalized_phase,
          "g" => generation,
          "e" => expires_at,
        },
        purpose: PURPOSE,
        expires_in: TTL,
      )
    end

    def decode(value)
      return nil unless value.is_a?(String) && value.length.between?(1, MAX_LENGTH)

      payload = Rails.application.message_verifier(VERIFIER_NAME).verified(value, purpose: PURPOSE)
      return nil unless payload.is_a?(Hash)
      return nil unless payload["k"] == KIND && SURFACES.include?(payload["s"])
      return nil unless payload["f"].is_a?(String) && payload["f"].present?
      return nil unless payload["p"].is_a?(String) && payload["p"].present?
      return nil unless payload["g"].is_a?(String) && payload["g"].present?
      return nil unless positive_integer?(payload["e"])

      Binding.new(
        kind: payload["k"],
        surface: payload["s"],
        flow_public_id: payload["f"],
        phase: payload["p"],
        generation: payload["g"],
        expires_at: payload["e"].to_i,
      )
    rescue ActiveSupport::MessageVerifier::InvalidSignature, JSON::ParserError
      nil
    end

    def generation_for(flow)
      timestamp = flow.issued_at
      raise ArgumentError, "sign-in flow generation is required" unless timestamp.respond_to?(:utc)

      timestamp.utc.iso8601(6)
    end
    private :generation_for

    def expiry_for(flow)
      timestamp = flow.expires_at
      raise ArgumentError, "sign-in flow expiry is required" unless timestamp.respond_to?(:to_i)

      value = timestamp.to_i
      raise ArgumentError, "sign-in flow expiry must be positive" unless value.positive?

      value
    end
    private :expiry_for

    def positive_integer?(value)
      value.is_a?(Integer) ? value.positive? : value.to_s.match?(/\A[1-9][0-9]*\z/)
    end
    private :positive_integer?

    def checked_surface(surface)
      normalized = surface.to_s
      return normalized if SURFACES.include?(normalized)

      raise ArgumentError, "unsupported sign-in flow binding surface: #{surface.inspect}"
    end
    private :checked_surface

    def checked_phase(flow, phase)
      normalized = phase.to_s
      state_names = flow.class.const_get(:STATE_NAMES, false).values
      return normalized if state_names.include?(normalized)

      raise ArgumentError, "unsupported sign-in flow binding phase: #{phase.inspect}"
    end
    private :checked_phase
  end
end
