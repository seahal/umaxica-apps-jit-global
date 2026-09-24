# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../app/values/processor_erasure_retry_policy"

class ProcessorErasureRetryPolicyTest < Minitest::Test
  def test_exhaustion_boundary_is_inclusive
    policy = ProcessorErasureRetryPolicy.new(max_attempts: 3, retry_delay_seconds: 0)

    refute policy.exhausted?(2) # rubocop:disable Rails/RefuteMethods
    assert policy.exhausted?(3)
    assert policy.exhausted?(4)
  end

  def test_attempt_number_zero_and_negative_are_rejected_by_both_operations
    policy = ProcessorErasureRetryPolicy.new(max_attempts: 3, retry_delay_seconds: 0)

    [0, -1].each do |attempt_number|
      assert_raises(ArgumentError) { policy.exhausted?(attempt_number) }
      assert_raises(ArgumentError) { policy.retry_at(now: Time.utc(2026, 9, 23), attempt_number:) }
    end
  end

  def test_retry_attempt_limit_accepts_only_the_declared_boundary
    assert_equal 1, ProcessorErasureRetryPolicy.new(max_attempts: 1, retry_delay_seconds: 0).max_attempts
    assert_equal 1_000, ProcessorErasureRetryPolicy.new(max_attempts: 1_000, retry_delay_seconds: 0).max_attempts

    assert_raises(ArgumentError) do
      ProcessorErasureRetryPolicy.new(max_attempts: 0, retry_delay_seconds: 0)
    end
    assert_raises(ArgumentError) do
      ProcessorErasureRetryPolicy.new(max_attempts: 1_001, retry_delay_seconds: 0)
    end
  end

  def test_policy_rejects_fractional_numeric_values_in_integer_contracts
    assert_raises(ArgumentError) do
      ProcessorErasureRetryPolicy.new(max_attempts: 2.5, retry_delay_seconds: 0)
    end

    assert_raises(ArgumentError) do
      ProcessorErasureRetryPolicy.new(max_attempts: 2, retry_delay_seconds: 1.5)
    end

    policy = ProcessorErasureRetryPolicy.new(max_attempts: 2, retry_delay_seconds: 0)
    assert_raises(ArgumentError) { policy.exhausted?(1.5) }
    assert_raises(ArgumentError) { policy.retry_at(now: Time.utc(2026, 9, 23), attempt_number: 1.5) }
  end
end
