# frozen_string_literal: true

# APP/COM includers provide email_transaction_model and email_session_token. This row owns code
# generations and one-time proof; actor credential validity and durable failures are checked by
# the write operation. Delivery state records transport outcome independently of code consumption.
module StepUpEmailChallenge
  public

  def issue_bound_email_code!(transaction:, credential_ref:, code:)
    raise ArgumentError, "email credential required" unless credential_ref.is_a?(String) && credential_ref.present?

    self.class.connection_class_for_self.connected_to(role: :writing) do
      with_lock do
        transaction.with_lock do
          now = transaction.class.database_now
          raise IdentityStepUpCeremonyContract::Error, "email ceremony unavailable" unless email_transaction_pending?(
            transaction, now,
          )

          generation = email_code_generation + 1
          update!(
            email_credential_ref: credential_ref, email_code_generation: generation,
            email_code_digest: StepUpEmailCodeDigest.for(
              transaction: transaction, credential_ref: credential_ref,
              generation: generation, code: code,
            ),
            email_code_issued_at: now, email_code_expires_at: [now + 10.minutes, transaction.expires_at].min,
            email_code_consumed_at: nil, email_delivery_state: "pending",
          )
          generation
        end
      end
    end
  end

  def mark_bound_email_delivery!(transaction:, generation:, success:)
    raise ArgumentError, "delivery outcome must be boolean" unless success == true || success == false

    self.class.connection_class_for_self.connected_to(role: :writing) do
      with_lock do
        transaction.with_lock do
          now = transaction.class.database_now
          return false unless email_transaction_pending?(transaction, now) &&
            generation.is_a?(Integer) && generation.positive? && email_code_generation == generation &&
            email_code_expires_at && email_code_expires_at > now && email_delivery_state == "pending"

          update!(email_delivery_state: success ? "delivered" : "failed")
          true
        end
      end
    end
  end

  def consume_bound_email_code!(transaction:, credential_ref:, code:)
    self.class.connection_class_for_self.connected_to(role: :writing) do
      with_lock do
        transaction.with_lock do
          now = transaction.class.database_now
          return false unless email_transaction_pending?(transaction, now) &&
            email_credential_ref == credential_ref && email_delivery_state == "delivered" &&
            email_code_consumed_at.nil? && email_code_expires_at && email_code_expires_at > now &&
            code.is_a?(String) && code.match?(/\A[0-9]{6}\z/)

          digest = StepUpEmailCodeDigest.for(
            transaction: transaction, credential_ref: credential_ref,
            generation: email_code_generation, code: code,
          )
          return false unless ActiveSupport::SecurityUtils.secure_compare(email_code_digest, digest)

          update!(email_code_consumed_at: now)
          transaction.record_verification!(
            method: "email_otp", aal: "none", phishing_resistant: false, user_verified: false,
            verified_at: now, verified_credential_ref: credential_ref,
          )
          true
        end
      end
    end
  end

  private

  def email_transaction_pending?(transaction, now)
    transaction.is_a?(email_transaction_model) && step_up_ceremony_transaction_ref == transaction.transaction_id &&
      email_session_token.public_id == transaction.session_ref && transaction.purpose == "step_up" &&
      transaction.status == "pending" && !transaction.expired?(now: now) &&
      transaction.allowed_methods_array.include?("email_otp") && status == "PENDING" && discard_at > now
  end
end
