# frozen_string_literal: true

require "digest"

# Base's half of Passkey registration, in the same shape as TOTP enrollment: the ticket is consumed
# while the principal transaction still holds the actor lock. There is no distributed commit. A
# failure leaves either nothing changed or a terminal ticket without a credential; a retry may
# return the credential this ticket created, and never creates another. Registration grants no
# Step-Up freshness. The principal database's unique index is the authority on uniqueness.
class IdentityPasskeyRegistrationFinalCommitter
  class << self
    public

    def call!(actor:, token:, transaction:, raw_result:, ip_address: nil, user_agent: nil)
      validate_binding!(actor, token, transaction)
      payload = BaseAuthAdmissionCoordinator.read_result!(
        raw_code: raw_result, surface: "app", transaction_ref: transaction.transaction_id,
        expected_intent: transaction.purpose,
      )
      digest = Valkey::AuthState::OpaqueAdmissionStore.digest_for(
        purpose: "#{transaction.purpose}_result", raw_code: raw_result,
      )
      Client.connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          refuse!("registration actor unavailable") unless actor.login_allowed?

          commit_ticket!(actor, token, transaction, payload, digest, ip_address, user_agent)
        end
      end
    rescue ActiveRecord::RecordNotFound, KeyError
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

    def validate_binding!(actor, token, transaction)
      return if actor.is_a?(Client) && token.is_a?(ClientToken) &&
        transaction.is_a?(ClientStepUpCeremonyTransaction) && token.user_id == actor.id &&
        %w(bootstrap credential_registration).include?(transaction.purpose)

      refuse!("passkey registration binding mismatch")
    end

    def commit_ticket!(actor, token, transaction, payload, digest, ip_address, user_agent)
      AppTicketRecord.connected_to(role: :writing) do
        token.with_lock do
          record = ClientStepUpSession.lock.find_by!(
            user_token_id: token.id, step_up_ceremony_transaction_ref: transaction.transaction_id,
          )
          transaction.with_lock do
            candidate = IdentityPasskeyCeremonyCandidate.lock.find_by!(
              step_up_ceremony_transaction_ref: transaction.transaction_id,
            )
            ceremony = ClientAuthCeremonySession.lock.find(payload.fetch("ceremony_session_ref"))
            now = ClientStepUpCeremonyTransaction.database_now
            validate_ticket!(actor, token, transaction, record, digest, payload, now)
            validate_candidate!(actor, token, transaction, candidate, now)
            validate_continuity!(ceremony, transaction, now)
            return existing_credential!(actor, transaction, candidate, ceremony) if transaction.consumed?

            refuse!("passkey registration already ended") if candidate.consumed_at || ceremony.completed?

            credential = create_credential!(actor, candidate, ip_address, user_agent)
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

    def create_credential!(actor, candidate, ip_address, user_agent)
      credential = ClientPasskey.create!(
        user_id: actor.id, webauthn_id: candidate.webauthn_id, public_key: candidate.public_key,
        sign_count: candidate.sign_count, description: candidate.description,
        **Webauthn::AuthenticatorMetadata.permit(candidate.metadata),
      )
      IdentityAudit.record!(
        actor: actor, event_id: ClientChronicleEvent::PASSKEY_REGISTERED, action: "passkey.register",
        subject: credential, ip_address: ip_address, user_agent: user_agent,
      )
      credential
    end

    def validate_ticket!(actor, token, transaction, record, digest, payload, now)
      return if token.currently_usable?(now) && transaction.surface == "app" &&
        transaction.actor_ref == actor.public_id && transaction.session_ref == token.public_id &&
        %w(verified consumed).include?(transaction.status) && !transaction.expired?(now: now) &&
        transaction.method == "passkey" && transaction.aal == "none" &&
        transaction.required_aal == "none" && transaction.phishing_resistant_required == false &&
        transaction.allowed_methods_array.include?("passkey") &&
        record.status == "PENDING" && record.scope == transaction.required_scope && record.discard_at > now &&
        transaction.result_delivery_matches?(
          result_digest: digest, result_generation: payload.fetch("result_generation"), now: now,
        )

      refuse!("passkey registration permission unavailable")
    end

    def validate_candidate!(actor, token, transaction, candidate, now)
      return if candidate.surface == "app" && candidate.actor_ref == actor.public_id &&
        candidate.session_ref == token.public_id &&
        candidate.step_up_ceremony_transaction_ref == transaction.transaction_id &&
        candidate.expires_at > now && candidate.material_intact?

      refuse!("verified passkey candidate unavailable")
    end

    def validate_continuity!(ceremony, transaction, now)
      return if ceremony.admitted? && ceremony.admission_purpose == "#{transaction.purpose}_handoff" &&
        ceremony.step_up_ceremony_transaction_ref == transaction.transaction_id &&
        !ceremony.revoked_at && !ceremony.cancelled_at && ceremony.expires_at > now &&
        (ceremony.active?(now: now) || (transaction.consumed? && ceremony.completed?))

      refuse!("passkey registration continuity unavailable")
    end

    # A retry of the same result returns the credential this ticket created. A missing, removed or
    # different credential is refused: nothing is recreated.
    def existing_credential!(actor, transaction, candidate, ceremony)
      credential = actor.client_passkeys.active.lock.find_by!(public_id: transaction.verified_credential_ref)
      return credential if candidate.consumed_at == transaction.consumed_at && ceremony.completed? &&
        credential.webauthn_id == candidate.webauthn_id &&
        ActiveSupport::SecurityUtils.secure_compare(credential.public_key, candidate.public_key)

      refuse!("finalized passkey credential unavailable")
    end
  end
end
