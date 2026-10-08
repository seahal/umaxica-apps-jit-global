# frozen_string_literal: true

EmailSignUpOtpVerificationResult =
  Data.define(:status, :email) do
    public

    def success? = status == :verified

    def verified_evidence? = %i(verified already_verified).include?(status)
  end
