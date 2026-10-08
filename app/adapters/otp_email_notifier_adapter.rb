# typed: false
# frozen_string_literal: true

class OtpEmailNotifierAdapter < OtpAdapter
  def initialize(notifier, surface: nil)
    super()
    @notifier = notifier
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
    notifier_params = {
      record: record,
      otp_code: otp_code,
      verification_token: verification_token,
      public_id: public_id,
    }
    notifier_params[:purpose] = purpose if purpose.present?
    notifier_params.merge!(binding.to_h) if binding
    notifier_params.merge!(signup_binding.to_h) if signup_binding
    notifier_params.merge!(registration_binding.to_h) if registration_binding
    notifier_params.merge!(reentry_binding.to_h) if reentry_binding
    begin
      @notifier.issue(**notifier_params)
    rescue StandardError => e
      record_email_enqueue_failure!(record: record, purpose: purpose, error: e)
      raise
    end

    record_email_enqueue!(record: record, purpose: purpose)
  end
end
