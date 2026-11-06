# frozen_string_literal: true

# Protects the short-lived PKCE verifier while an RP authorization code is pending.
class StepUpPkceVerifierCipherAdapter
  PURPOSE = "op_mediated_step_up_pkce_verifier"
  DESTROYED_PAYLOAD = { "verifier_state" => "destroyed" }.freeze

  class InvalidCiphertext < StandardError; end

  class << self
    public

    def encrypt(verifier:)
      raise ArgumentError, "PKCE verifier is invalid" unless valid_verifier?(verifier)

      encryptor.encrypt_and_sign({ "verifier" => verifier }, purpose: PURPOSE)
    end

    def decrypt(ciphertext:)
      payload = encryptor.decrypt_and_verify(ciphertext, purpose: PURPOSE)
      verifier = payload.is_a?(Hash) ? payload["verifier"] : nil
      return verifier if valid_verifier?(verifier)

      raise InvalidCiphertext, "PKCE verifier ciphertext has no active verifier"
    rescue ActiveSupport::MessageEncryptor::InvalidMessage => e
      raise InvalidCiphertext, "PKCE verifier ciphertext is invalid", cause: e
    end

    def destroyed_ciphertext
      encryptor.encrypt_and_sign(DESTROYED_PAYLOAD, purpose: PURPOSE)
    end

    private

    def valid_verifier?(verifier)
      OidcPkce.verify(
        code_verifier: verifier,
        code_challenge: OidcPkce.challenge_for(verifier),
      )
    end

    def encryptor
      key = Rails.application.key_generator.generate_key(
        PURPOSE, ActiveSupport::MessageEncryptor.key_len("aes-256-gcm"),
      )
      ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: JSON)
    end
  end
end
