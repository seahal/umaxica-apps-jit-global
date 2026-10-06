# frozen_string_literal: true

# Confirmation updates the existing encrypted candidate; credential creation remains a Base step.
class IdentityTotpEnrollmentVerificationCommitter
  MAX_ATTEMPTS = 5

  class << self
    public

    def call!(actor:, token:, transaction:, candidate_ref:, code:, title: nil)
      unless actor.is_a?(Client) && token.is_a?(ClientToken) &&
          transaction.is_a?(ClientStepUpCeremonyTransaction) && token.user_id == actor.id &&
          candidate_ref.is_a?(String) && candidate_ref.present? && candidate_ref.exclude?("\0")
        raise IdentityTotpCeremonyContract::Error, "TOTP enrollment binding mismatch"
      end
      return false unless title.nil? || (title.is_a?(String) && title.length <= 32 && title.exclude?("\0"))

      Client.connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          return false unless actor.login_allowed?

          AppTicketRecord.connected_to(role: :writing) do
            token.with_lock do
              record = ClientStepUpSession.lock.find_by!(
                user_token_id: token.id, step_up_ceremony_transaction_ref: transaction.transaction_id,
              )
              transaction.with_lock do
                child = ClientTotpCeremonyTransaction.lock.find_by!(
                  step_up_ceremony_transaction_ref: transaction.transaction_id, credential_candidate_ref: candidate_ref,
                )
                candidate = IdentityTotpCeremonyCandidate.lock.find_by!(ref: candidate_ref)
                now = ClientStepUpCeremonyTransaction.database_now
                validate_permission!(actor, token, transaction, record, now)
                validate_candidate!(child, candidate, transaction, actor, token, now)
                accepted = valid_code?(candidate.private_key, code, now)
                unless accepted
                  record.update!(attempt_count: record.attempt_count + 1)
                  return false
                end

                candidate.update!(last_otp_at: Time.zone.at(accepted), title: title)
                transaction.record_registration_verification!(method: "totp", verified_at: now)
                true
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
          transaction.session_ref == token.public_id && enrollment_scope_permitted?(transaction) &&
          %w(bootstrap credential_registration).include?(transaction.purpose) &&
          !transaction.step_up_required && !transaction.phishing_resistant_required &&
          !transaction.user_verification_required && !transaction.full_reauthentication_required &&
          transaction.status == "pending" && !transaction.expired?(now: now) &&
          record.status == "PENDING" && record.discard_at > now && record.attempt_count < MAX_ATTEMPTS
        raise IdentityTotpCeremonyContract::Error, "TOTP enrollment unavailable"
      end
    end

    def validate_candidate!(child, candidate, transaction, actor, token, now)
      unless child.status == "pending" && child.expires_at > now && child.operation == "registration" &&
          child.actor_ref == actor.public_id && child.session_ref == token.public_id && child.surface == "app" &&
          candidate.step_up_ceremony_transaction_ref == transaction.transaction_id &&
          candidate.surface == "app" && candidate.actor_ref == actor.public_id &&
          candidate.session_ref == token.public_id &&
          candidate.digest == child.credential_candidate_digest && candidate.expires_at > now &&
          candidate.consumed_at.nil? && candidate.last_otp_at.nil?
        raise IdentityTotpCeremonyContract::Error, "TOTP candidate unavailable"
      end
    end

    def valid_code?(secret, code, now)
      return false unless code.is_a?(String)

      normalized = code.delete(" ")
      return false unless normalized.match?(/\A[0-9]{6}\z/)

      ROTP::TOTP.new(secret).verify(normalized, at: now.to_i)
    end
  end
end
