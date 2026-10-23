# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Object-level authorization for the org (operator) passkey listing.
# index? allows any authenticated actor reaching the surface; nil is denied. Other defaults
# stay deny-all (allowlist).
class OperatorPasskeyPolicyTest < ActiveSupport::TestCase
  def test_index_denied_for_nil_user
    policy = OperatorPasskeyPolicy.new(OperatorPasskey.new, user: nil)

    assert_not policy.index?
  end

  def test_index_allowed_for_authenticated_user
    policy = OperatorPasskeyPolicy.new(
      OperatorPasskey.new,
      user: Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, id: 1),
    )

    assert_predicate policy, :index?
  end

  def test_show_denied_by_default
    policy = OperatorPasskeyPolicy.new(
      OperatorPasskey.new,
      user: Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, id: 1),
    )

    assert_not policy.show?
  end

  # create? gates registration (fresh record) to any authenticated operator.
  def test_create_allowed_for_authenticated_user
    policy = OperatorPasskeyPolicy.new(
      OperatorPasskey.new,
      user: Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, id: 1),
    )

    assert_predicate policy, :create?
    assert_predicate policy, :new?
  end

  def test_create_denied_for_nil_user
    assert_not OperatorPasskeyPolicy.new(OperatorPasskey.new, user: nil).create?
  end

  # show?/update?/destroy? require ownership (record.staff_id == operator.id).
  def test_per_record_rules_allow_owner
    owner = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, id: 1)
    record = OperatorPasskey.new(staff_id: 1)

    assert_predicate OperatorPasskeyPolicy.new(record, user: owner), :show?
    assert_predicate OperatorPasskeyPolicy.new(record, user: owner), :update?
    assert_predicate OperatorPasskeyPolicy.new(record, user: owner), :edit?
    assert_predicate OperatorPasskeyPolicy.new(record, user: owner), :destroy?
  end

  def test_per_record_rules_deny_non_owner
    owner = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, id: 1)
    record = OperatorPasskey.new(staff_id: 2)

    assert_not OperatorPasskeyPolicy.new(record, user: owner).show?
    assert_not OperatorPasskeyPolicy.new(record, user: owner).update?
    assert_not OperatorPasskeyPolicy.new(record, user: owner).destroy?
  end

  def test_relation_scope_filters_by_staff_id
    relation = Class.new do
      attr_reader :calls

      def initialize
        @calls = []
      end

      def where(**kwargs)
        @calls << [:where, kwargs]
        :where_scope
      end

      def none
        @calls << :none
        :none_scope
      end
    end.new

    user = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, id: 1)

    assert_equal :where_scope, OperatorPasskeyPolicy.new(OperatorPasskey.new, user: user).apply_scope(
      relation,
      type: :active_record_relation,
    )
    assert_equal [[:where, { staff_id: 1 }]], relation.calls
  end

  def test_relation_scope_returns_none_for_nil_user
    relation = Class.new do
      attr_reader :calls

      def initialize
        @calls = []
      end

      def where(**kwargs)
        @calls << [:where, kwargs]
        :where_scope
      end

      def none
        @calls << :none
        :none_scope
      end
    end.new

    assert_equal :none_scope, OperatorPasskeyPolicy.new(OperatorPasskey.new, user: nil).apply_scope(
      relation,
      type: :active_record_relation,
    )
    assert_equal [:none], relation.calls
  end
end
