# typed: false
# frozen_string_literal: true

require "test_helper"

class SessionAbsoluteExpiryValueTest < ActiveSupport::TestCase
  test "caps any token expiry at the fixed session deadline" do
    now = Time.utc(2026, 9, 13, 9, 0)
    absolute_expiry = now + 1.hour

    assert_equal absolute_expiry,
                 SessionAbsoluteExpiryValue.cap(
                   proposed_expiry: now + 2.hours,
                   absolute_expiry: absolute_expiry,
                 )
    assert_equal now + 30.minutes,
                 SessionAbsoluteExpiryValue.cap(
                   proposed_expiry: now + 30.minutes,
                   absolute_expiry: absolute_expiry,
                 )
  end

  test "leaves a proposed token expiry unchanged when no finite session deadline exists" do
    proposed = Time.utc(2026, 9, 13, 10, 0)

    assert_equal proposed, SessionAbsoluteExpiryValue.cap(proposed_expiry: proposed, absolute_expiry: nil)
    assert_equal proposed,
                 SessionAbsoluteExpiryValue.cap(proposed_expiry: proposed, absolute_expiry: Float::INFINITY)
  end

  test "uses the finite session deadline when no finite token expiry was requested" do
    deadline = Time.utc(2026, 9, 13, 10, 0)

    assert_equal deadline,
                 SessionAbsoluteExpiryValue.cap(proposed_expiry: nil, absolute_expiry: deadline)
  end
end
