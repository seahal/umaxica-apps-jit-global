# typed: false
# frozen_string_literal: true

module Notify
  module Com
    # Delivers an OTP to a visitor on the com surface.
    # See Notify::App::OtpNotifier for why each surface has its own notifier.
    class OtpNotifier < Notify::ApplicationNotifier
      class << self
        public

        def otp_delivery_surface = "com"
      end

      SIGN_UP_SURFACE = "com"
      extend Notify::OtpIssuanceNotifier

      deliver_by :email, class: "OtpNotifierEmailDeliveryJob" do |config|
        config.mailer = "Email::Com::OtpMailer"
        config.method = :create
        config.params =
          -> {
            delivery_params = {
              encrypted_hotp_token: params[:encrypted_hotp_token],
              email_address: recipient.address,
              encrypted_verification_token: params[:encrypted_verification_token],
              public_id: params[:public_id],
              purpose: params[:purpose],
            }
            binding = AuthEmailOtpDeliveryBindingValue.for(
              purpose: params[:purpose], auth_ceremony_session_ref: params[:auth_ceremony_session_ref],
              auth_email_otp_generation: params[:auth_email_otp_generation],
            )
            delivery_params.merge!(binding.to_h) if binding
            signup_binding = SignUpOtpDeliveryBindingValue.for_email(
              purpose: params[:purpose], surface: SIGN_UP_SURFACE,
              sign_up_flow_ref: params[:sign_up_flow_ref], public_id: params[:public_id],
              sign_up_otp_counter: params[:sign_up_otp_counter],
            )
            delivery_params.merge!(signup_binding.email_params) if signup_binding
            registration_binding = ContactRegistrationOtpDeliveryBindingValue.for_email(
              purpose: params[:purpose].to_s, surface: "com",
              contact_ceremony_transaction_ref: params[:contact_ceremony_transaction_ref],
              public_id: params[:public_id], contact_otp_counter: params[:contact_otp_counter],
            )
            delivery_params.merge!(registration_binding.email_params) if registration_binding
            delivery_params
          }
      end
    end
  end
end
