# frozen_string_literal: true

class EmailReentryOtpIssuer
  class << self
    public

    def call(email:, operation:, session_ref:)
      unless %w(recovery withdrawal).include?(operation)
        raise ArgumentError, "unsupported email reentry operation"
      end
      unless session_ref.is_a?(String) && session_ref.valid_encoding? &&
          session_ref.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/)
        raise ArgumentError, "email reentry browser reference required"
      end

      surface, transaction_model, notifier = components(email)
      if surface == "org" && operation == "withdrawal"
        raise ArgumentError, "ORG withdrawal reentry is unsupported"
      end

      issued = issue_challenge(email, transaction_model, operation, session_ref)
      return unless issued

      transaction, code = issued
      notifier.issue(
        record: email, otp_code: code, purpose: operation, public_id: email.public_id,
        email_ceremony_transaction_ref: transaction.transaction_id, email_otp_generation: transaction.otp_generation,
      )
      Chronicle.capture(
        action: "notification.delivery.email.enqueued", subject: email,
        metadata: { purpose: operation },
      )
      transaction
    end

    private

    def components(email)
      case email
      when ClientEmail then ["app", ClientEmailCeremonyTransaction, Notify::App::OtpNotifier]
      when VisitorEmail then ["com", VisitorEmailCeremonyTransaction, Notify::Com::OtpNotifier]
      when OperatorEmail then ["org", OperatorEmailCeremonyTransaction, Notify::Org::OtpNotifier]
      else raise ArgumentError, "unsupported reentry email identifier"
      end
    end

    def issue_challenge(email, transaction_model, operation, session_ref)
      email.with_lock do
        now = email.class.database_now
        next nil if email.locked?(now: now) || email.otp_cooldown_active?(now: now)

        transaction = transaction_model.create_transaction!(
          actor_ref: owner_reference(email), session_ref: session_ref, operation: operation,
          email_candidate_ref: email.public_id, normalized_email_digest: email.address_digest,
        )
        code = transaction.issue_email_otp!(purpose: operation)
        email.update!(otp_last_sent_at: now)
        [transaction, code]
      end
    end

    def owner_reference(email)
      case email
      when ClientEmail then email.user.public_id
      when VisitorEmail then email.visitor.public_id
      when OperatorEmail then email.staff.public_id
      else raise ArgumentError, "unsupported reentry email identifier"
      end
    end
  end
end
