# frozen_string_literal: true

require "digest"

# Ticket consumption commits while the principal transaction still holds the actor lock. A
# subsequent principal-commit failure leaves a terminal ticket: retry may return an existing
# active credential, but never recreate a missing or revoked one. Registration grants no freshness.
class IdentityTotpEnrollmentFinalCommitter
  class << self
    public

    def call!(actor:, token:, transaction:, raw_result: nil, result_reference: nil)
      validate_binding!(actor, token, transaction)
      payload, digest = read_result_delivery(
        transaction: transaction, raw_result: raw_result, result_reference: result_reference,
      )
      Client.connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          raise IdentityTotpCeremonyContract::Error, "enrollment actor unavailable" unless actor.login_allowed?

          commit_ticket!(actor, token, transaction, payload, digest)
        end
      end
    rescue ActiveRecord::RecordNotFound
      raise IdentityTotpCeremonyContract::Error, "enrollment record unavailable"
    rescue ClientTotpCredential::SlotLimitExceeded
      raise IdentityTotpCeremonyContract::Error, "TOTP credential limit is reached"
    end

    def read_result_delivery(transaction:, raw_result:, result_reference:)
      if result_reference.present?
        [
          BaseAuthAdmissionCoordinator.read_result_reference!(
            reference: result_reference, surface: "app", transaction_ref: transaction.transaction_id,
            expected_intent: transaction.purpose,
          ),
          transaction.result_digest,
        ]
      else
        raise ArgumentError, "TOTP result is required" unless raw_result.is_a?(String) && raw_result.present?

        [
          BaseAuthAdmissionCoordinator.read_result!(
            raw_code: raw_result, surface: "app", transaction_ref: transaction.transaction_id,
            expected_intent: transaction.purpose,
          ),
          Valkey::AuthState::OpaqueAdmissionStore.digest_for(
            purpose: "#{transaction.purpose}_result", raw_code: raw_result,
          ),
        ]
      end
    end

    private

    # Bootstrap retains the original protected operation; the child binds TOTP registration.
    # Later authenticator registration requires its own settings scope.
    def enrollment_scope_permitted?(transaction)
      transaction.required_scope == "settings_totp" ||
        (transaction.purpose == "bootstrap" && StepUpScopeCatalog::APP.key?(transaction.required_scope))
    end

    def validate_binding!(actor, token, transaction)
      unless actor.is_a?(Client) && token.is_a?(ClientToken) &&
          transaction.is_a?(ClientStepUpCeremonyTransaction) && token.user_id == actor.id &&
          %w(bootstrap credential_registration).include?(transaction.purpose)
        raise IdentityTotpCeremonyContract::Error, "TOTP enrollment binding mismatch"
      end
    end

    def commit_ticket!(actor, token, transaction, payload, digest)
      AppTicketRecord.connected_to(role: :writing) do
        token.with_lock do
          record = ClientStepUpSession.lock.find_by!(
            user_token_id: token.id, step_up_ceremony_transaction_ref: transaction.transaction_id,
          )
          transaction.with_lock do
            child = ClientTotpCeremonyTransaction.lock.find_by!(
              step_up_ceremony_transaction_ref: transaction.transaction_id,
            )
            candidate = IdentityTotpCeremonyCandidate.lock.find_by!(ref: child.credential_candidate_ref)
            ceremony = ClientAuthCeremonySession.lock.find(payload.fetch("ceremony_session_ref"))
            now = ClientStepUpCeremonyTransaction.database_now
            validate_ticket!(actor, token, transaction, record, digest, payload, now)
            validate_candidate!(actor, token, transaction, child, candidate, now)
            validate_continuity!(ceremony, transaction, now)
            return existing_credential!(actor, transaction, child, candidate, ceremony) if transaction.consumed?

            if child.consumed? || candidate.consumed_at || ceremony.completed?
              raise IdentityTotpCeremonyContract::Error, "enrollment already ended"
            end

            credential = ClientTotpCredential.create_for_user!(
              user: actor, private_key: candidate.private_key, title: candidate.title,
              last_otp_at: candidate.last_otp_at,
              user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
            )
            child.update!(status: "consumed", result_jti: transaction.result_jti, consumed_at: now)
            candidate.update!(consumed_at: now)
            transaction.commit_registration_consumption!(
              now: now, method: "totp", registered_credential_ref: credential.public_id,
            )
            ceremony.complete!(now: now)
            credential
          end
        end
      end
    end

    def validate_ticket!(actor, token, transaction, record, digest, payload, now)
      unless token.currently_usable?(now) && transaction.surface == "app" &&
          transaction.actor_ref == actor.public_id && transaction.session_ref == token.public_id &&
          %w(bootstrap credential_registration).include?(transaction.purpose) &&
          %w(verified consumed).include?(transaction.status) && enrollment_scope_permitted?(transaction) &&
          record.status == "PENDING" && record.scope == transaction.required_scope && record.discard_at > now &&
          transaction.result_delivery_matches?(
            result_digest: digest, result_generation: payload.fetch("result_generation"), now: now,
          )
        raise IdentityTotpCeremonyContract::Error, "enrollment permission unavailable"
      end

      validate_registration_evidence!(transaction, now)
    end

    def validate_registration_evidence!(transaction, now)
      unless transaction.step_up_required == false && transaction.phishing_resistant_required == false &&
          transaction.user_verification_required == false && transaction.full_reauthentication_required == false &&
          transaction.method == "totp" && transaction.aal == "none" && transaction.phishing_resistant == false &&
          transaction.allowed_methods_array.include?("totp") && transaction.verified_at &&
          transaction.verified_at >= transaction.created_at && transaction.verified_at <= now
        raise IdentityTotpCeremonyContract::Error, "registration evidence unavailable"
      end
    end

    def validate_candidate!(actor, token, transaction, child, candidate, now)
      unless child.surface == "app" && child.actor_ref == actor.public_id && child.session_ref == token.public_id &&
          child.operation == "registration" && child.expires_at > now &&
          candidate.step_up_ceremony_transaction_ref == transaction.transaction_id &&
          candidate.surface == "app" && candidate.actor_ref == actor.public_id &&
          candidate.session_ref == token.public_id &&
          candidate.expires_at > now && candidate.last_otp_at && candidate.last_otp_at <= transaction.verified_at &&
          child.credential_candidate_digest == candidate.digest &&
          ActiveSupport::SecurityUtils.secure_compare(candidate.digest, Digest::SHA256.hexdigest(candidate.private_key))
        raise IdentityTotpCeremonyContract::Error, "confirmed TOTP candidate unavailable"
      end
    end

    def validate_continuity!(ceremony, transaction, now)
      unless ceremony.admitted? && ceremony.admission_purpose == "#{transaction.purpose}_handoff" &&
          ceremony.step_up_ceremony_transaction_ref == transaction.transaction_id &&
          !ceremony.revoked_at && !ceremony.cancelled_at && ceremony.expires_at > now &&
          (ceremony.active?(now: now) || (transaction.consumed? && ceremony.completed?))
        raise IdentityTotpCeremonyContract::Error, "enrollment continuity unavailable"
      end
    end

    def existing_credential!(actor, transaction, child, candidate, ceremony)
      credential = actor.client_totp_credentials.lock.find_by!(public_id: transaction.verified_credential_ref)
      unless child.consumed? && child.result_jti == transaction.result_jti &&
          child.consumed_at == transaction.consumed_at && candidate.consumed_at == transaction.consumed_at &&
          ceremony.completed? && credential.active? &&
          credential.last_otp_at && credential.last_otp_at >= candidate.last_otp_at &&
          ActiveSupport::SecurityUtils.secure_compare(candidate.digest, Digest::SHA256.hexdigest(credential.private_key))
        raise IdentityTotpCeremonyContract::Error, "finalized TOTP credential unavailable"
      end

      credential
    end
  end
end
