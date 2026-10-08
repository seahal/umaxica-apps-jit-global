# frozen_string_literal: true

TelephoneCredentialRegistrationOtpIssueResult =
  Data.define(:status, :transaction, :code) do
    public

    def success? = status == :issued

    def inspect
      "#<TelephoneCredentialRegistrationOtpIssueResult status=#{status} transaction=[FILTERED] code=[FILTERED]>"
    end
  end
