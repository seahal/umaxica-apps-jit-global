# typed: false
# frozen_string_literal: true

module Notify
  # The entry point every OTP notifier exposes, extended into each surface.
  # Each concrete notifier supplies the fixed otp_delivery_surface contract.
  #
  # The OTP and optional verification token are encrypted here, synchronously, in
  # the caller's process and before `with` is reached. Noticed serializes `params`
  # verbatim into the delivery job, so this is the boundary that keeps plaintext
  # credentials out of the job arguments. The plaintext values stay local and
  # never enter `params`.
  #
  # The arguments are validated explicitly because Noticed::Ephemeral#deliver does
  # not call validate!, which would make a declared `required_params` a silent
  # no-op rather than an error.
  module OtpIssuanceNotifier
    public

    def issue(record:, otp_code:, verification_token: nil, public_id: nil, purpose: nil,
              auth_ceremony_session_ref: nil, auth_email_otp_generation: nil,
              sign_up_flow_ref: nil, sign_up_otp_counter: nil,
              contact_ceremony_transaction_ref: nil, contact_otp_counter: nil)
      raise ArgumentError, "record is required to issue an otp email" if record.nil?

      binding = AuthEmailOtpDeliveryBindingValue.for(
        purpose: purpose, auth_ceremony_session_ref: auth_ceremony_session_ref,
        auth_email_otp_generation: auth_email_otp_generation,
      )

      notifier_params = {
        encrypted_hotp_token: OutboundSensitivePayload.encrypt_email_otp(otp_code),
        encrypted_verification_token: encrypted_verification_token(verification_token),
        public_id: public_id,
      }
      notifier_params[:purpose] = purpose.to_s if purpose.present?
      notifier_params.merge!(binding.to_h) if binding
      if purpose.to_s == "sign_up" || !sign_up_flow_ref.nil? || !sign_up_otp_counter.nil?
        signup_binding = SignUpOtpDeliveryBindingValue.for_email(
          purpose: purpose, surface: otp_delivery_surface,
          sign_up_flow_ref: sign_up_flow_ref, public_id: public_id,
          sign_up_otp_counter: sign_up_otp_counter,
        )
        notifier_params.merge!(signup_binding.email_params) if signup_binding
      end
      registration_binding = ContactRegistrationOtpDeliveryBindingValue.for_email(
        purpose: purpose.to_s, surface: otp_delivery_surface,
        contact_ceremony_transaction_ref: contact_ceremony_transaction_ref,
        public_id: public_id, contact_otp_counter: contact_otp_counter,
      )
      notifier_params.merge!(registration_binding.email_params) if registration_binding
      with(notifier_params).deliver(record)
    end

    private

    def encrypted_verification_token(token)
      return if token.blank?

      OutboundSensitivePayload.encrypt_email_verification_token(token)
    end
  end
end
