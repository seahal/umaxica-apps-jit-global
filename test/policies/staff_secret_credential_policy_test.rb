# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OperatorSecretCredentialPolicyTest < ActiveSupport::TestCase
  def setup
    @user = nil
    @record = nil
    @policy = OperatorSecretCredentialPolicy.new(@record, user: @user)
  end

  def test_index
    assert_not @policy.index?
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

  # index?/new?/create? allow any operator actor (registration has no persisted record yet).
  def test_index_and_create_allow_operator
    policy = OperatorSecretCredentialPolicy.new(
      OperatorSecretCredential.new,
      user: Operator.new(
        security_mode_id: SecurityModeConfigurable::ADVANCED, id: 1,
      ),
    )

    assert_predicate policy, :index?
    assert_predicate policy, :create?
    assert_predicate policy, :new?
  end

  def test_index_and_create_deny_other_actor_types
    policy = OperatorSecretCredentialPolicy.new(
      OperatorSecretCredential.new,
      user: Client.new(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        id: 1,
      ),
    )

    assert_not policy.index?
    assert_not policy.create?
  end

  # Per-record actions require ownership (record.staff_id == user.id).
  def test_owner_may_manage_own_record
    owner = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, id: 1)
    record = OperatorSecretCredential.new(staff_id: owner.id)
    policy = OperatorSecretCredentialPolicy.new(record, user: owner)

    assert_predicate policy, :show?
    assert_predicate policy, :update?
    assert_predicate policy, :edit?
    assert_predicate policy, :destroy?
  end

  def test_non_owner_may_not_manage_record
    record = OperatorSecretCredential.new(staff_id: 1)
    policy = OperatorSecretCredentialPolicy.new(
      record,
      user: Operator.new(
        security_mode_id: SecurityModeConfigurable::ADVANCED, id: 2,
      ),
    )

    assert_not policy.show?
    assert_not policy.update?
    assert_not policy.destroy?
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

    assert_equal :where_scope, OperatorSecretCredentialPolicy.new(OperatorSecretCredential.new, user: user).apply_scope(
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

    assert_equal :none_scope, OperatorSecretCredentialPolicy.new(OperatorSecretCredential.new, user: nil).apply_scope(
      relation,
      type: :active_record_relation,
    )
    assert_equal [:none], relation.calls
  end
end
