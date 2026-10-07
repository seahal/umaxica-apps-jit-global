# typed: false
# frozen_string_literal: true

module Email::Com
  class OtpMailer < ApplicationMailer
    self.delivery_job = OtpMailDeliveryJob
    default from: "otp@umaxica.com"

    layout "email/application"

    around_deliver :deliver_current_auth_email_otp

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

    def deliver_current_auth_email_otp
      binding = AuthEmailOtpDeliveryBindingValue.for(
        purpose: params[:purpose], auth_ceremony_session_ref: params[:auth_ceremony_session_ref],
        auth_email_otp_generation: params[:auth_email_otp_generation],
      )
      registration_binding = ContactRegistrationOtpDeliveryBindingValue.for_email(
        purpose: params[:purpose].to_s, surface: "com",
        contact_ceremony_transaction_ref: params[:contact_ceremony_transaction_ref],
        public_id: params[:public_id], contact_otp_counter: params[:contact_otp_counter],
      )
      if registration_binding
        return deliver_current_registration_email_otp(registration_binding) { yield }
      end

      if binding.nil?
        signup_binding = SignUpOtpDeliveryBindingValue.for_email(
          purpose: params[:purpose], surface: "com", sign_up_flow_ref: params[:sign_up_flow_ref],
          public_id: params[:public_id], sign_up_otp_counter: params[:sign_up_otp_counter],
        )
        return yield unless signup_binding

        flow = VisitorSignUpFlow.find_by(public_id: signup_binding.flow_ref)
        return unless flow

        return SignUpOtpDeliveryGuard.call(
          flow: flow, channel: :email, contact_ref: signup_binding.contact_ref,
          counter: signup_binding.counter, destination: params[:email_address], code: @pass_code,
        ) { yield }
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
      transaction = VisitorEmailCeremonyTransaction.find_by(transaction_id: binding.flow_ref)
      return unless transaction

      ContactRegistrationOtpDeliveryIssuer.call(
        transaction: transaction, contact_ref: binding.contact_ref, counter: binding.counter,
        destination: params[:email_address], code: @pass_code,
      ) { yield }
    end

    def verification_token_from_params
      # Read-only compatibility for jobs/direct calls created before the encrypted
      # parameter was introduced. New producers always use the encrypted field.
      return params[:verification_token] if params[:encrypted_verification_token].blank?

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
