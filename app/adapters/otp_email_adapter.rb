# typed: false
# frozen_string_literal: true

class OtpEmailAdapter < OtpAdapter
  def initialize(mailer)
    super()
    @mailer = mailer
  end

  def deliver(record:, otp_code:, verification_token: nil, public_id: nil, purpose: nil, **)
    mailer_params = {
      encrypted_hotp_token: OutboundSensitivePayload.encrypt_email_otp(otp_code),
      email_address: record.address,
      encrypted_verification_token: encrypted_verification_token(verification_token),
      public_id: public_id,
    }
    mailer_params[:purpose] = purpose.to_s if purpose.present?

    @mailer.with(mailer_params).create.deliver_later
  end

  private

  def encrypted_verification_token(token)
    return if token.blank?

    OutboundSensitivePayload.encrypt_email_verification_token(token)
  end
end
