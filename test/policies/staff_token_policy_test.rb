# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OperatorTokenPolicyTest < ActiveSupport::TestCase
  def setup
    @user = nil
    @record = nil
    @policy = OperatorTokenPolicy.new(@record, user: @user)
  end

  def test_index
    assert_not @policy.index?
  end

  # index? gates the session listing to the owning actor type (Operator).
  def test_index_allows_operator
    assert_predicate OperatorTokenPolicy.new(nil, user: Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED)),
                     :index?
  end

  def test_index_denies_other_actor_types
    assert_not OperatorTokenPolicy.new(nil, user: Client.new(security_mode_id: SecurityModeConfigurable::NORMAL)).index?
    assert_not OperatorTokenPolicy.new(nil, user: Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL)).index?
  end

  def test_destroy_allows_owner_operator_token
    operator = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, id: 123)
    token = OperatorToken.new(staff_id: operator.id)

    assert_predicate OperatorTokenPolicy.new(token, user: operator), :destroy?
  end

  def test_destroy_denies_other_operator_token
    operator = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, id: 123)
    token = OperatorToken.new(staff_id: 456)

    assert_not OperatorTokenPolicy.new(token, user: operator).destroy?
  end

  def test_destroy_denies_other_actor_types
    token = OperatorToken.new(staff_id: 123)

    assert_not OperatorTokenPolicy.new(
      token,
      user: Client.new(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        id: 123,
      ),
    ).destroy?
    assert_not OperatorTokenPolicy.new(
      token,
      user: Visitor.new(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        id: 123,
      ),
    ).destroy?
  end

  def test_revoke_others_allows_operator_token_class_for_operator
    assert_predicate OperatorTokenPolicy.new(OperatorToken, user: Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED)),
                     :revoke_others?
  end

  def test_revoke_others_denies_non_operators_and_instances
    assert_not OperatorTokenPolicy.new(OperatorToken, user: Client.new(security_mode_id: SecurityModeConfigurable::NORMAL)).revoke_others?
    assert_not OperatorTokenPolicy.new(OperatorToken, user: Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL)).revoke_others?
    assert_not OperatorTokenPolicy.new(OperatorToken.new, user: Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED)).revoke_others?
  end

  def test_show
    assert_not @policy.show?
  end

  def test_create
    assert_not @policy.create?
  end

  def test_new
    assert_not @policy.new?
  end

  def test_update
    assert_not @policy.update?
  end

  def test_edit
    assert_not @policy.edit?
  end

  def test_destroy
    assert_not @policy.destroy?
  end
end
