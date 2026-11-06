# frozen_string_literal: true

# Base's half of Passkey registration. Auth has verified the attestation and stored only a
# transaction-bound candidate; this operation is the sole writer that turns that candidate into an
# effective credential. The remaining realms deliberately share the lifecycle but keep their actor,
# Ticket, session and credential classes explicit.
class IdentityPasskeyRegistrationFinalCommitter
  # An enclosing OP transaction would defer the candidate/proof consumption while the independent
  # Zenith credential and audit commit. Refuse instead of reporting a committed registration.
  class TransactionConflict < ArgumentError; end

  CONFIG = {
    "app" => {
      ticket_class: OpBaseAppRecord,
      actor_class: Client,
      token_class: ClientToken,
      transaction_class: ClientStepUpCeremonyTransaction,
      session_class: ClientStepUpSession,
      ceremony_class: ClientAuthCeremonySession,
      candidate_class: IdentityPasskeyCeremonyCandidate,
      passkey_class: ClientPasskey,
      owner_key: :user_id,
      token_key: :user_token_id,
      audit_event_id: ClientChronicleEvent::PASSKEY_REGISTERED,
      surface: "app",
    },
    "org" => {
      ticket_class: OpBaseOrgRecord,
      actor_class: Operator,
      token_class: OperatorToken,
      transaction_class: OperatorStepUpCeremonyTransaction,
      session_class: OperatorStepUpSession,
      ceremony_class: OperatorAuthCeremonySession,
      candidate_class: OperatorPasskeyCeremonyCandidate,
      passkey_class: OperatorPasskey,
      owner_key: :staff_id,
      token_key: :staff_token_id,
      audit_event_id: OperatorChronicleEvent::PASSKEY_REGISTERED,
      surface: "org",
    },
  }.freeze

  class << self
    public

    def call!(actor:, token:, transaction:, raw_result: nil, result_reference: nil,
              ip_address: nil, user_agent: nil, step_up_evidence: nil)
      binding = binding_for(actor, token, transaction)
      validate_initial_binding!(binding, actor, token, transaction)
      require_independent_ticket_commit!(binding)
      payload, digest = read_result_delivery(
        transaction: transaction, raw_result: raw_result, result_reference: result_reference,
      )

      binding.fetch(:actor_class).connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          refuse!("registration actor unavailable") unless actor.login_allowed?
          commit_ticket!(
            binding, actor, token, transaction, payload, digest, ip_address, user_agent, step_up_evidence,
          )
        end
      end
    rescue ActiveRecord::RecordNotFound, KeyError, TypeError
      refuse!("passkey registration record unavailable")
    rescue ActiveRecord::RecordNotUnique => e
      raise unless PasskeyRegistrationOperation.credential_id_conflict?(e)

      refuse!("passkey credential is already registered")
    rescue ActiveRecord::RecordInvalid
      refuse!("passkey credential was not accepted")
    rescue BaseAuthAdmissionCoordinator::Denied, IdentityStepUpCeremonyContract::Error
      refuse!("passkey registration result unavailable")
    end

    private

    def refuse!(message)
      raise IdentityPasskeyCeremonyContract::Error, message
    end

    # Candidate and proof consumption precede the Zenith credential, so the OP commit must be
    # independent. Checked before the result reference is read.
    def require_independent_ticket_commit!(config)
      ticket = config.fetch(:ticket_class)
      ticket.connected_to(role: :writing) do
        connection = ticket.lease_connection
        if connection.transaction_open?
          raise TransactionConflict, "passkey registration requires an independent OP commit"
        end
      end
    end

    def binding_for(actor, token, transaction)
      CONFIG.values.find do |config|
        actor.is_a?(config.fetch(:actor_class)) && token.is_a?(config.fetch(:token_class)) &&
          transaction.is_a?(config.fetch(:transaction_class))
      end || refuse!("passkey registration binding mismatch")
    end

    def validate_initial_binding!(config, actor, token, transaction)
      actor_key = config.fetch(:owner_key)
      unless token[actor_key] == actor.id && transaction.surface == config.fetch(:surface) &&
          transaction.actor_ref == actor.public_id && transaction.session_ref == token.public_id &&
          %w(bootstrap credential_registration).include?(transaction.purpose)
        refuse!("passkey registration binding mismatch")
      end
      return unless token.is_a?(OperatorToken) && token.standby_authentication_context?

      refuse!("passkey registration binding mismatch")

    end

    def read_result_delivery(transaction:, raw_result:, result_reference:)
      if result_reference.present?
        [
          BaseAuthAdmissionCoordinator.read_result_reference!(
            reference: result_reference, surface: transaction.surface,
            transaction_ref: transaction.transaction_id, expected_intent: transaction.purpose,
          ),
          transaction.result_digest,
        ]
      else
        unless raw_result.is_a?(String) && raw_result.present?
          raise ArgumentError, "registration result is required"
        end

        [
          BaseAuthAdmissionCoordinator.read_result!(
            raw_code: raw_result, surface: transaction.surface,
            transaction_ref: transaction.transaction_id, expected_intent: transaction.purpose,
          ),
          Valkey::AuthState::OpaqueAdmissionStore.digest_for(
            purpose: "#{transaction.purpose}_result", raw_code: raw_result,
          ),
        ]
      end
    end

    def commit_ticket!(config, actor, token, transaction, payload, digest, _ip_address, _user_agent, step_up_evidence)
      config.fetch(:ticket_class).connected_to(role: :writing) do
        config.fetch(:ticket_class).transaction do
          device = token.device_session_record!
          device.with_lock do
            commit_under_device_lock!(config, actor, token, transaction, payload, digest, device, step_up_evidence)
          end
        end
      end
    end

    def commit_under_device_lock!(config, actor, token, transaction, payload, digest, device, step_up_evidence)
      token.with_lock do
        if token.is_a?(OperatorToken) && token.standby_authentication_context?
          refuse!("passkey registration binding mismatch")
        end

        validate_registration_device!(actor, token, device)
        transaction.with_lock do
          record = config.fetch(:session_class).lock.find_by!(
            config.fetch(:token_key) => token.id,
            :step_up_ceremony_transaction_ref => transaction.transaction_id,
          )
          ceremony = config.fetch(:ceremony_class).lock.find(payload.fetch("ceremony_session_ref"))
          candidate = config.fetch(:candidate_class).lock.find_by!(
            step_up_ceremony_transaction_ref: transaction.transaction_id,
          )
          now = transaction.class.database_now

          validate_ticket!(config, actor, token, transaction, record, digest, payload, now)
          validate_candidate!(config, actor, token, transaction, candidate, now)
          validate_continuity!(ceremony, transaction, now)
          return existing_credential!(actor, transaction, candidate, ceremony) if transaction.consumed?

          refuse!("passkey registration already ended") if candidate.consumed_at || ceremony.completed?
          ensure_current_registration_authority!(actor, token, transaction, step_up_evidence)

          credential = create_credential!(config, actor, transaction, candidate)
          candidate.update!(consumed_at: now)
          transaction.commit_registration_consumption!(
            now: now, method: "passkey", registered_credential_ref: credential_reference(credential),
          )
          ceremony.complete!
          credential
        end
      end
    end

    def validate_registration_device!(actor, token, device)
      owner_matches =
        case actor
        when Client then device.user_id == actor.id && token.user_id == actor.id
        when Operator then device.staff_id == actor.id && token.staff_id == actor.id
        else false
        end
      return if owner_matches && device.usable? && token.device_session_id == device.id &&
        device.current_refresh_token_id == token.id

      refuse!("passkey registration device or session unavailable")
    end

    def create_credential!(config, actor, transaction, candidate)
      event_type =
        if transaction.purpose == "bootstrap"
          "passkey.registered.signup"
        else
          "passkey.registered.settings"
        end

      PasskeyRegistrationOperation.call!(
        actor: actor,
        passkey_class: config.fetch(:passkey_class),
        attributes: {
          webauthn_id: candidate.webauthn_id,
          public_key: candidate.public_key,
          sign_count: candidate.sign_count,
          description: candidate.description,
          transports: candidate.transports,
          **Webauthn::AuthenticatorMetadata.permit(candidate.metadata),
        },
        audit: {
          event_type: event_type,
          surface: config.fetch(:surface),
          actor_ref: actor.public_id,
          operation_ref: transaction.transaction_id,
        },
      )
    end

    def registration_policy(actor)
      case actor
      when Client then ClientPasskeyPolicy.new(ClientPasskey, user: actor)
      when Operator then OperatorPasskeyPolicy.new(OperatorPasskey, user: actor)
      else refuse!("unsupported passkey registration actor")
      end
    end

    def ensure_current_registration_authority!(actor, token, transaction, evidence)
      return if transaction.purpose == "bootstrap"

      policy = registration_policy(actor)
      now = transaction.class.database_now
      unless !transaction.expired?(now: now) &&
          transaction.required_scope == policy.management_requirement(token: token).scope &&
          policy.apply(:create?) && policy.management_authorized?(token: token, now: now) &&
          StepUpEvidenceVerifier.call(evidence:, actor:, token:)
        refuse!("passkey registration requires current Step-Up")
      end
    end

    def validate_ticket!(config, actor, token, transaction, record, digest, payload, now)
      valid = token.active_status?(now) && ticket_binding_matches?(config, actor, token, transaction, now) &&
        ticket_policy_matches?(transaction) && registration_record_matches?(record, transaction, now) &&
        ticket_result_matches?(transaction, digest, payload, now)
      refuse!("passkey registration permission unavailable") unless valid
    end

    def ticket_binding_matches?(config, actor, token, transaction, now)
      transaction.surface == config.fetch(:surface) && transaction.actor_ref == actor.public_id &&
        transaction.session_ref == token.public_id && %w(verified consumed).include?(transaction.status) &&
        !transaction.expired?(now: now)
    end

    def ticket_policy_matches?(transaction)
      transaction.purpose.in?(%w(bootstrap credential_registration)) && transaction.method == "passkey" &&
        transaction.aal == "none" && transaction.step_up_required == false &&
        transaction.phishing_resistant_required == false && transaction.user_verification_required == false &&
        transaction.full_reauthentication_required == false && transaction.allowed_methods_array.include?("passkey")
    end

    def registration_record_matches?(record, transaction, now)
      record.status == "PENDING" && record.scope == transaction.required_scope && record.discard_at > now
    end

    def ticket_result_matches?(transaction, digest, payload, now)
      transaction.result_delivery_matches?(
        result_digest: digest, result_generation: payload.fetch("result_generation"), now: now,
      )
    end

    def validate_candidate!(config, actor, token, transaction, candidate, now)
      valid = candidate.surface == config.fetch(:surface) && candidate.actor_ref == actor.public_id &&
        candidate.session_ref == token.public_id &&
        candidate.step_up_ceremony_transaction_ref == transaction.transaction_id &&
        candidate.expires_at > now && candidate.material_intact?
      refuse!("verified passkey candidate unavailable") unless valid
    end

    def validate_continuity!(ceremony, transaction, now)
      valid = ceremony.admitted? && ceremony.admission_purpose == "#{transaction.purpose}_handoff" &&
        ceremony.step_up_ceremony_transaction_ref == transaction.transaction_id &&
        ceremony.expires_at > now &&
        (ceremony.active?(now: now) || (transaction.consumed? && ceremony.completed?))
      refuse!("passkey registration continuity unavailable") unless valid
    end

    def credential_reference(credential)
      case credential
      when ClientPasskey then credential.public_id
      when OperatorPasskey then credential.external_id
      else refuse!("unsupported passkey registration credential")
      end
    end

    def existing_credential!(actor, transaction, candidate, ceremony)
      credential =
        case actor
        when Client then actor.client_passkeys.active.lock.find_by!(public_id: transaction.verified_credential_ref)
        when Operator then actor.staff_passkeys.active.lock.find_by!(external_id: transaction.verified_credential_ref)
        else refuse!("unsupported passkey registration owner")
        end
      return credential if candidate.consumed_at == transaction.consumed_at && ceremony.completed? &&
        credential.webauthn_id == candidate.webauthn_id &&
        ActiveSupport::SecurityUtils.secure_compare(credential.public_key, candidate.public_key)

      refuse!("finalized passkey credential unavailable")
    end
  end
end
