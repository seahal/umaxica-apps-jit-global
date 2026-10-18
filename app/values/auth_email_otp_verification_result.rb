# frozen_string_literal: true

AuthEmailOtpVerificationResult =
  Data.define(:status, :contact) do
    def success? = status == :verified

    def verified_evidence? = %i(verified already_verified).include?(status)
  end
