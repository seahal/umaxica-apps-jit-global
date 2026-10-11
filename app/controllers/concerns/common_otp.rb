# typed: false
# frozen_string_literal: true

# Concern for handling OTP (One-Time Password) authentication logic
# Provides methods for generating, verifying, and managing HOTP-based authentication
#
# Usage:
#   class MyController < ApplicationController
#     include CommonOtp
#   end
module CommonOtp
  extend ActiveSupport::Concern

  # Default OTP expiration time in minutes
  OTP_EXPIRATION_MINUTES = 12

  # Minimum elapsed time for timing attack protection (in seconds)
  TIMING_PROTECTION_SECONDS = 0.01

  private

  # ============================================================
  # Basic HOTP generation/verification (from Rotp)
  # ============================================================

  # Generate a new HOTP secret_credential, counter, and corresponding 6-digit pass code for one-time use.
  # All three values should be persisted together so the pass code can be verified later.
  #
  # @return [Array<String, Integer, String>] [secret_credential, counter, pass_code]
  def generate_hotp_code
    sec = ROTP::Base32.random
    hotp = ROTP::HOTP.new(sec)
    # Seed the HOTP counter with a CSPRNG. The counter is a one-time-use secret
    # input, so it must not come from the non-cryptographic Kernel#rand.
    # SecureRandom.random_number(999_999) yields 0..999_998; +1 -> 1..999_999;
    # *2 keeps the historical even-valued counter in range 2..1_999_998.
    counter = (SecureRandom.random_number(999_999) + 1) * 2
    [sec, counter, hotp.at(counter)]
  end

  # Verify the submitted pass code by recreating the HOTP value from the stored secret_credential and counter.
  # Returns true only when the provided code exactly matches the expected value.
  #
  # @param secret_credential [String] The stored HOTP secret_credential
  # @param counter [Integer] The stored counter value
  # @param pass_code [String] The submitted pass code to verify
  # @return [Boolean] true if codes match, false otherwise
  def verify_hotp_code(secret_credential:, counter:, pass_code:)
    submitted_code = pass_code.to_s
    return false unless submitted_code.match?(/\A\d{6}\z/)

    hotp = ROTP::HOTP.new(secret_credential)
    hotp.verify(submitted_code, counter) == counter
  end

  # ============================================================
  # Record-based OTP methods (from Auth::Otp)
  # ============================================================

  # Generates a new OTP code for a given record
  #
  # @param record [ActiveRecord::Base] The record to generate OTP for (e.g., ClientEmail, ClientTelephone)
  # @param expiration_minutes [Integer] Minutes until OTP expires (default: 12)
  # @return [String] The generated OTP code
  #
  # @example
  #   otp_code = generate_otp_for(@user_email)
  #   # => "123456"
  def generate_otp_for(record, expiration_minutes: OTP_EXPIRATION_MINUTES)
    # Generate and persist under one row lock so a concurrent issuer cannot
    # overwrite the credential after its code has been prepared for delivery.
    record.with_lock do
      otp_private_key = ROTP::Base32.random_base32
      otp_count_number = generate_otp_counter
      hotp = ROTP::HOTP.new(otp_private_key)
      otp_code = hotp.at(otp_count_number)
      expires_at = expiration_minutes.minutes.from_now.to_i

      record.store_otp(otp_private_key, otp_count_number, expires_at)
      otp_code.to_s
    end
  end

  # Generates OTP and sets attributes directly on the record (without storing)
  # Useful for records that need to be saved after OTP generation
  #
  # @param record [ActiveRecord::Base] The record to set OTP attributes on
  # @param expiration_minutes [Integer] Minutes until OTP expires (default: 12)
  # @return [String] The generated OTP code
  #
  # @example
  #   otp_code = generate_otp_attributes(@user_email)
  #   @user_email.save!
  def generate_otp_attributes(record, expiration_minutes: OTP_EXPIRATION_MINUTES)
    otp_private_key = ROTP::Base32.random_base32
    otp_count_number = generate_otp_counter
    hotp = ROTP::HOTP.new(otp_private_key)
    otp_code = hotp.at(otp_count_number)
    expires_at = expiration_minutes.minutes.from_now

    record.otp_private_key = otp_private_key
    record.otp_counter = otp_count_number
    record.otp_expires_at = expires_at

    otp_code.to_s
  end

  # Verifies an OTP code using constant-time comparison
  #
  # @param record [ActiveRecord::Base] The record containing OTP data
  # @param submitted_code [String] The code submitted by the user
  # @return [Hash] Result hash with :success and optional :error keys
  #
  # @example
  #   result = verify_otp_code(@user_email, "123456")
  #   if result[:success]
  #     # OTP is valid
  #   else
  #     # OTP is invalid, result[:error] contains error message
  #   end
  def verify_otp_code(record, submitted_code)
    otp_data = record.get_otp
    return { success: false, error: "OTP data not found" } unless otp_data
    return { success: false, error: "Submitted code is blank" } if submitted_code.blank?

    hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
    expected_code = hotp.at(otp_data[:otp_counter]).to_s

    if secure_compare_otp(expected_code, submitted_code)
      { success: true }
    else
      { success: false, error: "Invalid OTP code" }
    end
  end

  private

  # Verification and consumption must share one row-lock boundary. A caller that only verifies
  # first and clears the OTP later can accept the same correct code in two concurrent requests.
  # Failed attempts are incremented under that same boundary so a successful peer cannot be
  # followed by a stale invalid request that mutates the already-consumed record.
  def verify_otp_code_and_consume(record, submitted_code)
    result = nil
    record.with_lock do
      result = verify_otp_code(record, submitted_code)
      if result[:success]
        if !block_given? || yield(record)
          clear_otp(record)
        else
          result = { success: false, error: :consumption_rejected }
        end
      else
        increment_otp_attempts!(record)
      end
    end
    result
  end

  # ============================================================
  # Timing attack protection
  # ============================================================

  # Performs dummy OTP verification to prevent timing attacks
  # Always returns failure but takes same time as real verification
  #
  # @param submitted_code [String] The code submitted by the user
  # @return [Hash] Always returns failure result
  def verify_dummy_otp(submitted_code)
    # Perform timing attack protection with dummy comparison
    secure_compare_otp("000000", submitted_code)
    { success: false, error: "Invalid OTP code" }
  end

  # Performs dummy OTP generation to prevent timing attacks
  # Used when we want to simulate OTP generation without actually creating one
  def perform_dummy_otp_generation
    ROTP::Base32.random_base32
    ROTP::HOTP.new("dummy").at(0)
  end

  # Ensures minimum elapsed time to prevent timing attacks
  # Sleeps for remaining time if operation completed too quickly
  #
  # @param start_time [Float] Start time from Process.clock_gettime(Process::CLOCK_MONOTONIC)
  # @param target_seconds [Float] Target minimum elapsed time (default: 0.01)
  #
  # @example
  #   start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  #   # ... perform verification ...
  #   ensure_min_elapsed(start_time)
  def ensure_min_elapsed(start_time, target_seconds = TIMING_PROTECTION_SECONDS)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
    remaining = target_seconds - elapsed
    sleep(remaining) if remaining.positive?
  end

  # ============================================================
  # Record management helpers
  # ============================================================

  # Increments OTP attempt counter and checks if locked
  #
  # @param record [ActiveRecord::Base] The record to increment attempts on
  # @return [Boolean] true if record is now locked, false otherwise
  def increment_otp_attempts!(record)
    record.increment_attempts!
    record.locked?
  end

  # Clears OTP data from the record
  #
  # @param record [ActiveRecord::Base] The record to clear OTP from
  def clear_otp(record)
    record.clear_otp
  end

  private

  # Generates a secure random counter for OTP
  # Combines timestamp with random number for uniqueness
  #
  # @return [Integer] A unique counter value
  def generate_otp_counter
    Integer([Time.now.to_i, SecureRandom.random_number(1 << 64)].map(&:to_s).join.to_s, 10)
  end

  # Performs constant-time comparison of OTP codes
  # Wrapper around ActiveSupport::SecurityUtils.secure_compare
  #
  # @param expected [String] The expected OTP code
  # @param submitted [String] The submitted OTP code
  # @return [Boolean] true if codes match, false otherwise
  def secure_compare_otp(expected, submitted)
    expected_value = expected.to_s
    submitted_value = submitted.to_s
    return false unless submitted_value.match?(/\A\d{#{expected_value.length}}\z/)

    ActiveSupport::SecurityUtils.secure_compare(expected_value, submitted_value)
  end
end
