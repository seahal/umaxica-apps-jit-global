# typed: false
# frozen_string_literal: true

module Notify
  # The entry point every OTP notifier exposes, extended into each surface.
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
    def issue(record:, otp_code:, verification_token: nil, public_id: nil, purpose: nil)
      raise ArgumentError, "record is required to issue an otp email" if record.nil?

      notifier_params = {
        encrypted_hotp_token: OutboundSensitivePayload.encrypt_email_otp(otp_code),
        encrypted_verification_token: encrypted_verification_token(verification_token),
        public_id: public_id,
      }
      notifier_params[:purpose] = purpose.to_s if purpose.present?
      with(notifier_params).deliver(record)
    end

    private

    def encrypted_verification_token(token)
      return if token.blank?

      OutboundSensitivePayload.encrypt_email_verification_token(token)
    end
  end
end
