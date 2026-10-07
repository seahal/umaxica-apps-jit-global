# typed: false
# frozen_string_literal: true

class OtpTelephoneAdapter < OtpAdapter
  def initialize(surface: nil)
    super()
    @surface = surface
  end

  def deliver(record:, otp_code:, message_style: :default, purpose: nil, public_id: nil,
              sign_up_flow_ref: nil, sign_up_otp_counter: nil,
              contact_ceremony_transaction_ref: nil, contact_otp_counter: nil, **)
    binding = SignUpOtpDeliveryBindingValue.for_email(
      purpose: purpose, surface: @surface, sign_up_flow_ref: sign_up_flow_ref,
      public_id: public_id, sign_up_otp_counter: sign_up_otp_counter,
    )
    registration_binding = ContactRegistrationOtpDeliveryBindingValue.for_email(
      purpose: purpose.to_s, surface: @surface.to_s,
      contact_ceremony_transaction_ref: contact_ceremony_transaction_ref,
      public_id: public_id, contact_otp_counter: contact_otp_counter,
    )
    delivery_params = { to: record.number, title: sms_title, body: sms_body(otp_code, message_style) }
    delivery_params[:otp_binding] = binding.to_a if binding
    delivery_params[:otp_binding] = registration_binding.to_a if registration_binding
    OutboundSms.deliver_later(
      **delivery_params,
    )
  end

  private

  # The title never carries the OTP code. Amazon SNS ignores `subject` for direct
  # phone-number publishes, so a code here would never reach the recipient while
  # still being persisted as a plaintext Solid Queue job argument.
  def sms_title
    "Verification code"
  end

  def sms_body(otp_code, message_style)
    return localized_verification_message(otp_code) if message_style.to_sym == :localized_verification

    "Your verification code: #{otp_code}"
  end

  def localized_verification_message(otp_code)
    I18n.t("sign.telephone_verification.sms_message", code: otp_code)
  end
end
