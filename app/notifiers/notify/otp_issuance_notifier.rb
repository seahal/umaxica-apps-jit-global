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
  # Validate arguments before encryption and retain Noticed's delivery configuration validation.
  module OtpIssuanceNotifier
    public

    def issue(record:, otp_code:, verification_token: nil, public_id: nil, purpose: nil,
              auth_ceremony_session_ref: nil, auth_email_otp_generation: nil,
              sign_up_flow_ref: nil, sign_up_email_transaction_ref: nil, sign_up_email_otp_generation: nil,
              contact_ceremony_transaction_ref: nil, contact_otp_generation: nil,
              email_ceremony_transaction_ref: nil, email_otp_generation: nil)
      raise ArgumentError, "record is required to issue an otp email" if record.nil?

      reentry_binding = EmailReentryOtpDeliveryBindingValue.for(
        purpose: purpose, email_ceremony_transaction_ref: email_ceremony_transaction_ref,
        email_otp_generation: email_otp_generation,
      )

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
      notifier_params.merge!(reentry_binding.to_h) if reentry_binding
      if purpose.to_s == "sign_up" && %w(app com).exclude?(otp_delivery_surface)
        raise ArgumentError, "unsupported Email signup delivery realm"
      end

      signup_binding = EmailSignUpOtpDeliveryBindingValue.for(
        purpose: purpose, sign_up_flow_ref: sign_up_flow_ref,
        sign_up_email_transaction_ref: sign_up_email_transaction_ref,
        sign_up_email_otp_generation: sign_up_email_otp_generation,
      )
      notifier_params.merge!(signup_binding.to_h) if signup_binding
      registration_binding = EmailCredentialRegistrationOtpDeliveryBindingValue.for(
        purpose: purpose,
        contact_ceremony_transaction_ref: contact_ceremony_transaction_ref,
        contact_otp_generation: contact_otp_generation,
      )
      notifier_params.merge!(registration_binding.to_h) if registration_binding
      notifier = with(notifier_params)
      notifier.validate!
      unless notifier.bulk_delivery_methods.empty? && notifier.delivery_methods.keys == [:email]
        raise ArgumentError, "OTP notifier must use exactly one email delivery"
      end

      delivery = notifier.delivery_methods.fetch(:email)
      notification = const_get(:Notification, false).new(recipient: record, event: notifier)
      raise ActiveJob::EnqueueError, "OTP email enqueue rejected" unless delivery.perform?(notification)

      job = delivery.ephemeral_perform_later(name, record, notifier.params, {}, context: notification)
      raise ActiveJob::EnqueueError, "OTP email enqueue rejected" unless job

      notifier
    end

    private

    def encrypted_verification_token(token)
      return if token.blank?

      OutboundSensitivePayload.encrypt_email_verification_token(token)
    end
  end
end
