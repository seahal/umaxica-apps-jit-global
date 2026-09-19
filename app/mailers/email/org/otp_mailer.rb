# typed: false
# frozen_string_literal: true

module Email::Org
  class OtpMailer < ApplicationMailer
    default from: "otp@umaxica.org"

    layout "email/application"

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

    def verification_token_from_params
      # Read-only compatibility for jobs/direct calls created before the encrypted
      # parameter was introduced. New producers always use the encrypted field.
      return params[:verification_token] if params[:encrypted_verification_token].blank?

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
