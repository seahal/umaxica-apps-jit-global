# frozen_string_literal: true

EmailCredentialRegistrationOtpVerificationResult =
  Data.define(:status, :email) do
    public

    def success? = status == :verified

    def verified_evidence? = %i(verified already_verified).include?(status)
  end
