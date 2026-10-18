# frozen_string_literal: true

EmailCredentialRegistrationOtpIssueResult =
  Data.define(:status, :transaction, :code) do
    public

    def success? = status == :issued

    def inspect = "#<EmailCredentialRegistrationOtpIssueResult status=#{status} transaction=[FILTERED] code=[FILTERED]>"
  end
