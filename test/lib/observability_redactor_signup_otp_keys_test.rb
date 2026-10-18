# frozen_string_literal: true

require "test_helper"

class ObservabilityRedactorSignupOtpKeysTest < ActiveSupport::TestCase
  test "structured observations redact original signup delivery references and counter" do
    output = ObservabilityRedactor.scrub(
      sign_up_flow_ref: "original-flow", sign_up_otp_counter: "1",
      sign_up_otp_context: { flow_ref: "original-flow", code_digest: "digest" },
    )

    assert_equal ObservabilityRedactor::REDACTED, output.fetch(:sign_up_flow_ref)
    assert_equal ObservabilityRedactor::REDACTED, output.fetch(:sign_up_otp_counter)
    assert_equal ObservabilityRedactor::REDACTED, output.fetch(:sign_up_otp_context)
  end
end
