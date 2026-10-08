# typed: false
# frozen_string_literal: true

module Notify
  module Org
    # Delivers an OTP to a staff member on the org surface.
    # See Notify::App::OtpNotifier for why each surface has its own notifier.
    class OtpNotifier < Notify::ApplicationNotifier
      class << self
        public

        def otp_delivery_surface = "org"
      end

      extend Notify::OtpIssuanceNotifier

      deliver_by :email, class: "OtpNotifierEmailDeliveryJob" do |config|
        config.mailer = "Email::Org::OtpMailer"
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
            reentry_binding = EmailReentryOtpDeliveryBindingValue.for(
              purpose: params[:purpose], email_ceremony_transaction_ref: params[:email_ceremony_transaction_ref],
              email_otp_generation: params[:email_otp_generation],
            )
            delivery_params.merge!(reentry_binding.to_h) if reentry_binding
            registration_binding = EmailCredentialRegistrationOtpDeliveryBindingValue.for(
              purpose: params[:purpose],
              contact_ceremony_transaction_ref: params[:contact_ceremony_transaction_ref],
              contact_otp_generation: params[:contact_otp_generation],
            )
            delivery_params.merge!(registration_binding.to_h) if registration_binding
            delivery_params
          }
      end
    end
  end
end
