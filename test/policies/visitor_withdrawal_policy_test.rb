# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# The withdrawal flow is owner-self only: a visitor may drive their own withdrawal, never another's.
class VisitorWithdrawalPolicyTest < ActiveSupport::TestCase
  def test_allows_owner_visitor_for_all_rules
    owner = Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1)
    policy = VisitorWithdrawalPolicy.new(owner, user: owner)

    assert_predicate policy, :new?
    assert_predicate policy, :create?
    assert_predicate policy, :edit?
    assert_predicate policy, :update?
    assert_predicate policy, :destroy?
  end

  def test_denies_different_visitor
    owner = Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1)
    other = Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 2)
    policy = VisitorWithdrawalPolicy.new(owner, user: other)

    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.destroy?
  end

  def test_denies_nil_user
    policy = VisitorWithdrawalPolicy.new(
      Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1),
      user: nil,
    )

    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.destroy?
  end
end
