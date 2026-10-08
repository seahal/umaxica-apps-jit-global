# frozen_string_literal: true

TelephoneCredentialRegistrationOtpVerificationResult =
  Data.define(:status, :telephone) do
    public

    def success? = status == :verified

    def verified_evidence? = %i(verified already_verified).include?(status)
  end
