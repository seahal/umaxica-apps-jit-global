# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ChronicleRecordPolicyTest < ActiveSupport::TestCase
  test "sanitize removes forbidden keys from hash" do
    input = { "token" => "secret", "browser" => "Chrome", "password" => "hunter2" }
    result = ChronicleRecordPolicy.sanitize(input)

    assert_includes result, "browser"
    assert_not_includes result, "token"
    assert_not_includes result, "password"
  end

  test "sanitize handles nested hashes" do
    input = { "nested" => { "token" => "secret", "ok" => "value" } }
    result = ChronicleRecordPolicy.sanitize(input)

    assert_equal({ "ok" => "value" }, result["nested"])
  end

  test "sanitize filters arrays recursively" do
    input = [{ "token" => "secret" }, { "browser" => "Chrome" }]
    result = ChronicleRecordPolicy.sanitize(input)

    assert_equal [{}, { "browser" => "Chrome" }], result
  end

  test "sanitize handles string values" do
    input = "Hello world"
    result = ChronicleRecordPolicy.sanitize(input)

    assert_equal "Hello world", result
  end

  test "sanitize filters sensitive patterns in strings" do
    input = "Bearer eyJhbGciOiJIUzI1NiJ9.eyJkYXRhIjoiMSJ9.xXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXX"
    result = ChronicleRecordPolicy.sanitize(input)

    assert_includes result, "[FILTERED]"
  end

  test "sanitize_text returns nil for nil input" do
    assert_nil ChronicleRecordPolicy.sanitize_text(nil)
  end

  test "sanitize_text sanitizes string" do
    result = ChronicleRecordPolicy.sanitize_text("Bearer token123")

    assert_includes result, "[FILTERED]"
  end

  test "retention_policy_code_for returns permanent for matching patterns" do
    assert_equal "permanent", ChronicleRecordPolicy.retention_policy_code_for("audit.export.2024")
    assert_equal "permanent", ChronicleRecordPolicy.retention_policy_code_for("record.deleted")
    assert_equal "permanent", ChronicleRecordPolicy.retention_policy_code_for("record.destroyed")
    assert_equal "permanent", ChronicleRecordPolicy.retention_policy_code_for("action.irreversible")
  end

  test "retention_policy_code_for returns security for rate_limit" do
    assert_equal "security", ChronicleRecordPolicy.retention_policy_code_for("rate_limit.exceeded")
    assert_equal "security", ChronicleRecordPolicy.retention_policy_code_for("csrf_detected")
  end

  test "retention_policy_code_for returns known action policies" do
    assert_equal "ephemeral", ChronicleRecordPolicy.retention_policy_code_for("auth.sign_in.succeeded")
    assert_equal "ephemeral", ChronicleRecordPolicy.retention_policy_code_for("auth.sign_out.succeeded")
    assert_equal "security", ChronicleRecordPolicy.retention_policy_code_for("auth.sign_in.failed")
    assert_equal "compliance", ChronicleRecordPolicy.retention_policy_code_for("auth.step_up.succeeded")
    assert_equal "compliance", ChronicleRecordPolicy.retention_policy_code_for("auth.aal.changed")
    assert_equal "compliance", ChronicleRecordPolicy.retention_policy_code_for("account.suspended")
    assert_equal "compliance", ChronicleRecordPolicy.retention_policy_code_for("chronicle.audit_incomplete")
  end

  test "retention_policy_code_for defaults to security for unknown actions" do
    assert_equal "security", ChronicleRecordPolicy.retention_policy_code_for("unknown.action")
  end

  test "actor_payload returns nil values for blank actor" do
    payload = ChronicleRecordPolicy.actor_payload(nil)

    assert_nil payload[:actor_type]
    assert_nil payload[:actor_id]
  end

  test "actor_payload extracts actor info" do
    client = clients(:one)
    payload = ChronicleRecordPolicy.actor_payload(client)

    assert_equal "Client", payload[:actor_type]
    assert_predicate payload[:actor_id], :present?
  end

  test "subject_payload extracts subject info" do
    visitor = visitors(:reserved_visitor)
    payload = ChronicleRecordPolicy.subject_payload(visitor)

    assert_equal "Visitor", payload[:subject_type]
    assert_predicate payload[:subject_id], :present?
  end

  test "log_payload builds complete payload" do
    client = clients(:one)
    payload = ChronicleRecordPolicy.log_payload(
      event: "test.event",
      event_uuid: "abc-123",
      request_id: "req-456",
      action: "test.action",
      actor: client,
      subject: client,
      error: nil,
    )

    assert_equal "test.event", payload[:event]
    assert_equal "abc-123", payload[:event_uuid]
    assert_equal "req-456", payload[:request_id]
    assert_equal "test.action", payload[:action]
    assert_equal "Client", payload[:actor_type]
    assert_equal "Client", payload[:subject_type]
  end

  test "log_payload includes error info" do
    error = RuntimeError.new("Something broke")
    client = clients(:one)
    payload = ChronicleRecordPolicy.log_payload(
      event: "test.error",
      event_uuid: "abc-123",
      request_id: "req-456",
      action: "test.error",
      actor: client,
      subject: nil,
      error: error,
    )

    assert_equal "RuntimeError", payload[:error_class]
    assert_includes payload[:error_message], "Something broke"
  end

  test "sanitize preserves allowed digest keys" do
    input = { "session_id_digest" => "abc123", "token" => "secret" }
    result = ChronicleRecordPolicy.sanitize(input)

    assert_includes result, "session_id_digest"
    assert_not_includes result, "token"
  end

  test "sanitize preserves bounded categorical reason codes" do
    result = ChronicleRecordPolicy.sanitize(
      {
        reason_code: "telephone_verification_rate_limit",
        unsafe_reason_code: "a" * 64,
      },
    )

    assert_equal "telephone_verification_rate_limit", result["reason_code"]
    assert_equal "[FILTERED]", result["unsafe_reason_code"]
  end

  test "sanitize filters reserved context keys" do
    input = { "request_id" => "123", "ip_address" => "127.0.0.1", "user_agent" => "Chrome", "custom" => "ok" }
    result = ChronicleRecordPolicy.sanitize(input)

    assert_not_includes result, "request_id"
    assert_not_includes result, "ip_address"
    assert_not_includes result, "user_agent"
    assert_includes result, "custom"
  end

  test "sanitize removes credential transition forbidden secret material" do
    input = {
      raw_cookie: "__Host-session=raw",
      password: "correct-horse-battery-staple",
      otp: "123456",
      webauthn_raw_response: "client-data-json",
      csrf_token: "csrf-token-value",
      recovery_code: "recovery-code-value",
      secret_value: "secret-value",
      raw_bearer_token: "Bearer abc.def.ghi",
      reason: "mfa_disabled",
    }

    result = ChronicleRecordPolicy.sanitize(input)

    assert_equal({ "reason" => "mfa_disabled" }, result)
  end
end
