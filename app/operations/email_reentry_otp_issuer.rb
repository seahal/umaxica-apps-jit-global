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

        transaction = create_transaction_with_generated_references!(
          transaction_model: transaction_model, actor_ref: owner_reference(email), session_ref: session_ref,
          operation: operation, email_candidate_ref: email.public_id,
          normalized_email_digest: email.address_digest,
        )
        code = transaction.issue_email_otp!(purpose: operation)
        email.update!(otp_last_sent_at: now)
        [transaction, code]
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

    def create_transaction_with_generated_references!(transaction_model:, actor_ref:, session_ref:, operation:,
                                                      email_candidate_ref:, normalized_email_digest:)
      retries = 0

      loop do
        begin
          return transaction_model.transaction(requires_new: true) do
            transaction_model.create_transaction!(
              transaction_id: PublicId.generate, grant_jti: PublicId.generate,
              actor_ref: actor_ref, session_ref: session_ref, operation: operation,
              email_candidate_ref: email_candidate_ref, normalized_email_digest: normalized_email_digest,
            )
          end
        rescue ActiveRecord::RecordInvalid => e
          raise unless generated_reference_collision_validation?(e)
        rescue ActiveRecord::RecordNotUnique => e
          raise unless generated_reference_collision?(transaction_model, e)
        end

        retries += 1
        raise if retries > PublicId::MAX_COLLISION_RETRIES
      end
    end

    def generated_reference_collision_validation?(error)
      %i(transaction_id grant_jti).any? { |attribute| error.record.errors.of_kind?(attribute, :taken) }
    end

    def generated_reference_collision?(transaction_model, error)
      result = error.cause&.result
      return false unless result

      constraint = result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
      transaction_model.lease_connection.schema_cache.indexes(transaction_model.table_name).any? do |index|
        index.name == constraint && index.unique && index.where.nil? &&
          index.columns.one? && %w(transaction_id grant_jti).include?(index.columns.first)
      end
    end
  end
end
