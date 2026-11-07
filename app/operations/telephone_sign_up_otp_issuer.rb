# frozen_string_literal: true

class TelephoneSignUpOtpIssuer
  class InitialSubmissionRollback < StandardError
    attr_reader :result

    def initialize(result)
      @result = result
      super("initial Telephone signup OTP issue was refused")
    end
  end

  class << self
    public

    def call(flow:, telephone:, session_nonce:, initial_submission: false, actor_context: nil)
      owner, transaction_model, pending_status = components(flow, telephone)
      if initial_submission && actor_context.nil?
        raise ArgumentError, "initial Telephone signup requires an actor context"
      end

      issue =
        lambda do |registered_destination|
          owner.with_lock do
            telephone.with_lock do
              issued =
                if initial_submission
                  issue_initial_submission(
                    flow:, telephone:, owner:, pending_status:, transaction_model:, session_nonce:, actor_context:,
                    registered_destination:,
                  )
                else
                  flow.with_lock do
                    refusal = current_issuance_refusal(
                      flow:, contact: telephone, owner:, pending_status:, session_nonce:, contact_type: "telephone",
                    )
                    next refusal if refusal

                    issue_locked(flow, telephone, owner, transaction_model, registered_destination:)
                  end
                end
              telephone.update!(otp_last_sent_at: telephone.class.database_now) if issued.success?
              issued
            end
          end
        end

      if telephone.is_a?(ClientTelephone)
        AppRegisteredContactDestinationGuard.with_lock(contact: telephone, owner: owner, &issue)
      else
        issue.call(false)
      end
    rescue InitialSubmissionRollback => e
      e.result
    end

    private

    def issue_initial_submission(flow:, telephone:, owner:, pending_status:, transaction_model:, session_nonce:,
                                 actor_context:, registered_destination:)
      flow.with_cycle_lock do
        refusal = current_issuance_refusal(
          flow:, contact: telephone, owner:, pending_status:, session_nonce:, contact_type: "telephone",
          initial_submission: true,
        )
        expire_initial_flow_if_due(flow, actor_context) if refusal&.status == :inactive_flow
        next refusal if refusal
        next refused(:binding_mismatch) unless initial_flow_unbound?(flow, "telephone")
        next refused(:locked) if telephone.locked?(now: telephone.class.database_now)
        next refused(:rate_limited) if telephone_cooldown_active?(telephone)

        transition = SignUpStateMachine.call(ticket: flow, event: :submit_contact, actor_context: actor_context)
        next refused(:inactive_flow) if transition.status == :expired
        next refused(:binding_mismatch) unless transition.status == :advanced

        flow.update!(principal_id: owner.id, pending_contact_type: "telephone", pending_contact_id: telephone.id)
        issued = issue_locked(flow, telephone, owner, transaction_model, registered_destination:)
        raise InitialSubmissionRollback, issued unless issued.success? || issued.status == :registered_destination

        issued
      end
    end

    def current_issuance_refusal(flow:, contact:, owner:, pending_status:, session_nonce:, contact_type:,
                                 initial_submission: false)
      unless session_nonce.is_a?(String) && session_nonce.valid_encoding? &&
          session_nonce.encoding.ascii_compatible? && session_nonce.present? && flow.nonce_matches?(session_nonce)
        return refused(:session_mismatch)
      end

      now = flow.class.database_now
      return refused(:inactive_flow) if flow.sign_up_terminal? || flow.expires_at <= now || flow.lapsed?(now)

      unless initial_submission ||
          (flow.pending_contact_type == contact_type && flow.pending_contact_id == contact.id &&
            flow.principal_id == owner.id)
        return refused(:binding_mismatch)
      end
      return if owner.status_id == pending_status && owner.active? && owner.access_enabled? &&
        owner.accessible?(owner.class.database_now)

      refused(:inactive_candidate)
    end

    def initial_flow_unbound?(flow, contact_type)
      flow.sign_up_started? && flow.step == "start" && flow.entry_method == contact_type &&
        flow.principal_id.nil? && flow.pending_contact_type.nil? && flow.pending_contact_id.nil?
    end

    def expire_initial_flow_if_due(flow, actor_context)
      return unless flow.sign_up_started? && flow.expires_at <= flow.class.database_now

      SignUpStateMachine.call(ticket: flow, event: :submit_contact, actor_context: actor_context)
    end

    def telephone_cooldown_active?(telephone)
      now = telephone.class.database_now
      sent_at = telephone.otp_last_sent_at
      sent_at && sent_at != -Float::INFINITY && sent_at > now - TelephoneOtpPolicy::SEND_COOLDOWN
    end

    def components(flow, telephone)
      case flow
      when ClientSignUpFlow
        raise ArgumentError, "APP signup requires its own Telephone" unless telephone.is_a?(ClientTelephone)

        [Client.find(telephone.user_id), ClientTelephoneCeremonyTransaction, ClientStatus::UNVERIFIED_WITH_SIGN_UP]
      else raise ArgumentError, "unsupported Telephone signup realm"
      end
    end

    def issue_locked(flow, telephone, owner, transaction_model, registered_destination: false)
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
      return refused(:registered_destination) if registered_destination

      issue_bound_transaction(flow, telephone, owner, transaction_model)
    end

    def current_owner?(telephone, owner)
      current_owner_id =
        case telephone
        when ClientTelephone then telephone.user_id
        else raise ArgumentError, "unsupported Telephone signup candidate"
        end
      current_owner_id == owner.id
    end

    def issue_bound_transaction(flow, telephone, owner, transaction_model)
      session_ref = Digest::SHA256.hexdigest(JSON.generate(["telephone_sign_up", flow.public_id, flow.nonce_digest]))
      binding = {
        operation: "sign_up",
        actor_ref: owner.public_id,
        session_ref: session_ref,
        telephone_candidate_ref: telephone.public_id,
        normalized_number_digest: telephone.number_digest,
      }
      transactions = transaction_model.where(binding.except(:normalized_number_digest))
      existing = transactions.exists?
      transaction =
        existing ? transactions.lock.sole :
               create_transaction_with_generated_reference!(
                 transaction_model: transaction_model, binding: binding, expires_at: flow.expires_at,
               )
      if transaction.otp_consumed_at || transaction.otp_cancelled_at || transaction.consumed_at
        return refused(:closed_challenge)
      end
      unless transaction.normalized_number_digest == telephone.number_digest &&
          transaction.expires_at == flow.expires_at
        return refused(:binding_mismatch)
      end
      if existing && !transaction.telephone_otp_deliverable?(
        generation: transaction.otp_generation, at: transaction_model.database_now,
      )
        return refused(:closed_challenge)
      end

      issue_transaction(transaction)
    end

    def issue_transaction(transaction)
      code = transaction.issue_telephone_otp!(purpose: "sign_up")
      TelephoneSignUpOtpIssueResult.new(status: :issued, transaction: transaction, code: code)
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
      TelephoneSignUpOtpIssueResult.new(status: status, transaction: nil, code: nil)
    end
  end
end
