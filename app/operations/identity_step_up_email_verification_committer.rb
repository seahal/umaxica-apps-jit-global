# frozen_string_literal: true

# Failed attempts commit on the credential before returning rejection. Resends never reset
# this counter; only successful authentication does. Base owns the eventual freshness commit.
class IdentityStepUpEmailVerificationCommitter
  MAX_FAILURES = OtpLockable::MAX_OTP_ATTEMPTS
  LOCKOUT_DURATION = OtpLockable::OTP_LOCKOUT_DURATION

  class << self
    public

    def call!(actor:, credential:, transaction:, session_record:, code:)
      token = bound_token(actor, credential, transaction, session_record)
      return false unless token

      actor.class.connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          credential.with_lock do
            return false unless actor.login_allowed? && credential_valid?(credential)

            transaction.class.connection_owner.connected_to(role: :writing) do
              token.with_lock do
                session_record.with_lock do
                  transaction.with_lock do
                    now = transaction.class.database_now
                    return false unless verification_pending?(
                      actor, token, credential, transaction, session_record,
                      now,
                    )

                    if session_record.consume_bound_email_code!(
                      transaction: transaction, credential_ref: credential.public_id, code: code,
                    )
                      credential.update!(step_up_otp_failures: 0, step_up_otp_locked_until: nil)
                      true
                    else
                      failures = credential.step_up_otp_failures + 1
                      credential.update!(
                        step_up_otp_failures: failures,
                        step_up_otp_locked_until: (failures >= MAX_FAILURES) ? now + LOCKOUT_DURATION : nil,
                      )
                      false
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    private

    def bound_token(actor, credential, transaction, record)
      case actor
      when Client
        return unless credential.is_a?(ClientEmail) && credential.user_id == actor.id &&
          transaction.is_a?(ClientStepUpCeremonyTransaction) && record.is_a?(ClientStepUpSession) &&
          record.user_token.user_id == actor.id

        record.user_token
      when Visitor
        return unless credential.is_a?(VisitorEmail) && credential.visitor_id == actor.id &&
          transaction.is_a?(VisitorStepUpCeremonyTransaction) && record.is_a?(VisitorStepUpSession) &&
          record.visitor_token.visitor_id == actor.id

        record.visitor_token
      end
    end

    def credential_valid?(credential)
      case credential
      when ClientEmail
        credential.class.effective_binding.where(
          id: credential.id, user_email_status_id: [ClientEmailStatus::VERIFIED, ClientEmailStatus::VERIFIED_WITH_SIGN_UP],
        ).where("discard_at > clock_timestamp()").exists?
      when VisitorEmail
        credential.class.effective_binding.where(
          id: credential.id, visitor_email_status_id: [VisitorEmailStatus::VERIFIED, VisitorEmailStatus::VERIFIED_WITH_SIGN_UP],
        ).where("discard_at > clock_timestamp()").exists?
      end
    end

    def verification_pending?(actor, token, credential, transaction, record, now)
      token.currently_usable? && token.public_id == transaction.session_ref &&
        transaction.actor_ref == actor.public_id &&
        transaction.purpose == "step_up" && transaction.status == "pending" && !transaction.expired?(now: now) &&
        transaction.allowed_methods_array.include?("email_otp") &&
        record.step_up_ceremony_transaction_ref == transaction.transaction_id && record.status == "PENDING" &&
        record.discard_at > now && record.email_credential_ref == credential.public_id &&
        record.email_delivery_state == "delivered" && record.email_code_consumed_at.nil? &&
        record.email_code_expires_at && record.email_code_expires_at > now &&
        (!credential.step_up_otp_locked_until || credential.step_up_otp_locked_until <= now)
    end
  end
end
