# typed: false
# frozen_string_literal: true

module Email::Org
  class OtpMailer < ApplicationMailer
    self.delivery_job = OtpMailDeliveryJob
    default from: "otp@umaxica.org"

    layout "email/application"
    around_deliver :deliver_current_reentry_email_otp
    around_deliver :deliver_current_registration_email_otp

    def create
      @pass_code = OutboundSensitivePayload.decrypt_email_otp(params[:encrypted_hotp_token])
      @verification_token = verification_token_from_params
      @public_id = params[:public_id]
      @verification_url = verification_url

      mail(
        to: params[:email_address],
        subject: I18n.t("mail.email.org.otp_mailer.create.subject"),
      )
    end

    private

    def deliver_current_registration_email_otp
      binding = EmailCredentialRegistrationOtpDeliveryBindingValue.for(
        purpose: params[:purpose], contact_ceremony_transaction_ref: params[:contact_ceremony_transaction_ref],
        contact_otp_generation: params[:contact_otp_generation],
      )
      return yield unless binding

      transaction = OperatorEmailCeremonyTransaction.find_by(transaction_id: binding.contact_ceremony_transaction_ref)
      email = OperatorEmail.includes(:staff).find_by(public_id: params[:public_id])
      delivered = transaction && email && EmailCredentialRegistrationOtpDeliveryGuard.call(
        transaction: transaction, email: email, generation: binding.contact_otp_generation,
        destination: params[:email_address], code: @pass_code,
      ) { yield }
      return if delivered

      Rails.logger.info(
        JitLogEvent.format("email.registration_otp.delivery_refused", surface: "org", reason: "stale_evidence"),
      )
    end

    def deliver_current_reentry_email_otp
      binding = EmailReentryOtpDeliveryBindingValue.for(
        purpose: params[:purpose], email_ceremony_transaction_ref: params[:email_ceremony_transaction_ref],
        email_otp_generation: params[:email_otp_generation],
      )
      return yield unless binding

      transaction = OperatorEmailCeremonyTransaction.find_by(transaction_id: binding.email_ceremony_transaction_ref)
      delivered = deliver_reentry_email_proof(transaction, binding.email_otp_generation) { yield }
      return if delivered

      Rails.logger.info(
        JitLogEvent.format(
          "email.ceremony_otp.delivery_refused", surface: "org",
                                                 reason: "stale_evidence",
        ),
      )
    end

    def deliver_reentry_email_proof(transaction, generation)
      return false unless transaction && transaction.operation == params[:purpose].to_s &&
        transaction.purpose == params[:purpose].to_s

      email = OperatorEmail.includes(:staff).find_by(public_id: params[:public_id])
      return false unless email

      email.with_lock do
        digest = IdentifierBlindIndex.bidx_for_email(params[:email_address], realm: "org")
        next false unless transaction.email_candidate_ref == email.public_id &&
          transaction.actor_ref == email.staff.public_id &&
          transaction.normalized_email_digest == email.address_digest && digest == email.address_digest

        transaction.deliver_email_otp!(generation: generation, code: @pass_code) { yield }
      end
    end

    def verification_token_from_params
      if params.key?(:verification_token) || params.key?("verification_token")
        raise ArgumentError, "plaintext verification tokens are unsupported"
      end
      return if params[:encrypted_verification_token].blank?

      OutboundSensitivePayload.decrypt_email_verification_token(params[:encrypted_verification_token])
    end

    def verification_url
      return if @verification_token.blank? || @public_id.blank?

      Rails.application.routes.url_helpers.base_org_identity_url(
        token: @verification_token,
        host: ENV.fetch("PUBLIC_BASE_STAFF_URL"),
      )
    end
  end
end
