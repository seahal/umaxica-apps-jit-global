# frozen_string_literal: true

require "digest"

# Base's purpose-specific permission owns the lifetime. Repeated starts return the same encrypted
# candidate and never reset the parent deadline or its failure counter.
class IdentityTotpEnrollmentIssuer
  class << self
    public

    def call!(actor:, token:, transaction:)
      unless actor.is_a?(Client) && token.is_a?(ClientToken) &&
          transaction.is_a?(ClientStepUpCeremonyTransaction) && token.user_id == actor.id
        raise IdentityTotpCeremonyContract::Error, "TOTP enrollment surface mismatch"
      end

      Client.connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          raise IdentityTotpCeremonyContract::Error, "TOTP enrollment actor unavailable" unless actor.login_allowed?

          if actor.client_totp_credentials.slot_consuming.count >= ClientTotpCredential::MAX_TOTP_SLOTS
            raise ClientTotpCredential::SlotLimitExceeded, "TOTP credential limit is reached"
          end

          AppTicketRecord.connected_to(role: :writing) do
            token.with_lock do
              record = ClientStepUpSession.lock.find_by!(
                user_token_id: token.id, step_up_ceremony_transaction_ref: transaction.transaction_id,
              )
              transaction.with_lock do
                now = ClientStepUpCeremonyTransaction.database_now
                validate_permission!(actor, token, transaction, record, now)
                child = ClientTotpCeremonyTransaction.find_by(
                  step_up_ceremony_transaction_ref: transaction.transaction_id,
                )
                child ? existing_candidate!(child, actor, token, transaction, now) :
                  create_candidate!(actor, token, transaction, now)
              end
            end
          end
        end
      end
    end

    private

    # Bootstrap retains the original protected operation; the child binds TOTP registration.
    # Later authenticator registration requires its own settings scope.
    def enrollment_scope_permitted?(transaction)
      transaction.required_scope == "settings_totp" ||
        (transaction.purpose == "bootstrap" && StepUpScopeCatalog::APP.key?(transaction.required_scope))
    end

    def validate_permission!(actor, token, transaction, record, now)
      unless token.currently_usable?(now) && transaction.actor_ref == actor.public_id &&
          transaction.session_ref == token.public_id &&
          %w(bootstrap credential_registration).include?(transaction.purpose) &&
          enrollment_scope_permitted?(transaction) &&
          transaction.required_aal == "none" && !transaction.phishing_resistant_required &&
          transaction.allowed_methods_array.include?("totp") && transaction.status == "pending" &&
          !transaction.expired?(now: now) && record.status == "PENDING" && record.discard_at > now
        raise IdentityTotpCeremonyContract::Error, "TOTP enrollment permission unavailable"
      end
    end

    def existing_candidate!(child, actor, token, transaction, now)
      candidate = IdentityTotpCeremonyCandidate.find_by!(ref: child.credential_candidate_ref)
      unless child.status == "pending" && child.expires_at > now && child.operation == "registration" &&
          child.actor_ref == actor.public_id && child.session_ref == token.public_id && child.surface == "app" &&
          candidate.step_up_ceremony_transaction_ref == transaction.transaction_id &&
          candidate.surface == "app" && candidate.actor_ref == actor.public_id &&
          candidate.session_ref == token.public_id &&
          candidate.consumed_at.nil? && candidate.expires_at > now
        raise IdentityTotpCeremonyContract::Error, "TOTP enrollment already ended"
      end

      candidate
    end

    def create_candidate!(actor, token, transaction, now)
      secret = ROTP::Base32.random_base32
      candidate = IdentityTotpCeremonyCandidate.create!(
        ref: SecureRandom.uuid, digest: Digest::SHA256.hexdigest(secret), surface: "app",
        actor_ref: actor.public_id, session_ref: token.public_id,
        step_up_ceremony_transaction_ref: transaction.transaction_id,
        private_key: secret, expires_at: [now + 10.minutes, transaction.expires_at].min,
      )
      ClientTotpCeremonyTransaction.create!(
        transaction_id: SecureRandom.uuid, grant_jti: SecureRandom.uuid,
        surface: "app", actor_ref: actor.public_id, session_ref: token.public_id,
        operation: "registration", expires_at: candidate.expires_at,
        credential_candidate_ref: candidate.ref, credential_candidate_digest: candidate.digest,
        step_up_ceremony_transaction_ref: transaction.transaction_id,
      )
      candidate
    end
  end
end
