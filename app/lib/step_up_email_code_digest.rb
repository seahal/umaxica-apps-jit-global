# frozen_string_literal: true

class StepUpEmailCodeDigest
  class << self
    public

    def for(transaction:, credential_ref:, generation:, code:)
      unless generation.is_a?(Integer) && generation.positive? && code.is_a?(String) && code.match?(/\A[0-9]{6}\z/)
        raise ArgumentError, "invalid step-up email code"
      end

      # Fixed tuple: purpose, surface, actor, session, transaction, credential, generation, code.
      binding = JSON.generate(
        [
          "step_up.email_otp", transaction.surface, transaction.actor_ref, transaction.session_ref,
          transaction.transaction_id, credential_ref, generation, code,
        ],
      )
      key = Rails.application.key_generator.generate_key("step_up_email_code_digest", 32)
      OpenSSL::HMAC.hexdigest("SHA256", key, binding)
    end
  end
end
