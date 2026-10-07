# typed: false
# frozen_string_literal: true

module CommonOtpPolicy
  # Every out-of-band OTP secret has one finite upper bound. Purpose-specific
  # names remain separate so callers cannot accidentally use a confirmation
  # policy for authentication, or vice versa.
  MAX_OOB_TTL = 10.minutes
  AUTHENTICATION_TTL = MAX_OOB_TTL
  SIGN_UP_CONFIRMATION_TTL = MAX_OOB_TTL

  # Covers the full real/dummy email operation, not just the indexed lookup.
  # The isolated HTTP measurement showed distinct receipt, resend and refusal distributions.
  EMAIL_AUTH_RESPONSE_MINIMUM_SECONDS = 0.1

  SEND_COOLDOWN = 30.seconds
  REREGISTRATION_OVERWRITE_WINDOW = 10.seconds
end
