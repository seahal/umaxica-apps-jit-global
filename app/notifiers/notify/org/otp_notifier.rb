# typed: false
# frozen_string_literal: true

module Notify
  module Org
    # Delivers an OTP to a staff member on the org surface.
    # See Notify::App::OtpNotifier for why each surface has its own notifier.
    class OtpNotifier < Notify::ApplicationNotifier
      extend Notify::OtpIssuanceNotifier

      deliver_by :email do |config|
        config.mailer = "Email::Org::OtpMailer"
        config.method = :create
        config.params =
          -> {
            {
              encrypted_hotp_token: params[:encrypted_hotp_token],
              email_address: recipient.address,
              encrypted_verification_token: params[:encrypted_verification_token],
              public_id: params[:public_id],
              purpose: params[:purpose],
            }
          }
      end
    end
  end
end
