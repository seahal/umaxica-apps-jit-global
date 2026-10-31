# frozen_string_literal: true

class EmailSignUpOtpIssuer
  class << self
    public

    def call(flow:, email:, session_nonce:)
      owner, transaction_model, pending_status = components(flow, email)
      owner.with_lock do
        email.with_lock do
          issued =
            flow.with_lock do
              unless session_nonce.is_a?(String) && session_nonce.valid_encoding? &&
                  session_nonce.encoding.ascii_compatible? && session_nonce.present? &&
                  flow.nonce_matches?(session_nonce)
                next refused(:session_mismatch)
              end

              now = flow.class.database_now
              if flow.sign_up_terminal? || flow.expires_at <= now || flow.lapsed?(now)
                next refused(:inactive_flow)
              end
              unless flow.pending_contact_type == "email" && flow.pending_contact_id == email.id &&
                  flow.principal_id == owner.id
                next refused(:binding_mismatch)
              end
              unless owner.status_id == pending_status && owner.active? && owner.access_enabled? &&
                  owner.accessible?(owner.class.database_now)
                next refused(:inactive_candidate)
              end

              issue_locked(flow, email, owner, transaction_model)
            end
          email.update!(otp_last_sent_at: email.class.database_now) if issued.success?
          issued
        end
      end

    end

    private

    def components(flow, email)
      case flow
      when ClientSignUpFlow
        raise ArgumentError, "APP signup requires its own Email" unless email.is_a?(ClientEmail)

        [Client.find(email.user_id), ClientEmailCeremonyTransaction, ClientStatus::UNVERIFIED_WITH_SIGN_UP]
      else raise ArgumentError, "unsupported Email signup realm"
      end
    end

    def issue_locked(flow, email, owner, transaction_model)
      now = email.class.database_now
      flow_now = flow.class.database_now
      if flow.sign_up_terminal? || flow.expires_at <= flow_now || flow.lapsed?(flow_now)
        return refused(:inactive_flow)
      end

      current_owner_id =
        case email
        when ClientEmail then email.user_id
        else raise ArgumentError, "unsupported Email signup candidate"
        end
      unless current_owner_id == owner.id && owner.accessible?(owner.class.database_now)
        return refused(:inactive_candidate)
      end

      if email.binding_finalized_at || email.binding_released? || !email.accessible?(now)
        return refused(:inactive_candidate)
      end
      return refused(:locked) if email.locked?(now: now)
      return refused(:rate_limited) if email.otp_cooldown_active?(now: now)

      session_ref = Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", flow.public_id, flow.nonce_digest]))
      binding = {
        operation: "sign_up",
        actor_ref: owner.public_id,
        session_ref: session_ref,
        email_candidate_ref: email.public_id,
        normalized_email_digest: email.address_digest,
      }
      transaction, existing = find_or_create_bound_transaction(transaction_model, binding, flow.expires_at)
      if transaction.otp_consumed_at || transaction.otp_cancelled_at || transaction.consumed_at
        return refused(:closed_challenge)
      end
      return refused(:binding_mismatch) unless bound_to_candidate?(transaction, email, flow)
      return refused(:closed_challenge) if existing && !current_proof?(transaction, transaction_model)

      code = transaction.issue_email_otp!(purpose: "sign_up")
      EmailSignUpOtpIssueResult.new(status: :issued, transaction: transaction, code: code)
    end

    def bound_to_candidate?(transaction, email, flow)
      transaction.normalized_email_digest == email.address_digest && transaction.expires_at == flow.expires_at
    end

    def current_proof?(transaction, transaction_model)
      transaction.email_otp_deliverable?(generation: transaction.otp_generation, at: transaction_model.database_now)
    end

    def find_or_create_bound_transaction(transaction_model, binding, expires_at)
      transactions = transaction_model.where(binding.except(:normalized_email_digest))
      return [transactions.lock.sole, true] if transactions.exists?

      [
        create_transaction_with_generated_reference!(
          transaction_model: transaction_model, binding: binding, expires_at: expires_at,
        ),
        false,
      ]
    end

    def create_transaction_with_generated_reference!(transaction_model:, binding:, expires_at:)
      retries = 0

      loop do
        begin
          transaction_model.transaction(requires_new: true) do
            return transaction_model.create_transaction!(
              **binding, transaction_id: PublicId.generate, grant_jti: PublicId.generate, expires_at: expires_at,
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

    def refused(status)
      EmailSignUpOtpIssueResult.new(status: status, transaction: nil, code: nil)
    end
  end
end
