# typed: false
# frozen_string_literal: true

module EmailValidation
  extend ActiveSupport::Concern

  private

  def validate_and_normalize_email(email)
    JitUtilsEmailValidator.normalize(email)
  end

  def identity_email_model
    ClientEmail
  end

  def find_email_with_timing_protection(email)
    target_seconds = email_lookup_timing_protection_seconds
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    digest = IdentifierBlindIndex.bidx_for_email(email)
    result = digest ? identity_email_model.effective_binding.find_by(address_digest: digest) : nil

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
    remaining = target_seconds - elapsed
    sleep(remaining) if remaining.positive?

    result
  end

  def email_lookup_timing_protection_seconds
    0.05
  end
end
