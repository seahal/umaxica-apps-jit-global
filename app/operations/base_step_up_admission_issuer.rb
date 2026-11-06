# frozen_string_literal: true

# Base retains the concrete transaction and browser-session binding. Auth receives only a
# purpose-scoped opaque admission to the existing actor-specific ticket transaction.
class BaseStepUpAdmissionIssuer
  Binding = Data.define(:surface, :transaction_model, :session_model, :token_foreign_key, :methods, :scope_catalog)

  class << self
    public

    def conflict_binding_for_form!(actor:, token:, transaction:, base_browser_nonce:, base_token:)
      binding = binding_for(actor, token)
      device_session = token.device_session_record!
      unless base_token.equal?(token) && transaction.is_a?(binding.transaction_model) &&
          transaction.actor_ref == actor.public_id && transaction.session_ref == token.public_id &&
          %w(pending verified).include?(transaction.status) &&
          !transaction.expired?(now: transaction.class.database_now) && actor.login_allowed? &&
          token.active_status?(token.class.database_now) && device_session.usable? &&
          device_session.current_refresh_token_id == token.id
        deny!("step-up conflict parent is unavailable", "invalid_admission")
      end

      admission = BaseAuthAdmissionCoordinator.admission_binding_model(binding.surface).find_sole_by(
        step_up_ceremony_transaction_id: transaction.id,
        status_id: [*AuthAdmissionBinding::ACTIVE_STATUS_IDS, AuthAdmissionBinding::REDEEMED_STATUS_ID],
      )
      validate_restart_binding!(
        transaction:, binding:, purpose: transaction.purpose, restart_of: admission.entry_ref,
        base_browser_nonce:, base_token:,
      )
    rescue ActiveRecord::RecordNotFound, ActiveRecord::SoleRecordExceeded
      deny!("step-up conflict binding is unavailable", "invalid_admission")
    end

    def restart_binding_for_form!(actor:, token:, requirement:, return_to:, base_browser_nonce:, base_token:,
                                  restart_of:)
      deny!("Base token binding is invalid", "session_binding_mismatch") unless base_token.equal?(token)

      binding = binding_for(actor, token)
      validate_requirement!(requirement, actor:, token:, return_to:, binding:, oidc_step_up_context: nil)
      admission = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: binding.surface, reference: restart_of)
      transaction = binding.transaction_model.find_by(id: admission.step_up_ceremony_transaction_id)
      unless transaction && %w(pending verified).include?(transaction.status) &&
          !transaction.expired?(now: transaction.class.database_now) &&
          matching_pending_intent?(transaction, binding:, requirement:, token:, actor:, return_to:)
        deny!("step-up restart parent is unavailable", "invalid_admission")
      end

      device_session = token.device_session_record!
      unless actor.login_allowed? && token.active_status?(token.class.database_now) && device_session.usable? &&
          device_session.current_refresh_token_id == token.id
        deny!("Base session is unavailable", "session_expired")
      end

      validate_restart_binding!(
        transaction:, binding:, purpose: requirement.purpose, restart_of:, base_browser_nonce:, base_token:,
      )
    end

    def call!(actor:, token:, requirement:, return_to:, base_browser_nonce: nil, base_browser_digest: nil,
              base_token:, restart_of: nil, step_up_evidence: nil, oidc_step_up_context: nil)
      unless base_token.equal?(token)
        deny!("Base token binding is invalid", "session_binding_mismatch")
      end
      nonce_present = base_browser_nonce.is_a?(String) && base_browser_nonce.present?
      digest_present = base_browser_digest.is_a?(String) && base_browser_digest.match?(/\A[0-9a-f]{64}\z/)
      unless nonce_present ^ digest_present
        deny!("Base browser binding proof is invalid", "session_binding_mismatch")
      end
      if digest_present && restart_of.present?
        deny!("Base browser binding restart is invalid", "session_binding_mismatch")
      end

      binding = binding_for(actor, token)
      validate_requirement!(
        requirement, actor:, token:, return_to:, binding:, oidc_step_up_context:,
      )
      actor.class.connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          deny!("Base actor is unavailable", "authorization_denied") unless actor.login_allowed?

          ensure_bootstrap_eligible!(actor) if requirement.purpose == "bootstrap"

          binding.transaction_model.connection_owner.connected_to(role: :writing) do
            device_session = token.device_session_record!
            device_session.with_lock do
              token.with_lock do
                issue_under_root_locks!(
                  actor:, token:, binding:, requirement:, return_to:, base_browser_nonce:, base_browser_digest:,
                  base_token:, restart_of:,
                  device_session:, step_up_evidence:, oidc_step_up_context:,
                )
              end
            end
          end
        end
      end
    end

    private

    def issue_under_root_locks!(actor:, token:, binding:, requirement:, return_to:, base_browser_nonce:,
                                base_browser_digest:, base_token:, restart_of:, device_session:,
                                step_up_evidence:, oidc_step_up_context:)
      now = binding.transaction_model.database_now
      unless token.active_status?(now) && device_session.usable? &&
          device_session.current_refresh_token_id == token.id
        deny!("Base session is unavailable", "session_expired")
      end
      ensure_bootstrap_session!(token, now) if requirement.purpose == "bootstrap"
      if token.is_a?(OperatorToken) && token.standby_authentication_context?
        deny!("Emergency session cannot initiate step-up", "authorization_denied")
      end
      if requirement.purpose == "credential_registration"
        ensure_registration_authorized!(actor:, token:, step_up_evidence:, now:)
      end
      validate_oidc_step_up_context!(
        oidc_step_up_context:, requirement:, actor:, token:, binding:, device_session:, now:,
      ) if requirement.purpose == "step_up"

      methods = requirement.allowed_methods.map(&:to_s) & binding.methods
      deny!("step-up method unavailable", "unsupported_method") if methods.empty?

      session_scope = binding.session_model.where(binding.token_foreign_key => token.id)
      parent_ref = session_scope.pick(:step_up_ceremony_transaction_ref)
      binding.transaction_model.lock.find_by!(transaction_id: parent_ref) if parent_ref
      pending = session_scope.lock.first
      unless pending&.step_up_ceremony_transaction_ref == parent_ref
        deny!("step-up session changed before admission", "session_binding_mismatch")
      end
      transaction = existing_transaction(
        pending, binding:, requirement:, token:, actor:, return_to:, base_browser_nonce:, base_token:, restart_of:,
      )
      if transaction.is_a?(BaseAuthAdmissionCoordinator::Issuance) ||
          transaction.is_a?(BaseAuthAdmissionCoordinator::TerminalOutcome)
        return transaction
      end

      transaction ||= create_transaction!(
        binding:, token:, actor:, requirement:, methods:, return_to:, now: binding.transaction_model.database_now,
      )
      persist_session!(pending:, transaction:, binding:, token:)
      BaseAuthAdmissionCoordinator.issue_handoff!(
        transaction:, base_browser_nonce:, base_browser_digest:, base_token:, restart_of:,
      )
    end

    def deny!(message, code, context: {})
      raise BaseAuthAdmissionCoordinator::Denied.new(message, code: code, context: context)
    end

    def validate_requirement!(requirement, actor:, token:, return_to:, binding:, oidc_step_up_context:)
      unless requirement.is_a?(StepUpRequirement) &&
          supported_requirement_purpose?(requirement, binding, oidc_step_up_context:) &&
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

    def supported_requirement_purpose?(requirement, binding, oidc_step_up_context:)
      return requirement.step_up_required? if requirement.purpose == "reauthentication"

      if requirement.purpose == "step_up"
        return supported_oidc_step_up_requirement?(requirement, binding, oidc_step_up_context:)
      end

      if requirement.purpose == "credential_registration"
        return supported_registration_requirement?(requirement, binding)
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

    def supported_oidc_step_up_requirement?(requirement, binding, oidc_step_up_context:)
      context_model = oidc_step_up_context_model(binding.surface)
      oidc_step_up_context.is_a?(context_model) && oidc_step_up_context.persisted? &&
        requirement.step_up_required? && !requirement.phishing_resistant_required? &&
        !requirement.user_verification_required? && !requirement.full_reauthentication_required? &&
        requirement.scope == OidcAuthorizeRequestResolver::STEP_UP_SCOPE &&
        requirement.resource_ref == oidc_step_up_context.public_id && requirement.tenant_ref.nil? &&
        requirement.allowed_methods.present? &&
        (requirement.allowed_methods.map(&:to_s) - binding.methods).empty?
    end

    def validate_oidc_step_up_context!(oidc_step_up_context:, requirement:, actor:, token:, binding:, device_session:,
                                       now:)
      context_model = oidc_step_up_context_model(binding.surface)
      context_state_model = oidc_step_up_context_state_model(binding.surface)
      authorization_model = OidcAuthorizationTransactionCoordinator.model_for(binding.surface)
      grant_model = oidc_step_up_grant_model(binding.surface)
      expected_resource_type = { "app" => "client", "org" => "operator" }.fetch(binding.surface)
      expected_subject = OidcSubject.for(actor, resource_type: expected_resource_type)

      grant = grant_model.lock.find(oidc_step_up_context.grant_id)
      authorization = authorization_model.lock.find(oidc_step_up_context.oidc_authorization_transaction_id)
      context = context_model.lock.find(oidc_step_up_context.id)
      grant_root_id =
        case [grant, token]
        in [OpAppGrant, ClientToken] then grant.client_token_id
        in [OpOrgGrant, OperatorToken] then grant.operator_token_id
        else nil
        end

      unless context.public_id == requirement.resource_ref &&
          context.state_id == context_state_model::PENDING && context.expires_at > now &&
          context.bound_subject == expected_subject && context.grant_id == grant.id &&
          context.requested_acr == OidcAuthorizeRequestResolver::STEP_UP_ACR &&
          authorization.intent == "step_up" && authorization.pending? && !authorization.expired?(now:) &&
          !authorization.login_challenge_expired?(now:) && authorization.surface == binding.surface &&
          authorization.client_id == grant.oidc_client_id && grant_root_id == token.id &&
          grant.device_session_id == device_session.id && grant.active?(now)
        deny!("OIDC step-up context binding is unavailable", "invalid_admission")
      end
    rescue ActiveRecord::RecordNotFound
      deny!("OIDC step-up context binding is unavailable", "invalid_admission")
    end

    def oidc_step_up_context_model(surface)
      { "app" => ClientStepUpContext, "org" => OperatorStepUpContext }.fetch(surface)
    end

    def oidc_step_up_context_state_model(surface)
      { "app" => ClientStepUpContextState, "org" => OperatorStepUpContextState }.fetch(surface)
    end

    def oidc_step_up_grant_model(surface)
      { "app" => OpAppGrant, "org" => OpOrgGrant }.fetch(surface)
    end

    def supported_registration_requirement?(requirement, binding)
      method =
        case requirement.scope
        when "settings_passkey" then :passkey
        when "settings_totp" then :totp if binding.surface == "app"
        when "social_link" then :passkey if binding.surface == "app"
        end
      method.present? && requirement.allowed_methods == [method] && !requirement.step_up_required? &&
        !requirement.phishing_resistant_required? && !requirement.user_verification_required? &&
        !requirement.full_reauthentication_required?
    end

    def ensure_registration_authorized!(actor:, token:, step_up_evidence:, now:)
      return if token.active_status?(now) && StepUpEvidenceVerifier.call(
        evidence: step_up_evidence, actor: actor, token: token,
      )

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

      matching = matching_pending_intent?(transaction, binding:, requirement:, token:, actor:, return_to:)
      if restart_of.present?
        admission_binding = validate_restart_binding!(
          transaction:, binding:, purpose: requirement.purpose, restart_of:, base_browser_nonce:, base_token:,
        )
        if admission_binding.redeemed?
          return BaseStepUpCancelAndStartCommitter.call!(
            actor:, token:, previous_transaction: transaction, requirement:, return_to:,
            base_browser_nonce:, base_token:,
          )
        end
      end
      unless matching
        deny!(
          "another step-up transaction is pending", "transaction_conflict",
          context: { transaction_ref: transaction.transaction_id },
        )
      end

      transaction
    end

    def matching_pending_intent?(transaction, binding:, requirement:, token:, actor:, return_to:)
      transaction.actor_ref == actor.public_id && transaction.session_ref == token.public_id &&
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
    end

    def validate_restart_binding!(transaction:, binding:, purpose:, restart_of:, base_browser_nonce:, base_token:)
      unless restart_of.is_a?(String) && restart_of.match?(AuthAdmissionBinding::REFERENCE_PATTERN)
        deny!("step-up restart reference is invalid", "invalid_admission")
      end

      admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
        surface: binding.surface, reference: restart_of,
      )
      expected_purpose = BaseAuthAdmissionCoordinator::HANDOFF_PURPOSE.fetch(purpose)
      unless admission_binding.step_up_ceremony_transaction_id == transaction.id &&
          admission_binding.purpose == expected_purpose &&
          (admission_binding.active? || admission_binding.redeemed?)
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
      if pending.is_a?(ClientStepUpSession)
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
