# typed: false
# frozen_string_literal: true

module Email::App
  class OtpMailer < ApplicationMailer
    default from: "otp@umaxica.app"

    layout "email/application"

    OTP_SUBJECT_KEYS = {
      "sign_up" => "mail.email.app.otp_mailer.create.subjects.sign_up",
      "sign_in" => "mail.email.app.otp_mailer.create.subjects.sign_in",
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

      I18n.t("mail.email.app.otp_mailer.create.subject")
    end

    def verification_url
      return if @verification_token.blank? || @public_id.blank?

      Rails.application.routes.url_helpers.edit_base_app_identity_emails_registration_url(
        token: @verification_token,
        host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
      )
    end
  end
end
