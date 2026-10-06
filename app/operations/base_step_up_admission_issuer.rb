# frozen_string_literal: true

# Base retains the concrete transaction and browser-session binding. Auth receives only a
# purpose-scoped opaque admission to the existing actor-specific ticket transaction.
class BaseStepUpAdmissionIssuer
  Binding = Data.define(:surface, :transaction_model, :session_model, :token_foreign_key, :methods, :scope_catalog)

  class << self
    public

    def call!(actor:, token:, requirement:, return_to:, base_browser_nonce:, base_token:, restart_of: nil)
      unless base_token.equal?(token)
        deny!("Base token binding is invalid", "session_binding_mismatch")
      end

      binding = binding_for(actor, token)
      validate_requirement!(requirement, actor: actor, token: token, return_to: return_to, binding: binding)
      actor.class.connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          deny!("Base actor is unavailable", "authorization_denied") unless actor.login_allowed?

          ensure_bootstrap_eligible!(actor) if requirement.purpose == "bootstrap"

          binding.transaction_model.connection_owner.connected_to(role: :writing) do
            token.with_lock do
              now = binding.transaction_model.database_now
              unless token.currently_usable?(now)
                deny!("Base session is unavailable", "session_expired")
              end
              ensure_bootstrap_session!(token, now) if requirement.purpose == "bootstrap"
              if token.is_a?(OperatorToken) && token.emergency_authentication_context?
                deny!("Emergency session cannot initiate step-up", "authorization_denied")
              end

              if requirement.purpose == "credential_registration"
                ensure_registration_authorized!(requirement, actor: actor, token: token, binding: binding, now: now)
              end

              methods = requirement.allowed_methods.map(&:to_s) & binding.methods
              deny!("step-up method unavailable", "unsupported_method") if methods.empty?

              pending = binding.session_model.lock.find_by(binding.token_foreign_key => token.id)
              transaction = existing_transaction(
                pending, binding: binding, requirement: requirement,
                         token: token, actor: actor, return_to: return_to,
                         base_browser_nonce:, base_token:, restart_of:,
              )
              return transaction if transaction.is_a?(BaseAuthAdmissionCoordinator::Issuance)

              transaction ||= create_transaction!(
                binding: binding, token: token, actor: actor,
                requirement: requirement, methods: methods,
                return_to: return_to, now: binding.transaction_model.database_now,
              )
              persist_session!(pending: pending, transaction: transaction, binding: binding, token: token)
              BaseAuthAdmissionCoordinator.issue_handoff!(
                transaction: transaction, base_browser_nonce: base_browser_nonce, base_token: base_token,
                restart_of:,
              )
            end
          end
        end
      end
    end

    private

    def deny!(message, code, context: {})
      raise BaseAuthAdmissionCoordinator::Denied.new(message, code: code, context: context)
    end

    def validate_requirement!(requirement, actor:, token:, return_to:, binding:)
      unless requirement.is_a?(StepUpRequirement) && supported_requirement_purpose?(requirement, binding) &&
          requirement.audience == "step_up:#{binding.surface}" &&
          requirement.session_binding == token.public_id && requirement.token_binding == token.public_id &&
          requirement.require_session_binding && requirement.actor_ref == actor.public_id &&
          requirement.ttl.positive? &&
          return_to.is_a?(String) && binding.scope_catalog.fetch(requirement.scope).match?(return_to)
        deny!("step-up requirement binding missing", "malformed_request")
      end
    rescue KeyError
      deny!("step-up scope is unavailable", "malformed_request")
    end

    def supported_requirement_purpose?(requirement, binding)
      return requirement.step_up_required? if %w(step_up reauthentication).include?(requirement.purpose)

      if requirement.purpose == "credential_registration"
        method =
          case requirement.scope
          when "settings_passkey" then :passkey
          when "settings_totp" then :totp if binding.surface == "app"
          end
        return method.present? && requirement.allowed_methods == [method] &&
            !requirement.step_up_required? &&
            !requirement.phishing_resistant_required? && !requirement.user_verification_required? &&
            !requirement.full_reauthentication_required?
      end
      return false unless requirement.purpose == "bootstrap" && !requirement.step_up_required? &&
        !requirement.phishing_resistant_required? &&
        !requirement.user_verification_required? && !requirement.full_reauthentication_required?

      # Signed-in app Secret management always requires an existing Step-Up proof.
      return false if binding.surface == "app" && requirement.scope == "settings_secret_credential"

      # Email is confirmed inside Base; Passkey and TOTP are verified by an Auth ceremony.
      registration_methods = binding.methods & %w(passkey totp email_otp)
      requirement.allowed_methods.present? &&
        (requirement.allowed_methods.map(&:to_s) - registration_methods).empty?
    end

    def ensure_registration_authorized!(requirement, actor:, token:, binding:, now:)
      authorization = StepUpRequirement.new(
        scope: requirement.scope, step_up_required: true, allowed_methods: binding.methods,
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, purpose: "step_up",
        audience: requirement.audience, session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true, ttl: StepUpRequirement::DEFAULT_TTL, actor_ref: actor.public_id,
        resource_ref: requirement.resource_ref, tenant_ref: requirement.tenant_ref,
      )
      return if StepUpResolver.call(token: token, requirement: authorization, now: now).satisfied?

      deny!("credential registration requires Base step-up", "authorization_denied")
    end

    def ensure_bootstrap_session!(token, now)
      ensure_bootstrap_fresh!(token, now)
      return unless token.is_a?(ClientToken) && token.established_authentication_method == "secret"

      deny!("Secret session cannot bootstrap a credential", "authorization_denied")
    end

    # A first authenticator may be registered only shortly after primary authentication, so that a
    # stale or stolen session cannot enroll one. Refresh does not move the anchor.
    def ensure_bootstrap_fresh!(token, now)
      established_at = token.root_login_established_at
      fresh_until = established_at && (established_at + SecurityTokenLifetimes::BOOTSTRAP_PRIMARY_AUTHENTICATION_FRESHNESS)
      return if fresh_until && now < fresh_until

      deny!("bootstrap requires fresh primary authentication", "bootstrap_not_fresh")
    end

    # Credential history distinguishes first registration from recovery after loss or revocation.
    # These writer queries run only when Base starts a bootstrap ceremony, never on ordinary access.
    def ensure_bootstrap_eligible!(actor)
      return if StepUpBootstrapEligibilityQuery.call(actor: actor)

      deny!("bootstrap requires an unregistered actor", "authorization_denied")
    end

    def binding_for(actor, token)
      case token
      when ClientToken
        unless actor.is_a?(Client) && token.user_id == actor.id
          deny!("Base actor mismatch", "session_binding_mismatch")
        end

        Binding.new(
          surface: "app", transaction_model: ClientStepUpCeremonyTransaction,
          session_model: ClientStepUpSession, token_foreign_key: :user_token_id,
          methods: %w(passkey totp email_otp), scope_catalog: StepUpScopeCatalog::APP,
        )
      when VisitorToken
        unless actor.is_a?(Visitor) && token.visitor_id == actor.id
          deny!("Base actor mismatch", "session_binding_mismatch")
        end

        Binding.new(
          surface: "com", transaction_model: VisitorStepUpCeremonyTransaction,
          session_model: VisitorStepUpSession, token_foreign_key: :visitor_token_id,
          methods: %w(passkey email_otp), scope_catalog: StepUpScopeCatalog::COM,
        )
      when OperatorToken
        unless actor.is_a?(Operator) && token.staff_id == actor.id
          deny!("Base actor mismatch", "session_binding_mismatch")
        end

        Binding.new(
          surface: "org", transaction_model: OperatorStepUpCeremonyTransaction,
          session_model: OperatorStepUpSession, token_foreign_key: :staff_token_id, methods: %w(passkey),
          scope_catalog: StepUpScopeCatalog::ORG,
        )
      else
        deny!("Base session type mismatch", "session_binding_mismatch")
      end
    end

    def existing_transaction(pending, binding:, requirement:, token:, actor:, return_to:,
                             base_browser_nonce:, base_token:, restart_of:)
      return unless pending&.step_up_ceremony_transaction_ref

      transaction = binding.transaction_model.lock.find_by!(transaction_id: pending.step_up_ceremony_transaction_ref)
      now = binding.transaction_model.database_now
      return unless %w(pending verified).include?(transaction.status)

      # Issuance is a write under the session and row locks, so the expiry it observes is recorded
      # here. Read-only paths refuse an expired transaction without rewriting it.
      if transaction.expired?(now: now)
        transaction.commit_expiry!
        return
      end

      matching = transaction.actor_ref == actor.public_id && transaction.session_ref == token.public_id &&
        transaction.required_scope == requirement.scope &&
        transaction.step_up_required == requirement.step_up_required? &&
        transaction.user_verification_required == requirement.user_verification_required? &&
        transaction.full_reauthentication_required == requirement.full_reauthentication_required? &&
        transaction.phishing_resistant_required == requirement.phishing_resistant_required? &&
        transaction.audience == requirement.audience && transaction.token_binding == requirement.token_binding &&
        transaction.require_session_binding == requirement.require_session_binding &&
        transaction.tenant_ref == requirement.tenant_ref && transaction.resource_ref == requirement.resource_ref &&
        transaction.return_to == return_to && transaction.purpose == requirement.purpose &&
        transaction.allowed_methods_array.sort == (requirement.allowed_methods.map(&:to_s) & binding.methods).sort
      unless matching
        if restart_of.present?
          admission_binding = validate_restart_binding!(
            transaction:, binding:, requirement:, restart_of:, base_browser_nonce:, base_token:,
          )
          if admission_binding.redeemed?
            return BaseStepUpCancelAndStartCommitter.call!(
              actor:, token:, previous_transaction: transaction, requirement:, return_to:,
              base_browser_nonce:, base_token:,
            )
          end
        end
        deny!(
          "another step-up transaction is pending", "transaction_conflict",
          context: { transaction_ref: transaction.transaction_id },
        )
      end

      transaction
    end

    def validate_restart_binding!(transaction:, binding:, requirement:, restart_of:, base_browser_nonce:, base_token:)
      unless restart_of.is_a?(String) && restart_of.match?(BaseAuthAdmissionCoordinator::ADMISSION_REFERENCE_PATTERN)
        deny!("step-up restart reference is invalid", "invalid_admission")
      end

      admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
        surface: binding.surface, reference: restart_of,
      )
      expected_purpose = BaseAuthAdmissionCoordinator::HANDOFF_PURPOSE.fetch(requirement.purpose)
      unless admission_binding.step_up_ceremony_transaction_id == transaction.id &&
          admission_binding.purpose == expected_purpose && admission_binding.retired_at.nil? &&
          (admission_binding.redeemed? || admission_binding.expires_at > transaction.class.database_now)
        deny!("step-up restart binding is unavailable", "invalid_admission")
      end

      expected_digest = AuthAdmissionBinding.browser_digest(
        surface: binding.surface, entry_ref: admission_binding.entry_ref, nonce: base_browser_nonce,
      )
      unless admission_binding.base_browser_digest == expected_digest &&
          admission_binding.base_token_id == base_token.id
        deny!("step-up restart browser binding mismatch", "session_binding_mismatch")
      end

      admission_binding
    end

    def create_transaction!(binding:, token:, actor:, requirement:, methods:, return_to:, now:)
      binding.transaction_model.create_transaction!(
        surface: binding.surface, actor_ref: actor.public_id, session_ref: token.public_id,
        required_scope: requirement.scope, required_aal: StepUpRequirement::NO_AAL,
        step_up_required: requirement.step_up_required?,
        user_verification_required: requirement.user_verification_required?,
        full_reauthentication_required: requirement.full_reauthentication_required?,
        audience: requirement.audience, token_binding: requirement.token_binding,
        require_session_binding: requirement.require_session_binding, tenant_ref: requirement.tenant_ref,
        phishing_resistant_required: requirement.phishing_resistant_required?,
        allowed_methods: methods, resource_ref: requirement.resource_ref, return_to: return_to, now: now,
        expires_at: now + requirement.ttl, purpose: requirement.purpose,
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
