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
      extend Notify::OtpIssuanceNotifier

      # `enqueue` is deliberately left unset so the mail is delivered inside this
      # Noticed job rather than enqueuing a second ActionMailer job.
      #
      # `params` is spelled out because Email::App::OtpMailer#create expects
      # `email_address`, which is not a notifier param. The proc runs on the
      # Notification at perform time, so the address is read from the recipient
      # then and never reaches the job arguments.
      deliver_by :email do |config|
        config.mailer = "Email::App::OtpMailer"
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
