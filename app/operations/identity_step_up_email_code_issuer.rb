# frozen_string_literal: true

# Credential-scoped throttling survives resends, new transactions, and browser cookie changes.
# Ticket issuance commits before enqueue; an enqueue failure leaves an unusable generation.
class IdentityStepUpEmailCodeIssuer
  class Unavailable < StandardError; end
  RESEND_INTERVAL = 60.seconds

  class << self
    public

    def call!(actor:, credential:, transaction:, session_record:)
      token, notifier = binding_for(actor, credential, transaction, session_record)
      code = format("%06d", SecureRandom.random_number(1_000_000))
      generation = nil
      actor.class.connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          credential.with_lock do
            raise Unavailable,
                  "email credential unavailable" unless actor.login_allowed? && credential_valid?(credential)

            transaction.class.connection_owner.connected_to(role: :writing) do
              device = token.device_session_record!
              device.with_lock do
                token.with_lock do
                  now = transaction.class.database_now
                  validate_issuance!(actor, credential, transaction, session_record, token, device, now)

                  generation = session_record.issue_bound_email_code!(
                    transaction: transaction, credential_ref: credential.public_id, code: code,
                  )
                  credential.update!(step_up_otp_last_issued_at: now)
                end
              end
            end
          end
        end
      end
      begin
        notifier.issue(
          record: credential, otp_code: code, transaction_ref: transaction.transaction_id,
          generation: generation,
        )
      rescue ActiveJob::EnqueueError, ActiveRecord::ActiveRecordError
        session_record.mark_bound_email_delivery!(transaction: transaction, generation: generation, success: false)
        raise Unavailable, "email enqueue unavailable"
      end
      generation
    end

    private

    def validate_issuance!(actor, credential, transaction, record, token, device, now)
      return if device.usable? && device.user_id == actor.id && token.device_session_id == device.id &&
        device.current_refresh_token_id == token.id && token.user_id == actor.id &&
        token.active_status?(now) && token.public_id == transaction.session_ref &&
        transaction.actor_ref == actor.public_id && record.user_token_id == token.id &&
        (!credential.step_up_otp_locked_until || credential.step_up_otp_locked_until <= now) &&
        (!credential.step_up_otp_last_issued_at || credential.step_up_otp_last_issued_at + RESEND_INTERVAL <= now)

      raise Unavailable, "email issuance unavailable"
    end

    def binding_for(actor, credential, transaction, record)
      case actor
      when Client
        unless credential.is_a?(ClientEmail) && credential.user_id == actor.id &&
            transaction.is_a?(ClientStepUpCeremonyTransaction) && record.is_a?(ClientStepUpSession) &&
            ClientToken.find(record.user_token_id).user_id == actor.id
          raise Unavailable, "email ceremony binding mismatch"
        end

        [ClientToken.find(record.user_token_id), Notify::App::StepUpOtpNotifier]
      else
        raise Unavailable, "email step-up unsupported"
      end
    end

    def credential_valid?(credential)
      case credential
      when ClientEmail
        credential.class.effective_binding.where(
          id: credential.id, user_email_status_id: [ClientEmailStatus::VERIFIED, ClientEmailStatus::VERIFIED_WITH_SIGN_UP],
        ).where("discard_at > clock_timestamp()").exists?
      end
    end
  end
end
