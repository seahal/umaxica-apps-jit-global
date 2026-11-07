# typed: false
# frozen_string_literal: true

require "test_helper"

class SignSecretRecordEventLoggingBoundaryTest < ActiveSupport::TestCase
  test "the application log keeps secret credentials out of the event details" do
    log_lines = []
    credential = Struct.new(:id).new(41)
    sensitive_value = "not-a-real-secret-credential"

    result = nil
    Rails.logger.stub(:info, ->(line) { log_lines << line }) do
      result = SignSecretRecordEvent.call(
        event_name: "secret.verified",
        secret_credential: credential,
        details: { purpose: "verification", raw_secret_credential: sensitive_value },
      )
    end

    assert_equal "secret.verified", result.event_name
    assert_equal 41, result.secret_credential_id
    assert_equal 1, log_lines.length
    assert_includes log_lines.fetch(0), "secret.verified"
    assert_not_includes log_lines.fetch(0), sensitive_value
    assert_not_includes log_lines.fetch(0), "raw_secret_credential"
  end
end
