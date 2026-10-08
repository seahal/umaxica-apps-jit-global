# frozen_string_literal: true

class TelephoneSignUpOtpIssuer
  class << self
    public

    def call(flow:, telephone:, session_nonce:)
      owner, transaction_model, pending_status = components(flow, telephone)
      outcome =
        flow.with_lock do
          unless session_nonce.is_a?(String) && session_nonce.valid_encoding? &&
              session_nonce.encoding.ascii_compatible? && session_nonce.present? && flow.nonce_matches?(session_nonce)
            next refused(:session_mismatch)
          end

          now = flow.class.database_now
          if flow.sign_up_terminal? || flow.expires_at <= now || flow.lapsed?(now)
            next refused(:inactive_flow)
          end
          unless flow.pending_contact_type == "telephone" && flow.pending_contact_id == telephone.id &&
              flow.principal_id == owner.id
            next refused(:binding_mismatch)
          end

          owner.with_lock do
            unless owner.status_id == pending_status && owner.active? && owner.access_enabled? &&
                owner.accessible?(owner.class.database_now)
              next refused(:inactive_candidate)
            end

            telephone.with_lock { issue_locked(flow, telephone, owner, transaction_model) }
          end
        end
      terminate_expired_flow(flow) if outcome.status == :inactive_flow
      outcome
    end

    private

    def terminate_expired_flow(flow)
      return if flow.sign_up_terminal? || flow.expires_at > flow.class.database_now

      SignUpTermination.call(cycle: flow, event: :expire)
    end

    def components(flow, telephone)
      case flow
      when ClientSignUpFlow
        raise ArgumentError, "APP signup requires its own Telephone" unless telephone.is_a?(ClientTelephone)

        [telephone.user, ClientTelephoneCeremonyTransaction, ClientStatus::UNVERIFIED_WITH_SIGN_UP]
      when VisitorSignUpFlow
        raise ArgumentError, "COM signup requires its own Telephone" unless telephone.is_a?(VisitorTelephone)

        [telephone.visitor, VisitorTelephoneCeremonyTransaction, VisitorStatus::ACTIVE]
      else raise ArgumentError, "unsupported Telephone signup realm"
      end
    end

    def issue_locked(flow, telephone, owner, transaction_model)
      now = telephone.class.database_now
      flow_now = flow.class.database_now
      if flow.sign_up_terminal? || flow.expires_at <= flow_now || flow.lapsed?(flow_now)
        return refused(:inactive_flow)
      end

      unless current_owner?(telephone, owner) && owner.accessible?(owner.class.database_now)
        return refused(:inactive_candidate)
      end

      if telephone.binding_finalized_at || telephone.binding_released? || !telephone.accessible?(now)
        return refused(:inactive_candidate)
      end
      return refused(:locked) if telephone.locked?(now: now)

      sent_at = telephone.otp_last_sent_at
      if sent_at && sent_at != -Float::INFINITY && sent_at > now - TelephoneOtpPolicy::SEND_COOLDOWN
        return refused(:rate_limited)
      end

      issue_bound_transaction(flow, telephone, owner, transaction_model, now)
    end

    def current_owner?(telephone, owner)
      current_owner_id =
        case telephone
        when ClientTelephone then telephone.user_id
        when VisitorTelephone then telephone.visitor_id
        else raise ArgumentError, "unsupported Telephone signup candidate"
        end
      current_owner_id == owner.id
    end

    def issue_bound_transaction(flow, telephone, owner, transaction_model, now)
      session_ref = Digest::SHA256.hexdigest(JSON.generate(["telephone_sign_up", flow.public_id, flow.nonce_digest]))
      binding = {
        operation: "sign_up",
        actor_ref: owner.public_id,
        session_ref: session_ref,
        telephone_candidate_ref: telephone.public_id,
        normalized_number_digest: telephone.number_digest,
      }
      transactions = transaction_model.where(binding.except(:normalized_number_digest))
      transaction =
        transactions.exists? ? transactions.sole :
               transaction_model.create_transaction!(**binding, expires_at: flow.expires_at)
      if transaction.otp_consumed_at || transaction.otp_cancelled_at || transaction.consumed_at
        return refused(:closed_challenge)
      end
      unless transaction.normalized_number_digest == telephone.number_digest &&
          transaction.expires_at == flow.expires_at
        return refused(:binding_mismatch)
      end

      issue_transaction(transaction, telephone, now)
    end

    def issue_transaction(transaction, telephone, now)
      code = transaction.issue_telephone_otp!(purpose: "sign_up")
      telephone.update!(otp_last_sent_at: now)
      TelephoneSignUpOtpIssueResult.new(status: :issued, transaction: transaction, code: code)
    end

    def refused(status)
      TelephoneSignUpOtpIssueResult.new(status: status, transaction: nil, code: nil)
    end
  end
end
