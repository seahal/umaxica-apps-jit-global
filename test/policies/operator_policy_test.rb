# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OperatorPolicyTest < ActiveSupport::TestCase
  def test_index_returns_false_by_default
    policy = OperatorPolicy.new(Operator.new, user: nil)

    assert_not policy.index?
  end

  def test_show_returns_false_by_default
    policy = OperatorPolicy.new(Operator.new, user: nil)

    assert_not policy.show?
  end

  # show? gates owner-only viewing of account attributes (e.g. the birthdate page).
  def test_show_allows_owner_operator
    owner = Operator.new(id: 1)
    policy = OperatorPolicy.new(owner, user: owner)

    assert_predicate policy, :show?
  end

  def test_show_denies_different_operator
    owner = Operator.new(id: 1)
    other = Operator.new(id: 2)
    policy = OperatorPolicy.new(owner, user: other)

    assert_not policy.show?
  end

  def test_audit_allows_owner_operator
    owner = Operator.new(id: 1)
    policy = OperatorPolicy.new(owner, user: owner)

    assert_predicate policy, :audit?
  end

  def test_audit_denies_different_operator
    owner = Operator.new(id: 1)
    other = Operator.new(id: 2)
    policy = OperatorPolicy.new(owner, user: other)

    assert_not policy.audit?
  end

  def test_audit_denies_non_operator_actor
    client = Client.new(id: 1)
    operator = Operator.new(id: client.id)
    policy = OperatorPolicy.new(operator, user: client)

    assert_not policy.audit?
  end

  def test_billing_allows_owner_operator
    owner = Operator.new(id: 1)
    policy = OperatorPolicy.new(owner, user: owner)

    assert_predicate policy, :billing?
  end

  def test_billing_denies_different_operator
    owner = Operator.new(id: 1)
    other = Operator.new(id: 2)
    policy = OperatorPolicy.new(owner, user: other)

    assert_not policy.billing?
  end

  def test_billing_denies_non_operator_actor
    client = Client.new(id: 1)
    operator = Operator.new(id: client.id)
    policy = OperatorPolicy.new(operator, user: client)

    assert_not policy.billing?
  end

  def test_iam_allows_owner_operator
    owner = Operator.new(id: 1)
    policy = OperatorPolicy.new(owner, user: owner)

    assert_predicate policy, :iam?
  end

  def test_iam_denies_different_operator
    owner = Operator.new(id: 1)
    other = Operator.new(id: 2)
    policy = OperatorPolicy.new(owner, user: other)

    assert_not policy.iam?
  end

  def test_iam_denies_non_operator_actor
    client = Client.new(id: 1)
    operator = Operator.new(id: client.id)
    policy = OperatorPolicy.new(operator, user: client)

    assert_not policy.iam?
  end

  def test_support_allows_owner_operator
    owner = Operator.new(id: 1)
    policy = OperatorPolicy.new(owner, user: owner)

    assert_predicate policy, :support?
  end

  def test_support_denies_different_operator
    owner = Operator.new(id: 1)
    other = Operator.new(id: 2)
    policy = OperatorPolicy.new(owner, user: other)

    assert_not policy.support?
  end

  def test_support_denies_non_operator_actor
    client = Client.new(id: 1)
    operator = Operator.new(id: client.id)
    policy = OperatorPolicy.new(operator, user: client)

    assert_not policy.support?
  end

  def test_create_returns_false_by_default
    policy = OperatorPolicy.new(Operator.new, user: nil)

    assert_not policy.create?
  end

  def test_update_returns_false_by_default
    policy = OperatorPolicy.new(Operator.new, user: nil)

    assert_not policy.update?
  end

  # update? gates owner-only mutation of account attributes (e.g. the MFA level page).
  def test_update_allows_owner_operator
    owner = Operator.new(id: 1)
    policy = OperatorPolicy.new(owner, user: owner)

    assert_predicate policy, :update?
  end

  def test_update_denies_different_operator
    owner = Operator.new(id: 1)
    other = Operator.new(id: 2)
    policy = OperatorPolicy.new(owner, user: other)

    assert_not policy.update?
  end

  def test_destroy_returns_false_by_default
    policy = OperatorPolicy.new(Operator.new, user: nil)

    assert_not policy.destroy?
  end

  def test_purge_sessions_allows_operator
    operator = Operator.new(id: 1)
    policy = OperatorPolicy.new(Operator.new, user: operator)

    assert_predicate policy, :purge_sessions?
  end

  def test_purge_sessions_denies_nil_user
    policy = OperatorPolicy.new(Operator.new, user: nil)

    assert_not policy.purge_sessions?
  end

  def test_purge_sessions_denies_non_operator_user
    client = Client.new(id: 1)
    policy = OperatorPolicy.new(Operator.new, user: client)

    assert_not policy.purge_sessions?
  end
end
