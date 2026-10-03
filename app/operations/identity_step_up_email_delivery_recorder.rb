# frozen_string_literal: true

# The job is an encrypted transport, never authentication authority. Eligibility is checked on
# writers before SMTP; a concurrent cancellation may stop authentication even after mail is sent.
class IdentityStepUpEmailDeliveryRecorder
  class << self
    public

    def call!(credential:, transaction_ref:, generation:, encrypted_code:)
      actor, transaction_model, session_model, token_key, mailer = binding_for(credential)
      unless transaction_ref.is_a?(String) && transaction_ref.present? &&
          generation.is_a?(Integer) && generation.positive?
        raise ArgumentError, "invalid step-up email delivery reference"
      end

      transaction = nil
      session_record = nil
      eligible =
        actor.class.connection_class_for_self.connected_to(role: :writing) do
          actor.with_lock do
            credential.with_lock do
              next false unless actor.login_allowed? && credential_valid?(credential)

              transaction_model.connection_owner.connected_to(role: :writing) do
                transaction = transaction_model.find_by(transaction_id: transaction_ref)
                next false unless transaction && transaction.actor_ref == actor.public_id

                session_record = session_model.find_by(step_up_ceremony_transaction_ref: transaction_ref)
                next false unless session_record

                token = (token_key == :user_token) ? session_record.user_token : session_record.visitor_token
                token.with_lock do
                  session_record.with_lock do
                    transaction.with_lock do
                      now = transaction_model.database_now
                      next false unless delivery_pending?(
                        transaction, session_record, token, actor, credential,
                        generation, now,
                      )

                      payload_matches?(transaction, credential, session_record, generation, encrypted_code)
                    end
                  end
                end
              end
            end
          end
        end
      return false unless eligible

      # SMTP runs outside database locks. The terminal transaction and generation are checked
      # again when recording delivery, so a late job cannot revive canceled or replaced proof.
      delivered = deliver_mail!(mailer, credential, encrypted_code)
      session_record.mark_bound_email_delivery!(
        transaction: transaction, generation: generation, success: delivered,
      ) && delivered
    rescue Net::SMTPError, IOError, Timeout::Error, SocketError
      session_record&.mark_bound_email_delivery!(transaction: transaction, generation: generation, success: false)
      false
    end

    private

    def payload_matches?(transaction, credential, record, generation, encrypted_code)
      code = OutboundSensitivePayload.decrypt_email_otp(encrypted_code)
      digest = StepUpEmailCodeDigest.for(
        transaction: transaction, credential_ref: credential.public_id, generation: generation, code: code,
      )
      ActiveSupport::SecurityUtils.secure_compare(record.email_code_digest, digest)
    end

    def deliver_mail!(mailer, credential, encrypted_code)
      message = mailer.with(
        encrypted_hotp_token: encrypted_code, encrypted_verification_token: nil,
        public_id: nil, purpose: "step_up", email_address: credential.address,
      ).create
      message.message.raise_delivery_errors = true
      message.deliver_now.perform_deliveries
    end

    def binding_for(credential)
      case credential
      when ClientEmail
        [credential.user, ClientStepUpCeremonyTransaction, ClientStepUpSession, :user_token, Email::App::OtpMailer]
      when VisitorEmail
        [credential.visitor, VisitorStepUpCeremonyTransaction, VisitorStepUpSession, :visitor_token, Email::Com::OtpMailer]
      else
        raise ArgumentError, "step-up email surface unsupported"
      end
    end

    def credential_valid?(credential)
      statuses =
        case credential
        when ClientEmail then [ClientEmailStatus::VERIFIED, ClientEmailStatus::VERIFIED_WITH_SIGN_UP]
        when VisitorEmail then [VisitorEmailStatus::VERIFIED, VisitorEmailStatus::VERIFIED_WITH_SIGN_UP]
        end
      status_key = credential.is_a?(ClientEmail) ? :user_email_status_id : :visitor_email_status_id
      credential.class.where(
        :id => credential.id,
        status_key => statuses,
      ).where("discard_at > clock_timestamp()").exists?
    end

    def delivery_pending?(transaction, record, token, actor, credential, generation, now)
      owned = token.is_a?(ClientToken) ? token.user_id == actor.id : token.visitor_id == actor.id
      owned && token.currently_usable? && token.public_id == transaction.session_ref &&
        transaction.purpose == "step_up" && transaction.status == "pending" && !transaction.expired?(now: now) &&
        transaction.allowed_methods_array.include?("email_otp") &&
        record.status == "PENDING" && record.discard_at > now &&
        record.email_credential_ref == credential.public_id && record.email_code_generation == generation &&
        record.email_code_consumed_at.nil? && record.email_delivery_state == "pending" &&
        record.email_code_expires_at && record.email_code_expires_at > now
    end
  end
end
