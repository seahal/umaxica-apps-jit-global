# frozen_string_literal: true

# APP-only TOTP proof reuses the credential's locked window consumer and permanent failure policy.
# Principal verification commits before ticket evidence; Base rechecks validity before freshness.
class IdentityStepUpTotpVerificationCommitter
  class << self
    public

    def call!(actor:, transaction:, session_record:, code:, credential_public_id: nil)
      validate_binding!(actor, transaction, session_record)
      return false unless code.is_a?(String) && code.match?(/\A[0-9]{6}\z/)
      return false unless credential_public_id.nil? ||
        (credential_public_id.is_a?(String) && credential_public_id.present? && credential_public_id.exclude?("\0"))

      result = nil
      verified_at = nil
      Client.connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          raise IdentityStepUpCeremonyContract::Error, "actor unavailable" unless actor.login_allowed?

          result = TotpWindowConsumer.call(
            credentials: actor.client_totp_credentials.where(
              user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
            ), token: code, credential_public_id: credential_public_id,
          )
          verified_at = ClientTotpCredential.database_now if result.accepted?
        end
      end
      return false unless result.accepted?

      transaction.record_verification!(
        method: "totp", aal: "aal1", phishing_resistant: false,
        verified_at: verified_at, verified_credential_ref: result.credential.public_id,
      )
      true
    end

    private

    def validate_binding!(actor, transaction, record)
      unless actor.is_a?(Client) && transaction.is_a?(ClientStepUpCeremonyTransaction) &&
          record.is_a?(ClientStepUpSession) && record.user_token.user_id == actor.id &&
          transaction.actor_ref == actor.public_id && transaction.session_ref == record.user_token.public_id &&
          record.step_up_ceremony_transaction_ref == transaction.transaction_id
        raise IdentityStepUpCeremonyContract::Error, "TOTP ceremony binding mismatch"
      end

      ClientStepUpCeremonyTransaction.connection_owner.connected_to(role: :writing) do
        record.user_token.with_lock do
          record.with_lock do
            transaction.with_lock do
              now = ClientStepUpCeremonyTransaction.database_now
              unless record.user_token.currently_usable?(now) && transaction.purpose == "step_up" &&
                  transaction.allowed_methods_array.include?("totp") &&
                  transaction.status == "pending" && !transaction.expired?(now: now) &&
                  record.status == "PENDING" && record.discard_at > now
                raise IdentityStepUpCeremonyContract::Error, "TOTP ceremony unavailable"
              end
            end
          end
        end
      end
    end
  end
end
