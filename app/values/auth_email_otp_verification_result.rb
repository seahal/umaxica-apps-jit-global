# frozen_string_literal: true

AuthEmailOtpVerificationResult =
  Data.define(:status, :contact) do
    def success? = %i(verified already_verified).include?(status)
  end
