# frozen_string_literal: true

class TelephoneSignUpOtpVerificationCommitter
  class << self
    public

    def call(flow:, telephone:, session_nonce:, code:)
      owner, transaction_model, pending_status, surface = components(flow, telephone)
      source_failure_state = nil
      admitted_flow = false
      verification =
        flow.with_lock do
          unless session_nonce.is_a?(String) && session_nonce.valid_encoding? &&
              session_nonce.encoding.ascii_compatible? && session_nonce.present? && flow.nonce_matches?(session_nonce)
            next result(:session_mismatch, telephone)
          end
          unless code.is_a?(String) && code.encoding.ascii_compatible? && code.valid_encoding? &&
              code.match?(/\A[0-9]{6}\z/)
            next result(:invalid_code, telephone)
          end

          admitted_flow = true
          owner.with_lock do
            telephone.with_lock do
              now = flow.class.database_now
              if flow.sign_up_terminal? || flow.expires_at <= now || flow.lapsed?(now)
                next result(:inactive_flow, telephone)
              end
              unless eligible_source?(flow, telephone, owner, pending_status)
                next result(:inactive_candidate, telephone)
              end

              source_failure_state = telephone.attributes.slice("otp_attempts_count", "locked_at", "updated_at")
              verify_locked(flow, telephone, owner, transaction_model, surface, pending_status, code)
            end
          end
        end
      unless verification.success?
        terminate_expired_flow(flow) if admitted_flow
        return verification
      end

      reset_fresh_attempts(flow, telephone, owner, transaction_model, pending_status, code, source_failure_state)
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

        [telephone.user, ClientTelephoneCeremonyTransaction, ClientStatus::UNVERIFIED_WITH_SIGN_UP, :app]
      when VisitorSignUpFlow
        raise ArgumentError, "COM signup requires its own Telephone" unless telephone.is_a?(VisitorTelephone)

        [telephone.visitor, VisitorTelephoneCeremonyTransaction, VisitorStatus::ACTIVE, :com]
      else raise ArgumentError, "unsupported Telephone signup realm"
      end
    end

    def eligible_source?(flow, telephone, owner, pending_status)
      owner_id =
        case telephone
        when ClientTelephone then telephone.user_id
        when VisitorTelephone then telephone.visitor_id
        else raise ArgumentError, "unsupported Telephone signup candidate"
        end
      flow.principal_id == owner.id && flow.pending_contact_type == "telephone" &&
        flow.pending_contact_id == telephone.id && owner_id == owner.id &&
        owner.status_id == pending_status && owner.active? && owner.access_enabled? &&
        owner.accessible?(owner.class.database_now) && !telephone.binding_finalized_at &&
        !telephone.binding_released? && telephone.accessible?(telephone.class.database_now)
    end

    def verify_locked(flow, telephone, owner, transaction_model, surface, pending_status, code)
      return result(:locked, telephone) if telephone.locked?(now: telephone.class.database_now)

      session_ref = Digest::SHA256.hexdigest(JSON.generate(["telephone_sign_up", flow.public_id, flow.nonce_digest]))
      transactions = transaction_model.where(
        operation: "sign_up", actor_ref: owner.public_id, session_ref: session_ref,
        telephone_candidate_ref: telephone.public_id, normalized_number_digest: telephone.number_digest,
      )
      return result(:missing_challenge, telephone) unless transactions.exists?

      transaction = transactions.sole
      binding = {
        purpose: "sign_up",
        actor_ref: owner.public_id,
        session_ref: session_ref,
        operation: "sign_up",
        candidate_ref: telephone.public_id,
      }
      if transaction.otp_consumed_at
        return verify_receipt(
          flow, telephone, owner, transaction, surface, pending_status, code, binding,
        )
      end
      admission_status = nil
      verified =
        transaction.verify_telephone_otp!(code: code, **binding) do |valid|
          admission_status = TelephoneOtpVerificationFailureBudget.new.verify!(
            surface: surface, purpose: :sign_up, channel: :telephone,
            destination_digest: telephone.number_digest, valid: valid,
          )
          telephone.increment_attempts! unless valid
          admission_status == :verified && admission_current?(flow, telephone, owner, pending_status)
        end
      unless verified
        return result(:locked, telephone) if admission_status == :locked

        return result(telephone.locked?(now: telephone.class.database_now) ? :locked : :invalid_code, telephone)
      end

      result(:verified, telephone)
    end

    def verify_receipt(flow, telephone, owner, transaction, surface, pending_status, code, binding)
      transaction.with_lock do
        next result(:result_expired, telephone) unless live_receipt?(transaction)

        valid = transaction.telephone_otp_verified_evidence?(code: code, **binding)
        admission = TelephoneOtpVerificationFailureBudget.new.verify!(
          surface: surface, purpose: :sign_up, channel: :telephone,
          destination_digest: telephone.number_digest, valid: valid,
        )
        telephone.increment_attempts! unless valid
        if admission == :locked || telephone.locked?(now: telephone.class.database_now)
          next result(:locked, telephone)
        end
        unless admission_current?(flow, telephone, owner, pending_status) && live_receipt?(transaction)
          next result(:result_expired, telephone)
        end
        next result(:invalid_code, telephone) unless valid
        next result(:locked, telephone) unless admission == :verified
        unless transaction.telephone_otp_verified_evidence?(code: code, **binding)
          next result(:result_expired, telephone)
        end

        result(:already_verified, telephone)
      end
    end

    def live_receipt?(transaction)
      now = transaction.class.database_now
      transaction.purpose == "sign_up" && transaction.status == "pending" && transaction.consumed_at.nil? &&
        transaction.expires_at > now && transaction.otp_cancelled_at.nil? && transaction.otp_consumed_at &&
        transaction.otp_consumed_at <= now && transaction.otp_receipt_verifier.present? &&
        transaction.otp_result_expires_at && transaction.otp_result_expires_at > now
    end

    def admission_current?(flow, telephone, owner, pending_status)
      now = flow.class.database_now
      !flow.sign_up_terminal? && flow.expires_at > now && !flow.lapsed?(now) &&
        eligible_source?(flow, telephone, owner, pending_status)
    end

    def reset_fresh_attempts(flow, telephone, owner, transaction_model, pending_status, code, source_failure_state)
      flow.with_lock do
        owner.with_lock do
          telephone.with_lock do
            now = flow.class.database_now
            if flow.sign_up_terminal? || flow.expires_at <= now || flow.lapsed?(now)
              next result(:inactive_flow, telephone)
            end
            next result(:inactive_candidate, telephone) unless eligible_source?(flow, telephone, owner, pending_status)

            session_ref = Digest::SHA256.hexdigest(
              JSON.generate(["telephone_sign_up", flow.public_id, flow.nonce_digest]),
            )
            transaction = transaction_model.where(
              operation: "sign_up", actor_ref: owner.public_id, session_ref: session_ref,
              telephone_candidate_ref: telephone.public_id, normalized_number_digest: telephone.number_digest,
            ).sole
            unless transaction.telephone_otp_verified_evidence?(
              code: code, purpose: "sign_up", actor_ref: owner.public_id, session_ref: session_ref,
              operation: "sign_up", candidate_ref: telephone.public_id,
            )
              next result(:result_expired, telephone)
            end

            if telephone.attributes.slice(*source_failure_state.keys) == source_failure_state
              telephone.update!(otp_attempts_count: 0, locked_at: TelephoneOtpPolicy::OTP_UNLOCKED_SENTINEL)
            end
            result(:verified, telephone)
          end
        end
      end
    end

    def result(status, telephone)
      TelephoneSignUpOtpVerificationResult.new(status: status, telephone: telephone)
    end
  end
end
