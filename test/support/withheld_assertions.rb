# frozen_string_literal: true

# Assertions for values that must not reach test output.
module WithheldAssertions
  # `assert_equal`, `assert_same`, `assert_operator` and their kin render both operands when they
  # fail, and a failure message ends up in CI logs. Where an operand is an OTP context, a session or
  # ceremony binding, a credential record, or a keyed proof, that rendering is a disclosure. This
  # takes the comparison as a block so only its truth value is ever inspected.
  def assert_withheld(message = "Expected the withheld comparison to hold")
    holds = yield

    assert holds, message
  end
end
