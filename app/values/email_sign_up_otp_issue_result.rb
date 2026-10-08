# frozen_string_literal: true

EmailSignUpOtpIssueResult =
  Data.define(:status, :transaction, :code) do
    public

    def success? = status == :issued

    def inspect
      "#<EmailSignUpOtpIssueResult status=#{status.inspect} proof=[FILTERED]>"
    end
  end
