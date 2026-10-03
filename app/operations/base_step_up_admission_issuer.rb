# frozen_string_literal: true

# Base retains the concrete transaction and browser-session binding. Auth receives only a
# purpose-scoped opaque admission to the existing actor-specific ticket transaction.
class BaseStepUpAdmissionIssuer
  Binding = Data.define(:surface, :transaction_model, :session_model, :token_foreign_key, :methods, :scope_catalog)

  class << self
    public

    def call!(actor:, token:, requirement:, return_to:)
      binding = binding_for(actor, token)
      validate_requirement!(requirement, token: token, return_to: return_to, binding: binding)
      actor.class.connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          binding.transaction_model.connection_owner.connected_to(role: :writing) do
            token.with_lock do
              now = binding.transaction_model.database_now
              raise BaseAuthAdmissionCoordinator::Denied, "Base session is unavailable" unless token.currently_usable?
              if token.is_a?(OperatorToken) && token.emergency_authentication_context?
                raise BaseAuthAdmissionCoordinator::Denied, "Emergency session cannot initiate step-up"
              end

              methods = requirement.allowed_methods.map(&:to_s) & binding.methods
              raise BaseAuthAdmissionCoordinator::Denied, "step-up method unavailable" if methods.empty?

              pending = binding.session_model.lock.find_by(binding.token_foreign_key => token.id)
              transaction = existing_transaction(
                pending, binding: binding, requirement: requirement,
                         token: token, actor: actor, return_to: return_to, now: now,
              )
              transaction ||= create_transaction!(
                binding: binding, token: token, actor: actor,
                requirement: requirement, methods: methods,
                return_to: return_to, now: now,
              )
              persist_session!(pending: pending, transaction: transaction, binding: binding, token: token)
              BaseAuthAdmissionCoordinator.issue_handoff!(transaction: transaction, reference: SecureRandom.uuid)
            end
          end
        end
      end
    end

    private

    def validate_requirement!(requirement, token:, return_to:, binding:)
      unless requirement.is_a?(StepUpRequirement) && requirement.step_up_required? &&
          requirement.purpose == "step_up" && requirement.audience == "step_up:#{binding.surface}" &&
          requirement.session_binding == token.public_id && requirement.token_binding == token.public_id &&
          requirement.require_session_binding && requirement.ttl.positive? &&
          return_to.is_a?(String) && binding.scope_catalog.fetch(requirement.scope).match?(return_to)
        raise BaseAuthAdmissionCoordinator::Denied, "step-up requirement binding missing"
      end
    rescue KeyError
      raise BaseAuthAdmissionCoordinator::Denied, "step-up scope is unavailable"
    end

    def binding_for(actor, token)
      case token
      when ClientToken
        unless actor.is_a?(Client) && token.user_id == actor.id
          raise BaseAuthAdmissionCoordinator::Denied, "Base actor mismatch"
        end

        Binding.new(
          surface: "app", transaction_model: ClientStepUpCeremonyTransaction,
          session_model: ClientStepUpSession, token_foreign_key: :user_token_id,
          methods: %w(passkey totp email_otp), scope_catalog: StepUpScopeCatalog::APP,
        )
      when VisitorToken
        unless actor.is_a?(Visitor) && token.visitor_id == actor.id
          raise BaseAuthAdmissionCoordinator::Denied, "Base actor mismatch"
        end

        Binding.new(
          surface: "com", transaction_model: VisitorStepUpCeremonyTransaction,
          session_model: VisitorStepUpSession, token_foreign_key: :visitor_token_id,
          methods: %w(passkey email_otp), scope_catalog: StepUpScopeCatalog::COM,
        )
      when OperatorToken
        unless actor.is_a?(Operator) && token.staff_id == actor.id
          raise BaseAuthAdmissionCoordinator::Denied, "Base actor mismatch"
        end

        Binding.new(
          surface: "org", transaction_model: OperatorStepUpCeremonyTransaction,
          session_model: OperatorStepUpSession, token_foreign_key: :staff_token_id, methods: %w(passkey),
          scope_catalog: StepUpScopeCatalog::ORG,
        )
      else
        raise BaseAuthAdmissionCoordinator::Denied, "Base session type mismatch"
      end
    end

    def existing_transaction(pending, binding:, requirement:, token:, actor:, return_to:, now:)
      return unless pending&.step_up_ceremony_transaction_ref

      transaction = binding.transaction_model.lock.find_by!(transaction_id: pending.step_up_ceremony_transaction_ref)
      return unless %w(pending verified).include?(transaction.status) && !transaction.expired?(now: now)

      unless transaction.actor_ref == actor.public_id && transaction.session_ref == token.public_id &&
          transaction.required_scope == requirement.scope && transaction.required_aal ==
              (requirement.required_aal&.to_s || StepUpRequirement::NO_AAL) &&
          transaction.phishing_resistant_required == requirement.phishing_resistant_required? &&
          transaction.return_to == return_to && transaction.purpose == "step_up"
        raise BaseAuthAdmissionCoordinator::Denied, "another step-up transaction is pending"
      end

      transaction
    end

    def create_transaction!(binding:, token:, actor:, requirement:, methods:, return_to:, now:)
      binding.transaction_model.create_transaction!(
        surface: binding.surface, actor_ref: actor.public_id, session_ref: token.public_id,
        required_scope: requirement.scope, required_aal: requirement.required_aal&.to_s || StepUpRequirement::NO_AAL,
        phishing_resistant_required: requirement.phishing_resistant_required?,
        allowed_methods: methods, return_to: return_to, now: now,
        expires_at: now + requirement.ttl, purpose: "step_up",
      )
    end

    def persist_session!(pending:, transaction:, binding:, token:)
      return if pending&.step_up_ceremony_transaction_ref == transaction.transaction_id

      pending ||= binding.session_model.new(binding.token_foreign_key => token.id)
      pending.assign_attributes(
        step_up_ceremony_transaction_ref: transaction.transaction_id, scope: transaction.required_scope,
        return_to: transaction.return_to, status: "PENDING", method: nil, verified_at: nil,
        discard_at: transaction.expires_at, purge_eligible_at: transaction.expires_at,
        passkey_challenge: nil, passkey_challenge_ref: nil, passkey_rp_id: nil, passkey_origin: nil,
        passkey_challenge_expires_at: nil, passkey_challenge_consumed_at: nil,
      )
      if pending.is_a?(ClientStepUpSession) || pending.is_a?(VisitorStepUpSession)
        pending.assign_attributes(
          email_credential_ref: nil, email_code_digest: nil, email_code_generation: 0,
          email_code_issued_at: nil, email_code_expires_at: nil, email_code_consumed_at: nil,
          email_delivery_state: nil,
        )
      end
      pending.save!
    end
  end
end
