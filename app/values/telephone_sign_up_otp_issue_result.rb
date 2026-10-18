# frozen_string_literal: true

TelephoneSignUpOtpIssueResult =
  Data.define(:status, :transaction, :code) do
    public

    def success? = status == :issued

    def success? = status == :issued

    def inspect
      "#<TelephoneSignUpOtpIssueResult status=#{status.inspect} proof=[FILTERED]>"
    end
  end
