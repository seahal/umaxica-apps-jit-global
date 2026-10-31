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
            credentials: ClientTotpCredential.where(user_id: actor.id).where(
              user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
            ), token: code, credential_public_id: credential_public_id,
          )
          verified_at = ClientTotpCredential.database_now if result.accepted?
        end
      end
      return false unless result.accepted?

      Client.connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          credential = ClientTotpCredential.lock.find_by(id: result.credential.id, user_id: actor.id)
          unless actor.login_allowed? && credential&.usable?
            raise IdentityStepUpCeremonyContract::Error, "actor or TOTP unavailable"
          end

          validate_binding!(actor, transaction, session_record) do
            transaction.record_verification!(
              method: "totp", aal: "aal1", phishing_resistant: false, user_verified: false,
              verified_at: verified_at, verified_credential_ref: credential.public_id,
            )
          end
        end
      end
      true
    end

    private

    def validate_device!(actor, token, device)
      return if device.usable? && device.user_id == actor.id && token.device_session_id == device.id &&
        device.current_refresh_token_id == token.id

      raise IdentityStepUpCeremonyContract::Error, "TOTP ceremony device unavailable"
    end

    def validate_locked_ticket!(actor, token, transaction, record)
      now = ClientStepUpCeremonyTransaction.database_now
      unless token.user_id == actor.id && record.user_token_id == token.id &&
          transaction.actor_ref == actor.public_id && transaction.session_ref == token.public_id &&
          record.step_up_ceremony_transaction_ref == transaction.transaction_id &&
          token.active_status?(now) && transaction.purpose == "step_up" &&
          transaction.allowed_methods_array.include?("totp") &&
          transaction.status == "pending" && !transaction.expired?(now: now) &&
          record.status == "PENDING" && record.discard_at > now
        raise IdentityStepUpCeremonyContract::Error, "TOTP ceremony unavailable"
      end
    end

    def validate_binding!(actor, transaction, record)
      token = ClientToken.find(record.user_token_id) if record.is_a?(ClientStepUpSession)
      unless actor.is_a?(Client) && transaction.is_a?(ClientStepUpCeremonyTransaction) &&
          record.is_a?(ClientStepUpSession) && token.user_id == actor.id &&
          transaction.actor_ref == actor.public_id && transaction.session_ref == token.public_id &&
          record.step_up_ceremony_transaction_ref == transaction.transaction_id
        raise IdentityStepUpCeremonyContract::Error, "TOTP ceremony binding mismatch"
      end

      ClientStepUpCeremonyTransaction.connection_owner.connected_to(role: :writing) do
        device = token.device_session_record!
        device.with_lock do
          token.with_lock do
            validate_device!(actor, token, device)

            transaction.with_lock do
              record.with_lock do
                validate_locked_ticket!(actor, token, transaction, record)
                yield if block_given?
              end
            end
          end
        end
      end
    end
  end
end
