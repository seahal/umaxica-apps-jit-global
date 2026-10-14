# frozen_string_literal: true

class EmailSignUpOtpVerificationCommitter
  class << self
    public

    def call(flow:, email:, session_nonce:, code:)
      owner, transaction_model, pending_status, surface = components(flow, email)
      reset_snapshot = nil
      admitted_flow = false
      verification =
        flow.with_lock do
          unless session_nonce.is_a?(String) && session_nonce.valid_encoding? &&
              session_nonce.encoding.ascii_compatible? && session_nonce.present? && flow.nonce_matches?(session_nonce)
            next result(:session_mismatch, email)
          end
          unless code.is_a?(String) && code.encoding.ascii_compatible? && code.valid_encoding? &&
              code.match?(/\A[0-9]{6}\z/)
            next result(:invalid_code, email)
          end

          admitted_flow = true
          owner.with_lock do
            email.with_lock do
              now = flow.class.database_now
              if flow.sign_up_terminal? || flow.expires_at <= now || flow.lapsed?(now)
                next result(:inactive_flow, email)
              end
              unless eligible_source?(flow, email, owner, pending_status)
                next result(:inactive_candidate, email)
              end

              outcome = verify_locked(flow, email, owner, transaction_model, surface, pending_status, code)
              reset_snapshot = email.attributes.slice(
                "otp_attempts_count", "locked_at",
                "updated_at",
              ) if outcome.success?
              outcome
            end
          end
        end
      unless verification.success?
        terminate_expired_flow(flow) if admitted_flow
        return verification
      end

      reset_consumed_attempts(flow, email, owner, transaction_model, pending_status, code, reset_snapshot)
    end

    private

    def terminate_expired_flow(flow)
      return if flow.sign_up_terminal? || flow.expires_at > flow.class.database_now

      SignUpTermination.call(cycle: flow, event: :expire)
    end

    def components(flow, email)
      case flow
      when ClientSignUpFlow
        raise ArgumentError, "APP signup requires its own Email" unless email.is_a?(ClientEmail)

        [Client.find(email.user_id), ClientEmailCeremonyTransaction, ClientStatus::UNVERIFIED_WITH_SIGN_UP, :app]
      when VisitorSignUpFlow
        raise ArgumentError, "COM signup requires its own Email" unless email.is_a?(VisitorEmail)

        [Visitor.find(email.visitor_id), VisitorEmailCeremonyTransaction, VisitorStatus::ACTIVE, :com]
      else raise ArgumentError, "unsupported Email signup realm"
      end
    end

    def eligible_source?(flow, email, owner, pending_status)
      owner_id =
        case email
        when ClientEmail then email.user_id
        when VisitorEmail then email.visitor_id
        else raise ArgumentError, "unsupported Email signup candidate"
        end
      flow.principal_id == owner.id && flow.pending_contact_type == "email" &&
        flow.pending_contact_id == email.id && owner_id == owner.id &&
        owner.status_id == pending_status && owner.active? && owner.access_enabled? &&
        owner.accessible?(owner.class.database_now) && !email.binding_finalized_at &&
        !email.binding_released? && email.accessible?(email.class.database_now)
    end

    def verify_locked(flow, email, owner, transaction_model, surface, pending_status, code)
      return result(:locked, email) if email.locked?(now: email.class.database_now)

      session_ref = Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", flow.public_id, flow.nonce_digest]))
      transactions = transaction_model.where(
        operation: "sign_up", actor_ref: owner.public_id, session_ref: session_ref,
        email_candidate_ref: email.public_id, normalized_email_digest: email.address_digest,
      )
      return result(:missing_challenge, email) unless transactions.exists?

      transaction = transactions.sole
      binding = {
        purpose: "sign_up",
        actor_ref: owner.public_id,
        session_ref: session_ref,
        operation: "sign_up",
        candidate_ref: email.public_id,
      }
      if transaction.otp_consumed_at
        return verify_receipt_locked(transaction, flow, email, owner, surface, pending_status, code, binding)
      end

      admission_status = nil
      verified =
        transaction.verify_email_otp!(code: code, **binding) do |valid|
          admission_status = EmailOtpVerificationFailureBudget.new.verify!(
            surface: surface, purpose: :sign_up, channel: :email,
            destination_digest: email.address_digest, valid: valid,
          )
          email.increment_attempts! unless valid
          admission_status == :verified && admission_current?(flow, email, owner, pending_status)
        end
      unless verified
        return result(:locked, email) if admission_status == :locked

        return result(email.locked?(now: email.class.database_now) ? :locked : :invalid_code, email)
      end

      result(:verified, email)
    end

    def verify_receipt_locked(transaction, flow, email, owner, surface, pending_status, code, binding)
      transaction.with_lock do
        now = transaction.class.database_now
        unless transaction.status == "pending" && transaction.consumed_at.nil? && transaction.expires_at > now &&
            transaction.purpose == "sign_up" && transaction.otp_cancelled_at.nil? &&
            transaction.otp_result_expires_at && transaction.otp_result_expires_at > now
          next result(:result_expired, email)
        end

        valid = transaction.email_otp_verified_evidence?(code: code, **binding)
        admission = EmailOtpVerificationFailureBudget.new.verify!(
          surface: surface, purpose: :sign_up, channel: :email,
          destination_digest: email.address_digest, valid: valid,
        )
        email.increment_attempts! unless valid
        next result(:locked, email) if admission == :locked || email.locked?(now: email.class.database_now)
        next result(:invalid_code, email) unless valid
        next result(:result_expired, email) unless admission_current?(flow, email, owner, pending_status)
        next result(:result_expired, email) unless transaction.email_otp_verified_evidence?(code: code, **binding)

        result(:already_verified, email)
      end
    end

    def admission_current?(flow, email, owner, pending_status)
      now = flow.class.database_now
      !flow.sign_up_terminal? && flow.expires_at > now && !flow.lapsed?(now) &&
        eligible_source?(flow, email, owner, pending_status)
    end

    def reset_consumed_attempts(flow, email, owner, transaction_model, pending_status, code, snapshot)
      flow.with_lock do
        owner.with_lock do
          email.with_lock do
            next result(:inactive_candidate, email) unless admission_current?(flow, email, owner, pending_status)

            session_ref = Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", flow.public_id, flow.nonce_digest]))
            transaction = transaction_model.where(
              operation: "sign_up", actor_ref: owner.public_id, session_ref: session_ref,
              email_candidate_ref: email.public_id, normalized_email_digest: email.address_digest,
            ).sole
            unless transaction.email_otp_verified_evidence?(
              code: code, purpose: "sign_up", actor_ref: owner.public_id, session_ref: session_ref,
              operation: "sign_up", candidate_ref: email.public_id,
            )
              next result(:result_expired, email)
            end

            if email.attributes.slice(*snapshot.keys) == snapshot
              email.update!(otp_attempts_count: 0, locked_at: EmailOtpPolicy::OTP_UNLOCKED_SENTINEL)
            end
            result(:verified, email)
          end
        end
      end
    end

    def result(status, email)
      EmailSignUpOtpVerificationResult.new(status: status, email: email)
    end
  end
end
