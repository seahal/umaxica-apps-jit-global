# frozen_string_literal: true

class EmailCredentialRegistrationOtpFormQuery
  class << self
    public

    def call(actor:, token:, email:, transaction:, browser_nonce:)
      return false unless actor && token && email && transaction && browser_nonce.is_a?(String) &&
        browser_nonce.encoding.ascii_compatible? && browser_nonce.valid_encoding? &&
        browser_nonce.match?(/\A[A-Za-z0-9_-]{43}\z/)

      surface, owned, parent_model = components(actor, token, email, transaction)
      now = transaction.class.database_now
      device_session = token_device_session(token)
      return false unless owned && device_session && source_current?(actor, token, email, device_session, now)

      expected = CredentialRegistrationOtpSessionValue.for(
        surface: surface, channel: :email, transaction_ref: transaction.transaction_id,
        root_ref: token.public_id, browser_nonce: browser_nonce,
      ).dump
      return false unless bound_transaction?(transaction, actor, email, surface, expected, now) &&
        original_parent_available?(transaction, actor, token, parent_model, now)

      available_evidence?(transaction, now)
    end

    private

    def components(actor, token, email, transaction)
      case [actor, token, email, transaction]
      in [Client, ClientToken, ClientEmail, ClientEmailCeremonyTransaction]
        ["app", token.user_id == actor.id && email.user_id == actor.id, ClientStepUpCeremonyTransaction]
      in [Visitor, VisitorToken, VisitorEmail, VisitorEmailCeremonyTransaction]
        ["com", token.visitor_id == actor.id && email.visitor_id == actor.id, VisitorStepUpCeremonyTransaction]
      in [Operator, OperatorToken, OperatorEmail, OperatorEmailCeremonyTransaction]
        ["org", token.staff_id == actor.id && email.staff_id == actor.id, OperatorStepUpCeremonyTransaction]
      else raise ArgumentError, "unsupported Email registration form realm"
      end
    end

    def source_current?(actor, token, email, device_session, now)
      actor.login_allowed? && actor.accessible?(actor.class.database_now) &&
        source_available?(email) &&
        token.currently_usable?(now) && device_session.usable? &&
        device_session.current_refresh_token_id == token.id
    end

    def token_device_session(token)
      token.device_session_record
    end

    def source_available?(email)
      case email
      when ClientEmail, VisitorEmail then email.accessible?(email.class.database_now) && !email.binding_released?
      when OperatorEmail
        [OperatorEmailStatus::UNVERIFIED, OperatorEmailStatus::VERIFIED].include?(email.staff_email_status_id)
      else raise ArgumentError, "unsupported Email registration candidate"
      end
    end

    def bound_transaction?(transaction, actor, email, surface, expected, now)
      transaction.surface == surface && transaction.actor_ref == actor.public_id &&
        transaction.session_ref == expected && transaction.operation == "registration" &&
        transaction.purpose == "credential_registration" && transaction.email_candidate_ref == email.public_id &&
        transaction.normalized_email_digest == email.address_digest &&
        transaction.status == "pending" && !transaction.consumed_at && transaction.expires_at > now &&
        !transaction.otp_cancelled_at
    end

    def original_parent_available?(transaction, actor, token, parent_model, now)
      reference = transaction.bootstrap_ceremony_transaction_ref
      return true unless reference
      return false if transaction.is_a?(OperatorEmailCeremonyTransaction)

      parent = parent_model.find_by(transaction_id: reference)
      parent && parent.status == "pending" && parent.expires_at > now &&
        parent.actor_ref == actor.public_id && parent.session_ref == token.public_id && parent.purpose == "bootstrap"
    end

    def available_evidence?(transaction, now)
      return true if transaction.email_otp_deliverable?(generation: transaction.otp_generation, at: now)

      return false unless transaction.otp_consumed_at && transaction.otp_consumed_at <= now &&
        transaction.otp_receipt_verifier.present? &&
        transaction.otp_result_expires_at && transaction.otp_result_expires_at > now

      true
    end
  end
end
