# frozen_string_literal: true

# Keeping response timing separate prevents Email callers from exposing the retired shared Source verifier.
module EmailOtpResponseTiming
  extend ActiveSupport::Concern

  TIMING_PROTECTION_SECONDS = 0.01

  private

  def ensure_min_elapsed(start_time, target_seconds = TIMING_PROTECTION_SECONDS)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
    remaining = target_seconds - elapsed
    sleep(remaining) if remaining.positive?
  end

  def ensure_email_auth_verification_elapsed(start_time, code:)
    return unless code.is_a?(String) && code.match?(/\A[0-9]{6}\z/)

    ensure_min_elapsed(start_time, EmailOtpPolicy::EMAIL_AUTH_RESPONSE_MINIMUM_SECONDS)
  end

  def perform_dummy_otp_generation
    SecureRandom.random_number(1_000_000).to_s.rjust(6, "0")
  end

  def verify_dummy_otp(submitted_code)
    value = submitted_code.to_s
    ActiveSupport::SecurityUtils.secure_compare("000000", value) if value.match?(/\A[0-9]{6}\z/)
    { success: false, error: "Invalid OTP code" }
  end
end
