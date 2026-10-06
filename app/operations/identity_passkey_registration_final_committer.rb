# frozen_string_literal: true

# Base's half of Passkey registration. Auth has verified the attestation and stored only a
# transaction-bound candidate; this operation is the sole writer that turns that candidate into an
# effective credential. The three realms deliberately share the lifecycle but keep their actor,
# Ticket, session and credential classes explicit.
class IdentityPasskeyRegistrationFinalCommitter
  CONFIG = {
    "app" => {
      ticket_class: AppTicketRecord,
      actor_class: Client,
      token_class: ClientToken,
      transaction_class: ClientStepUpCeremonyTransaction,
      session_class: ClientStepUpSession,
      ceremony_class: ClientAuthCeremonySession,
      candidate_class: IdentityPasskeyCeremonyCandidate,
      passkey_class: ClientPasskey,
      owner_key: :user_id,
      token_key: :user_token_id,
      owner_association: :client_passkeys,
      audit_event_id: ClientChronicleEvent::PASSKEY_REGISTERED,
      surface: "app",
    },
    "com" => {
      ticket_class: ComTicketRecord,
      actor_class: Visitor,
      token_class: VisitorToken,
      transaction_class: VisitorStepUpCeremonyTransaction,
      session_class: VisitorStepUpSession,
      ceremony_class: VisitorAuthCeremonySession,
      candidate_class: VisitorPasskeyCeremonyCandidate,
      passkey_class: VisitorPasskey,
      owner_key: :visitor_id,
      token_key: :visitor_token_id,
      owner_association: :visitor_passkeys,
      surface: "com",
    },
    "org" => {
      ticket_class: OrgTicketRecord,
      actor_class: Operator,
      token_class: OperatorToken,
      transaction_class: OperatorStepUpCeremonyTransaction,
      session_class: OperatorStepUpSession,
      ceremony_class: OperatorAuthCeremonySession,
      candidate_class: OperatorPasskeyCeremonyCandidate,
      passkey_class: OperatorPasskey,
      owner_key: :staff_id,
      token_key: :staff_token_id,
      owner_association: :staff_passkeys,
      audit_event_id: OperatorChronicleEvent::PASSKEY_REGISTERED,
      surface: "org",
    },
  }.freeze

  class << self
    public

    def call!(actor:, token:, transaction:, raw_result: nil, result_reference: nil,
              ip_address: nil, user_agent: nil)
      binding = binding_for(actor, token, transaction)
      validate_initial_binding!(binding, actor, token, transaction)
      payload, digest = read_result_delivery(
        transaction: transaction, raw_result: raw_result, result_reference: result_reference,
      )

      binding.fetch(:actor_class).connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          refuse!("registration actor unavailable") unless actor.login_allowed?
          commit_ticket!(binding, actor, token, transaction, payload, digest, ip_address, user_agent)
        end
      end
    rescue ActiveRecord::RecordNotFound, KeyError, TypeError
      refuse!("passkey registration record unavailable")
    rescue ActiveRecord::RecordNotUnique
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

    def binding_for(actor, token, transaction)
      CONFIG.values.find do |config|
        actor.is_a?(config.fetch(:actor_class)) && token.is_a?(config.fetch(:token_class)) &&
          transaction.is_a?(config.fetch(:transaction_class))
      end || refuse!("passkey registration binding mismatch")
    end

    def validate_initial_binding!(config, actor, token, transaction)
      actor_key = config.fetch(:owner_key)
      unless token.public_send(actor_key) == actor.id && transaction.surface == config.fetch(:surface) &&
          transaction.actor_ref == actor.public_id && transaction.session_ref == token.public_id &&
          %w(bootstrap credential_registration).include?(transaction.purpose)
        refuse!("passkey registration binding mismatch")
      end
      return unless token.is_a?(OperatorToken) && token.emergency_authentication_context?

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

    def commit_ticket!(config, actor, token, transaction, payload, digest, ip_address, user_agent)
      config.fetch(:ticket_class).connected_to(role: :writing) do
        config.fetch(:ticket_class).transaction do
          token.with_lock do
            record = config.fetch(:session_class).lock.find_by!(
              config.fetch(:token_key) => token.id,
              :step_up_ceremony_transaction_ref => transaction.transaction_id,
            )
            transaction.with_lock do
              ceremony = config.fetch(:ceremony_class).lock.find(payload.fetch("ceremony_session_ref"))
              candidate = config.fetch(:candidate_class).lock.find_by!(
                step_up_ceremony_transaction_ref: transaction.transaction_id,
              )
              now = transaction.class.database_now

              validate_ticket!(config, actor, token, transaction, record, digest, payload, now)
              validate_candidate!(config, actor, token, transaction, candidate, now)
              validate_continuity!(ceremony, transaction, now)
              return existing_credential!(actor, transaction, candidate, ceremony, config) if transaction.consumed?

              refuse!("passkey registration already ended") if candidate.consumed_at || ceremony.completed?

              credential = create_credential!(config, actor, candidate, ip_address, user_agent)
              candidate.update!(consumed_at: now)
              transaction.commit_registration_consumption!(
                now: now, method: "passkey", registered_credential_ref: credential.public_id,
              )
              ceremony.complete!(now: now)
              credential
            end
          end
        end
      end
    end

    def create_credential!(config, actor, candidate, ip_address, user_agent)
      credential = config.fetch(:passkey_class).create!(
        config.fetch(:owner_key) => actor.id,
        :webauthn_id => candidate.webauthn_id,
        :public_key => candidate.public_key,
        :sign_count => candidate.sign_count,
        :description => candidate.description,
        :transports => candidate.transports,
        **Webauthn::AuthenticatorMetadata.permit(candidate.metadata),
      )
      if config[:audit_event_id]
        IdentityAudit.record!(
          actor: actor, event_id: config.fetch(:audit_event_id), action: "passkey.register",
          subject: credential, ip_address: ip_address, user_agent: user_agent,
        )
      end
      credential
    end

    def validate_ticket!(config, actor, token, transaction, record, digest, payload, now)
      valid = token.currently_usable?(now) && transaction.surface == config.fetch(:surface) &&
        transaction.actor_ref == actor.public_id && transaction.session_ref == token.public_id &&
        %w(verified consumed).include?(transaction.status) && !transaction.expired?(now: now) &&
        transaction.purpose.in?(%w(bootstrap credential_registration)) && transaction.method == "passkey" &&
        transaction.aal == "none" && transaction.step_up_required == false &&
        transaction.phishing_resistant_required == false && transaction.user_verification_required == false &&
        transaction.full_reauthentication_required == false && transaction.allowed_methods_array.include?("passkey") &&
        record.status == "PENDING" && record.scope == transaction.required_scope && record.discard_at > now &&
        transaction.result_delivery_matches?(
          result_digest: digest, result_generation: payload.fetch("result_generation"), now: now,
        )
      refuse!("passkey registration permission unavailable") unless valid
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
        !ceremony.revoked_at && !ceremony.cancelled_at && ceremony.expires_at > now &&
        (ceremony.active?(now: now) || (transaction.consumed? && ceremony.completed?))
      refuse!("passkey registration continuity unavailable") unless valid
    end

    def existing_credential!(actor, transaction, candidate, ceremony, config)
      association = actor.public_send(config.fetch(:owner_association))
      credential = association.active.lock.find_by!(public_id: transaction.verified_credential_ref)
      return credential if candidate.consumed_at == transaction.consumed_at && ceremony.completed? &&
        credential.webauthn_id == candidate.webauthn_id &&
        ActiveSupport::SecurityUtils.secure_compare(credential.public_key, candidate.public_key)

      refuse!("finalized passkey credential unavailable")
    end
  end
end
