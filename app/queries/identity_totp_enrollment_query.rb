# frozen_string_literal: true

# Candidate display is read-only and uses the exact admitted registration permission.
class IdentityTotpEnrollmentQuery
  class << self
    public

    def call(actor:, token:, transaction:)
      unless actor.is_a?(Client) && token.is_a?(ClientToken) &&
          transaction.is_a?(ClientStepUpCeremonyTransaction)
        raise IdentityTotpCeremonyContract::Error, "TOTP display surface mismatch"
      end

      Client.connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          OpBaseAppRecord.connected_to(role: :writing) do
            device = token.device_session_record!
            device.with_lock do
              token.with_lock do
                validate_device!(actor, token, device)
                transaction.reload
                now = ClientStepUpCeremonyTransaction.database_now
                validate_permission!(actor, token, transaction, now)
                child = ClientTotpCeremonyTransaction.find_by(
                  step_up_ceremony_transaction_ref: transaction.transaction_id,
                )
                return nil unless child

                candidate = IdentityTotpCeremonyCandidate.find_by!(ref: child.credential_candidate_ref)
                validate_candidate!(child, candidate, actor, token, transaction, now)
                candidate
              end
            end
          end
        end
      end
    end

    private

    def validate_device!(actor, token, device)
      return if device.usable? && device.user_id == actor.id && token.device_session_id == device.id &&
        device.current_refresh_token_id == token.id

      raise IdentityTotpCeremonyContract::Error, "TOTP display device unavailable"
    end

    def validate_permission!(actor, token, transaction, now)
      scope_permitted = transaction.required_scope == "settings_totp" ||
        (transaction.purpose == "bootstrap" && StepUpScopeCatalog::APP.key?(transaction.required_scope))
      unless token.user_id == actor.id && token.active_status?(now) && actor.login_allowed? &&
          transaction.actor_ref == actor.public_id && transaction.session_ref == token.public_id &&
          transaction.surface == "app" && %w(bootstrap credential_registration).include?(transaction.purpose) &&
          transaction.status == "pending" && !transaction.expired?(now: now) && scope_permitted &&
          !transaction.step_up_required && !transaction.phishing_resistant_required &&
          !transaction.user_verification_required && !transaction.full_reauthentication_required &&
          transaction.allowed_methods_array.include?("totp")
        raise IdentityTotpCeremonyContract::Error, "TOTP display permission unavailable"
      end
    end

    def validate_candidate!(child, candidate, actor, token, transaction, now)
      unless child.status == "pending" && child.operation == "registration" && child.expires_at > now &&
          child.actor_ref == actor.public_id && child.surface == "app" && child.session_ref == token.public_id &&
          candidate.step_up_ceremony_transaction_ref == transaction.transaction_id &&
          candidate.actor_ref == child.actor_ref && candidate.session_ref == child.session_ref &&
          candidate.surface == "app" && candidate.digest == child.credential_candidate_digest &&
          candidate.expires_at > now && candidate.consumed_at.nil? && candidate.last_otp_at.nil?
        raise IdentityTotpCeremonyContract::Error, "TOTP candidate unavailable"
      end
    end
  end
end
