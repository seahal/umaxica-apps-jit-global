# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# The org withdrawal landing page is owner-self only: an operator may view their own, never another's.
class OperatorWithdrawalPolicyTest < ActiveSupport::TestCase
  def test_allows_owner_operator
    owner = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, id: 1)
    policy = OperatorWithdrawalPolicy.new(owner, user: owner)

    assert_predicate policy, :show?
  end

  def test_denies_different_operator
    owner = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, id: 1)
    other = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, id: 2)
    policy = OperatorWithdrawalPolicy.new(owner, user: other)

    assert_not policy.show?
  end

  def test_denies_nil_user
    policy = OperatorWithdrawalPolicy.new(
      Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, id: 1),
      user: nil,
    )

    assert_not policy.show?
  end
end
