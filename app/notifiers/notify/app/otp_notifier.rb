# typed: false
# frozen_string_literal: true

module Notify
  module App
    # Delivers an OTP to an end user on the app surface.
    #
    # One notifier per surface rather than one taking `surface:` as a param: a
    # parameterized notifier would carry the trust boundary as a string through
    # ActiveJob, turning a surface mix-up into a runtime data bug on a job payload
    # instead of a load-time constant error. OtpAdapter.for spells out every
    # surface for the same reason.
    class OtpNotifier < Notify::ApplicationNotifier
      class << self
        public

        def otp_delivery_surface = "app"
      end

      SIGN_UP_SURFACE = "app"
      extend Notify::OtpIssuanceNotifier

      # `enqueue` is deliberately left unset so the mail is delivered inside this
      # Noticed job rather than enqueuing a second ActionMailer job.
      #
      # `params` is spelled out because Email::App::OtpMailer#create expects
      # `email_address`, which is not a notifier param. The proc runs on the
      # Notification at perform time, so the address is read from the recipient
      # then and never reaches the job arguments.
      deliver_by :email, class: "OtpNotifierEmailDeliveryJob" do |config|
        config.mailer = "Email::App::OtpMailer"
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
            reentry_binding = EmailReentryOtpDeliveryBindingValue.for(
              purpose: params[:purpose], email_ceremony_transaction_ref: params[:email_ceremony_transaction_ref],
              email_otp_generation: params[:email_otp_generation],
            )
            delivery_params.merge!(reentry_binding.to_h) if reentry_binding
            signup_binding = EmailSignUpOtpDeliveryBindingValue.for(
              purpose: params[:purpose], sign_up_flow_ref: params[:sign_up_flow_ref],
              sign_up_email_transaction_ref: params[:sign_up_email_transaction_ref],
              sign_up_email_otp_generation: params[:sign_up_email_otp_generation],
            )
            delivery_params.merge!(signup_binding.to_h) if signup_binding
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
