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

      AppTicketRecord.connected_to(role: :writing) do
        transaction.reload
        token.reload
        child = ClientTotpCeremonyTransaction.find_by(step_up_ceremony_transaction_ref: transaction.transaction_id)
        candidate = IdentityTotpCeremonyCandidate.find_by!(ref: child.credential_candidate_ref) if child
        now = ClientStepUpCeremonyTransaction.database_now
        validate_permission!(actor, token, transaction, now)
        return nil unless child

        validate_candidate!(child, candidate, actor, token, transaction, now)
        candidate
      end
    end

    private

    def validate_permission!(actor, token, transaction, now)
      scope_permitted = transaction.required_scope == "settings_totp" ||
        (transaction.purpose == "bootstrap" && StepUpScopeCatalog::APP.key?(transaction.required_scope))
      unless token.user_id == actor.id && token.currently_usable?(now) && actor.login_allowed? &&
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
