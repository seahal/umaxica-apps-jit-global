# frozen_string_literal: true

class EmailSignUpOtpFormQuery
  class << self
    public

    def call(flow:, email:, session_nonce:)
      return false unless flow && email && session_nonce.is_a?(String) && session_nonce.encoding.ascii_compatible? &&
        session_nonce.valid_encoding? && session_nonce.present?

      owner, transaction_model, pending_status = components(flow, email)
      return false unless flow.nonce_matches?(session_nonce)
      return false unless eligible_parent_and_source?(flow, email, owner, pending_status)

      session_ref = Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", flow.public_id, flow.nonce_digest]))
      transactions = transaction_model.where(
        operation: "sign_up", purpose: "sign_up", actor_ref: owner.public_id, session_ref: session_ref,
        email_candidate_ref: email.public_id, normalized_email_digest: email.address_digest,
      )
      return false unless transactions.exists?

      available_form?(transactions.sole, transaction_model.database_now)
    end

    private

    def components(flow, email)
      case flow
      when ClientSignUpFlow
        raise ArgumentError, "APP signup requires its own Email" unless email.is_a?(ClientEmail)

        [email.user, ClientEmailCeremonyTransaction, ClientStatus::UNVERIFIED_WITH_SIGN_UP]
      when VisitorSignUpFlow
        raise ArgumentError, "COM signup requires its own Email" unless email.is_a?(VisitorEmail)

        [email.visitor, VisitorEmailCeremonyTransaction, VisitorStatus::ACTIVE]
      else raise ArgumentError, "unsupported Email signup realm"
      end
    end

    def eligible_parent_and_source?(flow, email, owner, pending_status)
      now = flow.class.database_now
      owner_id =
        case email
        when ClientEmail then email.user_id
        when VisitorEmail then email.visitor_id
        else raise ArgumentError, "unsupported Email signup candidate"
        end
      !flow.sign_up_terminal? && flow.expires_at > now && !flow.lapsed?(now) &&
        flow.principal_id == owner.id && flow.pending_contact_type == "email" &&
        flow.pending_contact_id == email.id && owner_id == owner.id &&
        owner.status_id == pending_status && owner.active? && owner.access_enabled? &&
        owner.accessible?(owner.class.database_now) && email.accessible?(email.class.database_now) &&
        !email.binding_finalized_at && !email.binding_released?
    end

    def available_form?(transaction, at)
      return true if transaction.email_otp_deliverable?(generation: transaction.otp_generation, at: at)

      transaction.status == "pending" && transaction.consumed_at.nil? && transaction.expires_at > at &&
        transaction.otp_cancelled_at.nil? && transaction.otp_consumed_at && transaction.otp_consumed_at <= at &&
        transaction.otp_receipt_verifier.present? && transaction.otp_result_expires_at &&
        transaction.otp_result_expires_at > at
    end
  end
end
