# frozen_string_literal: true

# Correlation references for Step-Up ceremony logs. The key is derived for observability only, so a
# reference cannot be recomputed from an identifier by anyone who holds neither the key nor the log.
# Each kind is domain-separated: the same identifier never yields the same reference twice.
class StepUpObservabilityDigest
  KEY_SALT = "step_up_observability_digest"
  REFERENCE_HEX_LENGTH = 32

  class << self
    public

    def ceremony_ref(transaction_id) = reference("ceremony", transaction_id)

    def session_ref(session_public_id) = reference("session", session_public_id)

    def jump_jti_ref(jti) = reference("jump_jti", jti)

    private

    def reference(kind, identifier)
      raise ArgumentError, "#{kind} identifier is blank" unless identifier.is_a?(String) && identifier.present?

      key = Rails.application.key_generator.generate_key(KEY_SALT, 32)
      OpenSSL::HMAC.hexdigest("SHA256", key, JSON.generate([kind, identifier]))[0, REFERENCE_HEX_LENGTH]
    end
  end
end
