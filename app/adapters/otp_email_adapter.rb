# typed: false
# frozen_string_literal: true

class OtpEmailAdapter < OtpAdapter
  def initialize(mailer, surface: nil)
    super()
    @mailer = mailer
    @surface = surface
  end

  def deliver(record:, otp_code:, verification_token: nil, public_id: nil, purpose: nil,
              auth_ceremony_session_ref: nil, auth_email_otp_generation: nil,
              sign_up_flow_ref: nil, sign_up_email_transaction_ref: nil, sign_up_email_otp_generation: nil,
              contact_ceremony_transaction_ref: nil, contact_otp_generation: nil,
              email_ceremony_transaction_ref: nil, email_otp_generation: nil)
    binding = AuthEmailOtpDeliveryBindingValue.for(
      purpose: purpose, auth_ceremony_session_ref: auth_ceremony_session_ref,
      auth_email_otp_generation: auth_email_otp_generation,
    )
    signup_binding = EmailSignUpOtpDeliveryBindingValue.for(
      purpose: purpose, sign_up_flow_ref: sign_up_flow_ref,
      sign_up_email_transaction_ref: sign_up_email_transaction_ref,
      sign_up_email_otp_generation: sign_up_email_otp_generation,
    )
    registration_binding = EmailCredentialRegistrationOtpDeliveryBindingValue.for(
      purpose: purpose,
      contact_ceremony_transaction_ref: contact_ceremony_transaction_ref,
      contact_otp_generation: contact_otp_generation,
    )
    reentry_binding = EmailReentryOtpDeliveryBindingValue.for(
      purpose: purpose, email_ceremony_transaction_ref: email_ceremony_transaction_ref,
      email_otp_generation: email_otp_generation,
    )
    mailer_params = {
      encrypted_hotp_token: OutboundSensitivePayload.encrypt_email_otp(otp_code),
      email_address: record.address,
      encrypted_verification_token: encrypted_verification_token(verification_token),
      public_id: public_id,
    }
    mailer_params[:purpose] = purpose.to_s if purpose.present?
    mailer_params.merge!(binding.to_h) if binding
    mailer_params.merge!(signup_binding.to_h) if signup_binding
    mailer_params.merge!(registration_binding.to_h) if registration_binding
    mailer_params.merge!(reentry_binding.to_h) if reentry_binding

    begin
      @mailer.with(mailer_params).create.deliver_later
    rescue StandardError => e
      record_email_enqueue_failure!(record: record, purpose: purpose, error: e)
      raise
    end

    record_email_enqueue!(record: record, purpose: purpose)
  end

  private

  def encrypted_verification_token(token)
    return if token.blank?

    OutboundSensitivePayload.encrypt_email_verification_token(token)
  end
end
