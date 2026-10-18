# typed: false
# frozen_string_literal: true

class OtpTelephoneAdapter < OtpAdapter
  def initialize(surface: nil)
    super()
    @surface = surface
  end

  def deliver(record:, otp_code:, message_style: :default, purpose: nil, public_id: nil,
              sign_up_flow_ref: nil, sign_up_otp_counter: nil,
              sign_up_telephone_transaction_ref: nil, sign_up_telephone_otp_generation: nil,
              contact_ceremony_transaction_ref: nil, contact_otp_counter: nil, contact_otp_generation: nil)
    unless sign_up_otp_counter.nil? && contact_otp_counter.nil?
      raise ArgumentError, "Telephone delivery requires ceremony generations, not counters"
    end

    if purpose.to_s == "sign_up"
      unless contact_ceremony_transaction_ref.nil? &&
          contact_otp_generation.nil?
        raise ArgumentError, "Telephone signup requires ceremony delivery metadata"
      end

      binding = TelephoneSignUpOtpDeliveryBindingValue.for_sms(
        otp_binding: [@surface.to_s, "sign_up", sign_up_flow_ref,
                      sign_up_telephone_transaction_ref, sign_up_telephone_otp_generation,],
      )
    else
      unless sign_up_flow_ref.nil? && sign_up_telephone_transaction_ref.nil? &&
          sign_up_telephone_otp_generation.nil?
        raise ArgumentError, "Telephone signup delivery purpose mismatch"
      end

      if purpose.to_s == "credential_registration"
        binding = TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms(
          otp_binding: [@surface.to_s, "credential_registration", contact_ceremony_transaction_ref,
                        public_id, contact_otp_generation,],
        )
      else
        unless purpose.nil? && contact_ceremony_transaction_ref.nil? &&
            contact_otp_generation.nil?
          raise ArgumentError, "unsupported Telephone OTP delivery purpose"
        end

        binding = nil
      end
    end
    delivery_params = { to: record.number, title: sms_title, body: sms_body(otp_code, message_style) }
    delivery_params[:otp_binding] = binding.to_a if binding
    delivery_params[:otp_code] = otp_code if binding
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
