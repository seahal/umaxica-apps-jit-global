# typed: false
# frozen_string_literal: true

module Email::Com
  class OtpMailer < ApplicationMailer
    self.delivery_job = OtpMailDeliveryJob
    default from: "otp@umaxica.com"

    layout "email/application"

    around_deliver :deliver_current_auth_email_otp
    around_deliver :deliver_current_reentry_email_otp

    OTP_SUBJECT_KEYS = {
      "sign_up" => "mail.email.com.otp_mailer.create.subjects.sign_up",
      "sign_in" => "mail.email.com.otp_mailer.create.subjects.sign_in",
    }.freeze

    def create
      @pass_code = OutboundSensitivePayload.decrypt_email_otp(params[:encrypted_hotp_token])
      @verification_token = verification_token_from_params
      @public_id = params[:public_id]
      @verification_url = verification_url

      mail(
        to: params[:email_address],
        subject: otp_subject,
      )
    end

    private

    def deliver_current_reentry_email_otp
      binding = EmailReentryOtpDeliveryBindingValue.for(
        purpose: params[:purpose], email_ceremony_transaction_ref: params[:email_ceremony_transaction_ref],
        email_otp_generation: params[:email_otp_generation],
      )
      return yield unless binding

      transaction = VisitorEmailCeremonyTransaction.find_by(transaction_id: binding.email_ceremony_transaction_ref)
      delivered = deliver_reentry_email_proof(transaction, binding.email_otp_generation) { yield }
      return if delivered

      Rails.logger.info(
        JitLogEvent.format(
          "email.ceremony_otp.delivery_refused", surface: "com",
                                                 reason: "stale_evidence",
        ),
      )
    end

    def deliver_reentry_email_proof(transaction, generation)
      return false unless transaction && transaction.operation == params[:purpose].to_s &&
        transaction.purpose == params[:purpose].to_s

      email = VisitorEmail.find_by(public_id: params[:public_id])
      return false unless email

      email.with_lock do
        digest = IdentifierBlindIndex.bidx_for_email(params[:email_address], realm: "com")
        next false unless transaction.email_candidate_ref == email.public_id &&
          transaction.actor_ref == email.visitor.public_id &&
          transaction.normalized_email_digest == email.address_digest && digest == email.address_digest

        transaction.deliver_email_otp!(generation: generation, code: @pass_code) { yield }
      end
    end

    def deliver_current_auth_email_otp
      binding = AuthEmailOtpDeliveryBindingValue.for(
        purpose: params[:purpose], auth_ceremony_session_ref: params[:auth_ceremony_session_ref],
        auth_email_otp_generation: params[:auth_email_otp_generation],
      )
      registration_binding = EmailCredentialRegistrationOtpDeliveryBindingValue.for(
        purpose: params[:purpose],
        contact_ceremony_transaction_ref: params[:contact_ceremony_transaction_ref],
        contact_otp_generation: params[:contact_otp_generation],
      )
      if registration_binding
        return deliver_current_registration_email_otp(registration_binding) { yield }
      end

      if binding.nil?
        signup_binding = EmailSignUpOtpDeliveryBindingValue.for(
          purpose: params[:purpose], sign_up_flow_ref: params[:sign_up_flow_ref],
          sign_up_email_transaction_ref: params[:sign_up_email_transaction_ref],
          sign_up_email_otp_generation: params[:sign_up_email_otp_generation],
        )
        return yield unless signup_binding

        return deliver_current_signup_email_otp(signup_binding) { yield }
      end

      ceremony = VisitorAuthCeremonySession.find_by(id: binding.auth_ceremony_session_ref)
      delivered =
        ceremony&.with_email_otp_delivery!(
          generation: binding.auth_email_otp_generation, code: @pass_code, destination: params[:email_address],
        ) { yield }
      return if delivered

      # Operational rejection only; this log is not the authoritative security audit.
      Rails.logger.info(
        JitLogEvent.format(
          "auth.email_otp.delivery_refused", surface: "com", reason: "stale_evidence",
                                             event_uuid: SecureRandom.uuid,
        ),
      )
    end

    def deliver_current_registration_email_otp(binding)
      transaction = VisitorEmailCeremonyTransaction.find_by(transaction_id: binding.contact_ceremony_transaction_ref)
      email = VisitorEmail.find_by(public_id: params[:public_id])
      return unless transaction && email

      EmailCredentialRegistrationOtpDeliveryGuard.call(
        transaction: transaction, email: email, generation: binding.contact_otp_generation,
        destination: params[:email_address], code: @pass_code,
      ) { yield }
    end

    def deliver_current_signup_email_otp(binding)
      flow = VisitorSignUpFlow.find_by(public_id: binding.sign_up_flow_ref)
      email = VisitorEmail.find_by(public_id: params[:public_id])
      transaction = VisitorEmailCeremonyTransaction.find_by(transaction_id: binding.sign_up_email_transaction_ref)
      delivered =
        if flow && email && transaction
          EmailSignUpOtpDeliveryGuard.call(
            flow: flow, email: email, transaction: transaction, generation: binding.sign_up_email_otp_generation,
            destination: params[:email_address], code: @pass_code,
          ) { yield }
        end
      return if delivered

      Rails.logger.info(
        JitLogEvent.format("email.signup_otp.delivery_refused", surface: "com", reason: "stale_evidence"),
      )
    end

    def verification_token_from_params
      if params.key?(:verification_token) || params.key?("verification_token")
        raise ArgumentError, "plaintext verification tokens are unsupported"
      end
      return if params[:encrypted_verification_token].blank?

      OutboundSensitivePayload.decrypt_email_verification_token(params[:encrypted_verification_token])
    end

    def otp_subject
      purpose = params[:purpose].to_s
      subject_key = OTP_SUBJECT_KEYS[purpose]
      return I18n.t(subject_key) if subject_key

      I18n.t("mail.email.com.otp_mailer.create.subject")
    end

    def verification_url
      return if @verification_token.blank? || @public_id.blank?

      Rails.application.routes.url_helpers.base_com_identity_url(
        token: @verification_token,
        host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL"),
      )
    end
  end
end
