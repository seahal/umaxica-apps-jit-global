# typed: false
# frozen_string_literal: true

module CommonOtpPolicy
  # Authentication OTPs must expire within ten minutes. The same shorter
  # bound is used for signup contact confirmation so SMS confirmation never
  # exceeds its protocol limit.
  AUTHENTICATION_TTL = 10.minutes
  SIGN_UP_CONFIRMATION_TTL = 10.minutes

  SEND_COOLDOWN = 30.seconds
  REREGISTRATION_OVERWRITE_WINDOW = 10.seconds
end
