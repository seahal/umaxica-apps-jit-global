# typed: false
# frozen_string_literal: true

# Signs the provider-owned transaction that connects the Entra callback to the
# second-stage org passkey request. This is deliberately separate from
# SignInFlowBindingCodec: the normal org transaction is session-backed and has
# no durable sign-in-flow row in every admission path.
class OrgNormalSignInBindingCodec
  VERIFIER_NAME = :org_normal_sign_in_binding
  PURPOSE = "org_normal_sign_in_binding"
  KIND = "org_normal_sign_in"
  SURFACE = "org"
  PHASE = "PRIMARY_PENDING"
  MAX_LENGTH = 768
  TTL = 15.minutes

  Binding = Data.define(:kind, :surface, :transaction_public_id, :phase, :generation, :expires_at)

  private_constant :VERIFIER_NAME, :PURPOSE, :KIND, :SURFACE, :PHASE, :MAX_LENGTH, :TTL

  class << self
    public

    def encode(transaction:, surface:, phase:)
      normalized_surface = checked_surface(surface)
      normalized_phase = checked_phase(phase)
      public_id = transaction.fetch("public_id").to_s
      generation = generation_for(transaction)
      expires_at = expiry_for(transaction)
      raise ArgumentError, "org normal sign-in transaction public id is required" if public_id.blank?

      Rails.application.message_verifier(VERIFIER_NAME).generate(
        {
          "k" => KIND,
          "s" => normalized_surface,
          "t" => public_id,
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
      return nil unless payload["k"] == KIND && payload["s"] == SURFACE
      return nil unless payload["t"].is_a?(String) && payload["t"].present?
      return nil unless payload["p"] == PHASE
      return nil unless payload["g"].is_a?(String) && positive_integer?(payload["g"])
      return nil unless positive_integer?(payload["e"])

      Binding.new(
        kind: payload["k"],
        surface: payload["s"],
        transaction_public_id: payload["t"],
        phase: payload["p"],
        generation: payload["g"],
        expires_at: payload["e"].to_i,
      )
    rescue ActiveSupport::MessageVerifier::InvalidSignature, JSON::ParserError
      nil
    end

    private

    def checked_surface(surface)
      normalized = surface.to_s
      return normalized if normalized == SURFACE

      raise ArgumentError, "unsupported org normal sign-in binding surface: #{surface.inspect}"
    end

    def checked_phase(phase)
      normalized = phase.to_s
      return normalized if normalized == PHASE

      raise ArgumentError, "unsupported org normal sign-in binding phase: #{phase.inspect}"
    end

    def generation_for(transaction)
      value = transaction.fetch("issued_at")
      return value.to_s if value.to_i.positive?

      raise ArgumentError, "org normal sign-in transaction generation is required"
    end

    def expiry_for(transaction)
      value = transaction.fetch("expires_at").to_i
      return value if value.positive?

      raise ArgumentError, "org normal sign-in transaction expiry must be positive"
    end

    def positive_integer?(value)
      value.is_a?(Integer) ? value.positive? : value.to_s.match?(%r{\A[1-9][0-9]*\z})
    end
  end
end
