# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthenticationSecurityEventEmitterTest < ActiveSupport::TestCase
  setup do
    ChronicleRecord.connected_to(role: :writing) do
      ChronicleRetentionPolicy.find_or_create_by!(code: "security") do |policy|
        policy.name = "Security"
        policy.duration_days = 365
        policy.permanent = false
      end
    end
  end

  test "emits known event types with redacted payloads" do
    logged = []

    Rails.logger.stub(:info, ->(message) { logged << JSON.parse(message) }) do
      AuthenticationSecurityEventEmitter.emit(
        "rate_limit.exceeded",
        severity: "warning",
        reason_code: "telephone_verification_rate_limit",
        token: "raw-token",
        verifier: "raw-verifier",
        challenge: "raw-challenge",
        totp_secret: "raw-totp-secret",
        recovery_secret: "raw-recovery-secret",
        cookie: "raw-cookie",
      )
    end

    event = logged.fetch(0)
    data = event.fetch("data")

    assert_equal "authentication.security_event", event.fetch("event")
    assert_equal "rate_limit.exceeded", data.fetch("event_type")
    assert_equal "warning", data.fetch("severity")
    assert_equal "telephone_verification_rate_limit", data.fetch("reason_code")
    assert_equal "[FILTERED]", data.fetch("token")
    assert_equal "[FILTERED]", data.fetch("verifier")
    assert_equal "[FILTERED]", data.fetch("challenge")
    assert_equal "[FILTERED]", data.fetch("totp_secret")
    assert_equal "[FILTERED]", data.fetch("recovery_secret")
    assert_equal "[FILTERED]", data.fetch("cookie")
  end

  test "persists a sanitized security event in Chronicle" do
    assert_difference -> { Chronicle.count }, 1 do
      AuthenticationSecurityEventEmitter.emit(
        "rate_limit.exceeded",
        severity: "warning",
        reason_code: "telephone_verification_rate_limit",
        request_id: "req-auth-audit",
        ip_address: "127.0.0.1",
        token: "raw-token",
        otp: "123456",
      )
    end

    chronicle = Chronicle.order(:created_at).last

    assert_equal "authentication.security_event.rate_limit.exceeded", chronicle.action
    assert_equal "succeeded", chronicle.result
    assert_equal "security", chronicle.chronicle_retention_policy.code
    assert_equal "warning", chronicle.metadata["severity"]
    assert_equal "telephone_verification_rate_limit", chronicle.metadata["reason_code"]
    assert_not chronicle.metadata.key?("token")
    assert_not chronicle.metadata.key?("otp")
    assert_equal "req-auth-audit", chronicle.request_id
    assert_equal IPAddr.new("127.0.0.1"), chronicle.ip_address
  end

  test "rejects unknown event types" do
    assert_raises(ArgumentError) do
      AuthenticationSecurityEventEmitter.emit("not.real")
    end
  end

  test "keeps the operational event path when Chronicle is unavailable" do
    logged = []

    ChronicleIntentWriter.stub(
      :call,
      ->(*) { raise ActiveRecord::ConnectionNotEstablished, "chronicle unavailable" },
    ) do
      Rails.logger.stub(:info, ->(message) { logged << JSON.parse(message) }) do
        assert_nothing_raised do
          AuthenticationSecurityEventEmitter.emit(
            "rate_limit.exceeded",
            reason_code: "telephone_verification_rate_limit",
          )
        end
      end
    end

    assert_equal "authentication.security_event", logged.fetch(0).fetch("event")
  end
end
