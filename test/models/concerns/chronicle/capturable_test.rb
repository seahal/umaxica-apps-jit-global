# typed: false
# frozen_string_literal: true

require "test_helper"

class ChronicleCapturableTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class BusinessFailure < StandardError; end

  setup do
    @policy =
      ChronicleRetentionPolicy.find_or_create_by!(code: "security") do |policy|
        policy.name = "Security"
        policy.duration_days = 365
        policy.permanent = false
      end
  end

  test "capture records succeeded when block succeeds" do
    result =
      Chronicle.capture(
        action: "auth.sign_in.failed",
        request_id: "request-success",
      ) do
        "business-result"
      end

    chronicle = Chronicle.includes(:chronicle_retention_policy).find_by!(request_id: "request-success")

    assert_equal "business-result", result
    assert_equal "succeeded", chronicle.result
    assert_equal "auth.sign_in.failed", chronicle.action
    assert_equal @policy, chronicle.chronicle_retention_policy
    assert_equal 365.days.from_now.to_date, chronicle.erasable_at.to_date
  end

  test "capture records failed and reraises original block exception" do
    error =
      assert_raises(BusinessFailure) do
        Chronicle.capture(
          action: "auth.sign_in.failed",
          request_id: "request-failure",
        ) do
          raise BusinessFailure, "business failed"
        end
      end

    chronicle = Chronicle.find_by!(request_id: "request-failure")

    assert_equal "business failed", error.message
    assert_equal "failed", chronicle.result
  end

  test "result writer failure invokes invalidator" do
    invalidator_calls = []
    event_uuid = SecureRandom.uuid

    SecureRandom.stub(:uuid, event_uuid) do
      ChronicleResultWriter.stub(:call, ->(**_args) { raise StandardError, "result failed" }) do
        ChronicleInvalidator.stub(:call, ->(**args) { invalidator_calls << args }) do
          result =
            Chronicle.capture(
              action: "auth.sign_in.failed",
              request_id: "request-result-failure",
            ) do
              "business-result"
            end

          assert_equal "business-result", result
        end
      end
    end

    assert_equal 1, invalidator_calls.size
    assert_equal event_uuid, invalidator_calls.first.fetch(:event_uuid)
    assert_equal "request-result-failure", invalidator_calls.first.fetch(:request_id)
  end

  test "invalidator failure logs manual recovery required with same event uuid" do
    event_uuid = SecureRandom.uuid
    log_io = StringIO.new
    logger = ActiveSupport::Logger.new(log_io)

    SecureRandom.stub(:uuid, event_uuid) do
      Rails.stub(:logger, logger) do
        ChronicleResultWriter.stub(:call, ->(**_args) { raise StandardError, "result failed" }) do
          ChronicleInvalidator.stub(:call, ->(**_args) { raise StandardError, "invalidation failed" }) do
            Chronicle.capture(
              action: "auth.sign_in.failed",
              request_id: "request-invalidation-failure",
            ) do
              "business-result"
            end
          end
        end
      end
    end

    log_lines = log_io.string.lines

    assert log_lines.any? { |line| line.include?("chronicle.manual_recovery_required") }
    assert log_lines.any? { |line| line.include?(event_uuid) }
    assert log_lines.any? { |line| line.include?("request-invalidation-failure") }
  end

  test "event_uuid is reused for intent and result writes" do
    event_uuid = SecureRandom.uuid
    result_writer_calls = []
    original_result_writer = ChronicleResultWriter.method(:call)

    SecureRandom.stub(:uuid, event_uuid) do
      ChronicleResultWriter.stub(
        :call,
        lambda do |**args|
          result_writer_calls << args
          original_result_writer.call(**args)
        end,
      ) do
        Chronicle.capture(
          action: "auth.sign_in.failed",
          request_id: "request-event-uuid",
        ) do
          true
        end
      end
    end

    chronicle = Chronicle.find_by!(request_id: "request-event-uuid")

    assert_equal event_uuid, chronicle.event_uuid
    assert_equal event_uuid, result_writer_calls.first.fetch(:event_uuid)
  end

  test "metadata cannot spoof trusted request context columns" do
    Chronicle.capture(
      action: "auth.sign_in.failed",
      request_id: "trusted-request",
      ip_address: "203.0.113.10",
      user_agent: "Trusted Agent",
      metadata: {
        request_id: "spoofed-request",
        ip_address: "198.51.100.10",
        user_agent: "Spoofed Agent",
      },
    ) do
      true
    end

    chronicle = Chronicle.find_by!(request_id: "trusted-request")

    assert_equal "203.0.113.10", chronicle.ip_address.to_s
    assert_equal "Trusted Agent", chronicle.user_agent
    assert_nil chronicle.metadata["request_id"]
    assert_nil chronicle.metadata["ip_address"]
    assert_nil chronicle.metadata["user_agent"]
    assert_nil Chronicle.find_by(request_id: "spoofed-request")
  end

  test "capture does not accept retention policy override" do
    assert_raises(ArgumentError) do
      Chronicle.capture(
        action: "account.terminated",
        retention_policy_code: "ephemeral",
        request_id: "request-retention-downgrade",
      ) do
        true
      end
    end

    assert_nil Chronicle.find_by(request_id: "request-retention-downgrade")
  end

  test "reason and free text metadata are sanitized" do
    Chronicle.capture(
      action: "auth.sign_in.failed",
      request_id: "request-sanitized-text",
      reason: "password=super-secret_credential",
      metadata: {
        note: "otp 123456 and Bearer abc.def.ghi",
        opaque: "a" * 40,
      },
    ) do
      true
    end

    chronicle = Chronicle.find_by!(request_id: "request-sanitized-text")

    assert_equal "[FILTERED]", chronicle.reason
    assert_equal "otp [FILTERED] and [FILTERED]", chronicle.metadata["note"]
    assert_equal "[FILTERED]", chronicle.metadata["opaque"]
  end

  test "unknown visibility context does not drop audit intent" do
    Chronicle.capture(
      action: "auth.sign_in.failed",
      request_id: "request-unknown-visibility",
      visibility_contexts: ["missing-context"],
    ) do
      true
    end

    chronicle = Chronicle.find_by!(request_id: "request-unknown-visibility")

    assert_equal "succeeded", chronicle.result
    assert_empty chronicle.chronicle_visibilities
  end
end
