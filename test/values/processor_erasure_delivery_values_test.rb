# frozen_string_literal: true

require "minitest/autorun"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/numeric/bytes"
require_relative "../../app/policies/chronicle_record_policy"
require_relative "../../app/values/processor_erasure_dispatch_result"
require_relative "../../app/values/processor_erasure_verified_receipt"

class ProcessorErasureDeliveryValuesTest < Minitest::Test
  def test_verified_receipt_rejects_invalid_security_bindings
    invalid_values = [
      { generation: 0 },
      { processor_key: "" },
      { notification_public_id: "" },
      { idempotency_key_digest: "not-a-digest" },
      { receipt_id: "" },
      { verified_at: nil },
    ]

    invalid_values.each do |overrides|
      assert_raises(ArgumentError, overrides.inspect) do
        ProcessorErasureVerifiedReceipt.new(**valid_receipt_attributes.merge(overrides))
      end
    end
  end

  def test_verified_receipt_normalizes_integer_and_string_bindings
    receipt = ProcessorErasureVerifiedReceipt.new(
      **valid_receipt_attributes.merge(
        generation: "2",
        processor_key: :email_delivery,
        notification_public_id: 123,
        idempotency_key_digest: valid_receipt_attributes.fetch(:idempotency_key_digest),
        receipt_id: 456,
      ),
    )

    assert_equal 2, receipt.generation
    assert_equal "email_delivery", receipt.processor_key
    assert_equal "123", receipt.notification_public_id
    assert_equal valid_receipt_attributes.fetch(:idempotency_key_digest), receipt.idempotency_key_digest
    assert_equal "456", receipt.receipt_id
  end

  def test_verified_receipt_rejects_fractional_generation
    assert_raises(ArgumentError) do
      ProcessorErasureVerifiedReceipt.new(**valid_receipt_attributes.merge(generation: 1.5))
    end
  end

  def test_dispatch_result_requires_verified_receipt_for_success
    assert_raises(ArgumentError) do
      ProcessorErasureDispatchResult.received(receipt: Object.new)
    end

    [nil, 0].each do |outcome|
      assert_raises(ArgumentError, outcome.inspect) do
        ProcessorErasureDispatchResult.new(
          outcome:,
          receipt: nil,
          error_code: nil,
          error_message: nil,
        )
      end
    end

    assert_instance_of ProcessorErasureDispatchResult, ProcessorErasureDispatchResult.accepted_without_receipt
    assert_raises(ArgumentError) do
      ProcessorErasureDispatchResult.retryable(code: "", message: "temporary")
    end

    assert_raises(ArgumentError) do
      ProcessorErasureDispatchResult.retryable(code: "provider token=secret", message: "temporary")
    end
  end

  def test_failure_message_is_sanitized_before_it_can_be_persisted
    raw_token = "a" * 40

    result = ProcessorErasureDispatchResult.retryable(
      code: "temporary",
      message: "provider token=#{raw_token}",
    )

    assert_nil result.error_message.index(raw_token)
    assert_includes result.error_message, "[FILTERED]"
  end

  def test_direct_dispatch_result_construction_preserves_message_sanitization
    raw_token = "b" * 40

    result = ProcessorErasureDispatchResult.new(
      outcome: :retryable_failure,
      receipt: nil,
      error_code: "temporary",
      error_message: "provider token=#{raw_token}",
    )

    assert_nil result.error_message.index(raw_token)
    assert_includes result.error_message, "[FILTERED]"
  end

  private

  def valid_receipt_attributes
    {
      processor_key: "email_delivery",
      notification_public_id: "notification-1",
      generation: 1,
      idempotency_key_digest: "a" * 64,
      receipt_id: "receipt-1",
      verified_at: Time.utc(2026, 9, 23, 7, 0, 0),
    }
  end
end
