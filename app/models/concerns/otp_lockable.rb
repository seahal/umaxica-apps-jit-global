# typed: false
# frozen_string_literal: true

# OtpLockable centralizes the OTP attempt/lock/expiry mechanics shared by the
# Email and Telephone concerns. Both concerns include this module; channel
# specifics (address vs number normalization, encryption, lookup scopes, and the
# email-only cooldown) stay in the including concern.
#
# Requires:
# - otp_counter
# - otp_private_key
# - otp_attempts_count
# - otp_expires_at
# - locked_at
#
# Optional:
# - otp_last_sent_at
#     Present on email tables; absent on telephone tables. When absent, time
#     windows (attempt window, re-registration window) anchor on created_at via
#     #otp_window_anchor. Cooldown, which strictly needs otp_last_sent_at, is
#     therefore intentionally NOT defined here and lives in the Email concern.
#
# Registers:
# - after_initialize OTP defaults (otp_counter, otp_private_key, otp_attempts_count)
#
# Sentinel convention:
# - locked_at and otp_expires_at use the PostgreSQL "-infinity" sentinel to mean
#   "in the distant past" => unlocked / already expired. #lockout_expires_at also
#   tolerates the legacy "+infinity" value defensively, but all writers here use
#   OTP_UNLOCKED_SENTINEL.
module OtpLockable
  extend ActiveSupport::Concern

  MAX_OTP_ATTEMPTS = 5
  OTP_ATTEMPT_WINDOW = 15.minutes
  OTP_LOCKOUT_DURATION = 15.minutes

  # Written to locked_at to mark a record as not locked. "-infinity" reads as a
  # lockout that expired in the distant past, i.e. no active lock.
  #
  # Must be the Float, not the "-infinity" string: ActiveRecord's timestamp type
  # cast silently turns the string sentinel into nil (violating the NOT NULL
  # column), while the Float casts to PostgreSQL's -infinity correctly.
  OTP_UNLOCKED_SENTINEL = -Float::INFINITY

  included do
    after_initialize do
      self.otp_counter = "0" if otp_counter.blank?
      self.otp_private_key = ROTP::Base32.random_base32 if otp_private_key.blank?
      self.otp_attempts_count ||= 0
    end
  end

  # Stores OTP credential on this record.
  def store_otp(otp_private_key, otp_counter, expires_at)
    attrs = {
      otp_private_key: otp_private_key,
      otp_counter: otp_counter,
      otp_expires_at: Time.zone.at(expires_at),
    }
    attrs[:otp_last_sent_at] = Time.current if respond_to?(:otp_last_sent_at=)

    attrs[:locked_at] = OTP_UNLOCKED_SENTINEL unless locked?

    update!(attrs)
  end

  # Retrieves OTP credential from this record, or nil when expired/locked/blank.
  def get_otp
    return nil if otp_private_key.blank? || otp_expired? || locked?

    {
      otp_private_key: otp_private_key,
      otp_counter: Integer(otp_counter.to_s, 10),
      otp_expires_at: otp_expires_at.to_i,
    }
  end

  # Clears OTP credential after verification, leaving the record unlocked.
  # otp_private_key is intentionally kept (the column is NOT NULL and the key is
  # safe to reuse).
  def clear_otp(reset_attempts: true)
    attrs = {
      otp_counter: "0",
      otp_expires_at: -Float::INFINITY,
    }
    attrs[:otp_attempts_count] = 0 if reset_attempts
    attrs[:locked_at] = OTP_UNLOCKED_SENTINEL if reset_attempts
    attrs[:otp_last_sent_at] = -Float::INFINITY if respond_to?(:otp_last_sent_at=)

    update!(attrs)
  end

  def otp_expired?
    return true if otp_expires_at.is_a?(Float) && otp_expires_at == -Float::INFINITY

    otp_expires_at.nil? || otp_expires_at <= Time.current
  end

  def otp_active?
    !otp_expired? && !locked?
  end

  def locked?
    lockout_active? || attempts_locked_without_expiry?
  end

  def lockout_active?
    lockout_expires_at.present? && lockout_expires_at > Time.current
  end

  def lockout_expires_at
    return nil if locked_at.blank? || locked_at == -Float::INFINITY || locked_at == Float::INFINITY

    locked_at
  end

  def reregistration_window_active?
    anchor = otp_window_anchor
    return false if anchor.blank? || anchor == -Float::INFINITY

    anchor > CommonOtpPolicy::REREGISTRATION_OVERWRITE_WINDOW.ago
  end

  # Increments the attempt counter under a row lock and applies the lockout once
  # the threshold is reached. Uses save!(validate: false) on purpose: this is an
  # internal counter bump, not a user-facing save, so unrelated model validations
  # must never block it.
  def increment_attempts!
    operation =
      lambda do
        with_lock do
          next if lockout_active?

          unless attempt_window_active?
            self.otp_last_sent_at = Time.current if respond_to?(:otp_last_sent_at=)
            self.otp_attempts_count = 0
          end

          self.otp_attempts_count = otp_attempts_count.to_i + 1
          self.locked_at = OTP_LOCKOUT_DURATION.from_now if otp_attempts_count >= MAX_OTP_ATTEMPTS
          save!(validate: false)
        end
        reload
      end

    defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
  end

  private

  def attempt_window_active?
    anchor = otp_window_anchor
    return false if anchor.blank? || anchor == -Float::INFINITY

    anchor > OTP_ATTEMPT_WINDOW.ago
  end

  def attempts_locked_without_expiry?
    lockout_expires_at.blank? && attempt_window_active? && otp_attempts_count.to_i >= MAX_OTP_ATTEMPTS
  end

  # Anchor for time windows: the explicit otp_last_sent_at column when it exists
  # (email tables), otherwise created_at (telephone tables).
  def otp_window_anchor
    respond_to?(:otp_last_sent_at) ? otp_last_sent_at : created_at
  end
end
