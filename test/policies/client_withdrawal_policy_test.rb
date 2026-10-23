# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# The withdrawal flow is owner-self only: a client may drive their own withdrawal, never another's.
class ClientWithdrawalPolicyTest < ActiveSupport::TestCase
  def test_allows_owner_client_for_all_rules
    owner = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1)
    policy = ClientWithdrawalPolicy.new(owner, user: owner)

    assert_predicate policy, :new?
    assert_predicate policy, :create?
    assert_predicate policy, :edit?
    assert_predicate policy, :update?
    assert_predicate policy, :destroy?
  end

  def test_denies_different_client
    owner = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1)
    other = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 2)
    policy = ClientWithdrawalPolicy.new(owner, user: other)

    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.destroy?
  end

  def test_denies_nil_user
    policy = ClientWithdrawalPolicy.new(
      Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1),
      user: nil,
    )

    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.destroy?
  end
end
