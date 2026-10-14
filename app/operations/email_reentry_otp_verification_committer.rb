# frozen_string_literal: true

class EmailReentryOtpVerificationCommitter
  class << self
    public

    def call(email:, transaction_ref:, session_ref:, operation:, code:)
      surface, transaction_model = components(email)
      purpose = budget_purpose(operation)
      return false if surface == :org && operation == "withdrawal"

      email.with_lock do
        now = email.class.database_now
        next false if email.locked?(now: now)

        transaction = transaction_model.find_by(transaction_id: transaction_ref)
        next false unless transaction

        transaction.with_lock do
          next false unless transaction.normalized_email_digest == email.address_digest

          verified =
            transaction.verify_email_otp!(
              code: code, purpose: operation, actor_ref: owner_reference(email), session_ref: session_ref,
              operation: operation, candidate_ref: email.public_id,
            ) do |valid|
              status = EmailOtpVerificationFailureBudget.new.verify!(
                surface: surface, purpose: purpose, channel: :email,
                destination_digest: email.address_digest, valid: valid,
              )
              email.increment_attempts! unless valid
              status == :verified
            end
          next false unless verified

          email.update!(otp_attempts_count: 0, locked_at: EmailOtpPolicy::OTP_UNLOCKED_SENTINEL)
          true
        end
      end
    end

    private

    def budget_purpose(operation)
      case operation
      when "recovery" then :enforcement_recovery
      when "withdrawal" then :withdrawal_reentry
      else raise ArgumentError, "unsupported email reentry operation"
      end
    end

    def components(email)
      case email
      when ClientEmail then [:app, ClientEmailCeremonyTransaction]
      when VisitorEmail then [:com, VisitorEmailCeremonyTransaction]
      when OperatorEmail then [:org, OperatorEmailCeremonyTransaction]
      else raise ArgumentError, "unsupported reentry email identifier"
      end
    end

    def owner_reference(email)
      case email
      when ClientEmail then Client.find(email.user_id).public_id
      when VisitorEmail then Visitor.find(email.visitor_id).public_id
      when OperatorEmail then Operator.find(email.staff_id).public_id
      else raise ArgumentError, "unsupported reentry email identifier"
      end
    end
  end
end
