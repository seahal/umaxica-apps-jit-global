# frozen_string_literal: true

class TelephoneSignUpOtpFormQuery
  class << self
    public

    def call(flow:, telephone:, session_nonce:)
      return false unless telephone && flow && session_nonce.is_a?(String) && session_nonce.valid_encoding? &&
        session_nonce.encoding.ascii_compatible? && session_nonce.present? && flow.nonce_matches?(session_nonce)

      owner, transaction_model, telephone_status = components(flow, telephone)
      return false unless current_source?(flow, telephone, owner, telephone_status)

      session_ref = Digest::SHA256.hexdigest(JSON.generate(["telephone_sign_up", flow.public_id, flow.nonce_digest]))
      transactions = transaction_model.where(
        operation: "sign_up", purpose: "sign_up", actor_ref: owner.public_id, session_ref: session_ref,
        telephone_candidate_ref: telephone.public_id, normalized_number_digest: telephone.number_digest,
      )
      return false unless transactions.exists?

      live_transaction?(transactions.sole, transaction_model.database_now)
    end

    private

    def components(flow, telephone)
      case flow
      when ClientSignUpFlow
        raise ArgumentError, "APP signup requires its own Telephone" unless telephone.is_a?(ClientTelephone)

        [telephone.user, ClientTelephoneCeremonyTransaction, telephone.user_telephone_status_id]
      when VisitorSignUpFlow
        raise ArgumentError, "COM signup requires its own Telephone" unless telephone.is_a?(VisitorTelephone)

        [telephone.visitor, VisitorTelephoneCeremonyTransaction, telephone.visitor_telephone_status_id]
      else raise ArgumentError, "unsupported Telephone signup realm"
      end
    end

    def current_source?(flow, telephone, owner, telephone_status)
      expected_status =
        case telephone
        when ClientTelephone then ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP
        when VisitorTelephone then VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP
        else raise ArgumentError, "unsupported Telephone signup candidate"
        end
      now = flow.class.database_now
      return false if flow.sign_up_terminal? || flow.expires_at <= now || flow.lapsed?(now)

      flow.principal_id == owner.id && flow.pending_contact_type == "telephone" &&
        flow.pending_contact_id == telephone.id && telephone_status == expected_status &&
        !telephone.binding_finalized_at && !telephone.binding_released? &&
        telephone.accessible?(telephone.class.database_now)
    end

    def live_transaction?(transaction, at)
      return true if transaction.telephone_otp_deliverable?(generation: transaction.otp_generation, at: at)

      transaction.status == "pending" && transaction.consumed_at.nil? && transaction.expires_at > at &&
        transaction.otp_cancelled_at.nil? && transaction.otp_consumed_at &&
        transaction.otp_receipt_verifier.present? && transaction.otp_result_expires_at &&
        transaction.otp_result_expires_at > at
    end
  end
end
