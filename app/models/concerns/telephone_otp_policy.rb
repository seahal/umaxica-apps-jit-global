# frozen_string_literal: true

module TelephoneOtpPolicy
  extend ActiveSupport::Concern

  MAX_OTP_ATTEMPTS = 5
  OTP_ATTEMPT_WINDOW = 15.minutes
  OTP_LOCKOUT_DURATION = 15.minutes
  OTP_UNLOCKED_SENTINEL = -Float::INFINITY
  MAX_OOB_TTL = 10.minutes
  AUTHENTICATION_TTL = MAX_OOB_TTL
  SIGN_UP_CONFIRMATION_TTL = MAX_OOB_TTL
  SEND_COOLDOWN = 30.seconds
  REREGISTRATION_OVERWRITE_WINDOW = 10.seconds

  public

  def locked?(now: nil)
    decision_time = now || self.class.database_now
    lockout_active?(now: decision_time) || attempts_locked_without_expiry?(now: decision_time)
  end

  def lockout_active?(now: nil)
    expiry = lockout_expires_at
    return false if expiry.blank?

    expiry > (now || self.class.database_now)
  end

  def lockout_expires_at
    return nil if locked_at.blank? || locked_at == -Float::INFINITY || locked_at == Float::INFINITY

    locked_at
  end

  def reregistration_window_active?(now: nil)
    anchor = otp_window_anchor
    return false if anchor.blank? || anchor == -Float::INFINITY

    anchor > (now || self.class.database_now) - REREGISTRATION_OVERWRITE_WINDOW
  end

  def increment_attempts!
    operation =
      lambda do
        with_lock do
          decision_time = self.class.database_now
          next if lockout_active?(now: decision_time)

          self.otp_attempts_count = otp_attempts_count.to_i + 1
          self.locked_at = decision_time + OTP_LOCKOUT_DURATION if otp_attempts_count >= MAX_OTP_ATTEMPTS
          save!(validate: false)
        end
        reload
      end

    defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
  end

  private

  def initialize_telephone_otp_state
    self.otp_attempts_count ||= 0
  end

  def attempt_window_active?(now: nil)
    anchor = otp_window_anchor
    return false if anchor.blank? || anchor == -Float::INFINITY

    anchor > (now || self.class.database_now) - OTP_ATTEMPT_WINDOW
  end

  def attempts_locked_without_expiry?(now: nil)
    lockout_expires_at.blank? && attempt_window_active?(now: now) &&
      otp_attempts_count.to_i >= MAX_OTP_ATTEMPTS
  end

  def otp_window_anchor
    otp_last_sent_at
  end
end
