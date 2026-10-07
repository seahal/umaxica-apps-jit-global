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
              sign_up_flow_ref: nil, sign_up_otp_counter: nil,
              contact_ceremony_transaction_ref: nil, contact_otp_counter: nil, **)
    binding = AuthEmailOtpDeliveryBindingValue.for(
      purpose: purpose, auth_ceremony_session_ref: auth_ceremony_session_ref,
      auth_email_otp_generation: auth_email_otp_generation,
    )
    signup_binding = SignUpOtpDeliveryBindingValue.for_email(
      purpose: purpose, surface: @surface, sign_up_flow_ref: sign_up_flow_ref,
      public_id: public_id, sign_up_otp_counter: sign_up_otp_counter,
    )
    registration_binding = ContactRegistrationOtpDeliveryBindingValue.for_email(
      purpose: purpose.to_s, surface: @surface.to_s,
      contact_ceremony_transaction_ref: contact_ceremony_transaction_ref,
      public_id: public_id, contact_otp_counter: contact_otp_counter,
    )
    mailer_params = {
      encrypted_hotp_token: OutboundSensitivePayload.encrypt_email_otp(otp_code),
      email_address: record.address,
      encrypted_verification_token: encrypted_verification_token(verification_token),
      public_id: public_id,
    }
    mailer_params[:purpose] = purpose.to_s if purpose.present?
    mailer_params.merge!(binding.to_h) if binding
    mailer_params.merge!(signup_binding.email_params) if signup_binding
    mailer_params.merge!(registration_binding.email_params) if registration_binding

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
