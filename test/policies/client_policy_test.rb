# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ClientPolicyTest < ActiveSupport::TestCase
  fixtures :clients, :operators

  class MockRecord
    attr_accessor :user_id

    def initialize(user_id = nil)
      @user_id = user_id
    end
  end

  def test_index_with_staff_and_admin_or_manager
    staff = operators(:one)
    policy = ClientPolicy.new(MockRecord.new, user: staff)
    policy.define_singleton_method(:operator_or_manager?) { true }

    assert_predicate policy, :index?
  end

  def test_index_with_staff_without_admin_or_manager
    staff = operators(:one)
    policy = ClientPolicy.new(MockRecord.new, user: staff)
    policy.define_singleton_method(:operator_or_manager?) { false }

    assert_not policy.index?
  end

  def test_index_with_user
    user = clients(:one)
    policy = ClientPolicy.new(MockRecord.new, user: user)

    assert_not policy.index?
  end

  def test_index_with_nil_actor
    policy = ClientPolicy.new(MockRecord.new, user: nil)

    assert_not policy.index?
  end

  def test_show_with_owner
    user = clients(:one)
    record = MockRecord.new(user.id)
    policy = ClientPolicy.new(record, user: user)

    assert_predicate policy, :show?
  end

  def test_show_with_staff_and_admin_or_manager
    staff = operators(:one)
    policy = ClientPolicy.new(MockRecord.new, user: staff)
    policy.define_singleton_method(:operator_or_manager?) { true }

    assert_predicate policy, :show?
  end

  def test_show_with_staff_without_admin_or_manager
    staff = operators(:one)
    policy = ClientPolicy.new(MockRecord.new, user: staff)
    policy.define_singleton_method(:operator_or_manager?) { false }

    assert_not policy.show?
  end

  def test_show_with_non_owner_user
    user = clients(:one)
    other_user = clients(:two)
    record = MockRecord.new(other_user.id)
    policy = ClientPolicy.new(record, user: user)

    assert_not policy.show?
  end

  def test_create_with_staff_and_admin
    staff = operators(:one)
    policy = ClientPolicy.new(MockRecord.new, user: staff)
    policy.define_singleton_method(:operator?) { true }

    assert_predicate policy, :create?
  end

  def test_create_with_staff_without_admin
    staff = operators(:one)
    policy = ClientPolicy.new(MockRecord.new, user: staff)
    policy.define_singleton_method(:operator?) { false }

    assert_not policy.create?
  end

  def test_create_with_user
    user = clients(:one)
    policy = ClientPolicy.new(MockRecord.new, user: user)

    assert_not policy.create?
  end

  def test_update_with_owner
    user = clients(:one)
    record = MockRecord.new(user.id)
    policy = ClientPolicy.new(record, user: user)

    assert_predicate policy, :update?
  end

  def test_update_with_staff_and_admin_or_manager
    staff = operators(:one)
    policy = ClientPolicy.new(MockRecord.new, user: staff)
    policy.define_singleton_method(:operator_or_manager?) { true }

    assert_predicate policy, :update?
  end

  def test_update_with_staff_without_admin_or_manager
    staff = operators(:one)
    policy = ClientPolicy.new(MockRecord.new, user: staff)
    policy.define_singleton_method(:operator_or_manager?) { false }

    assert_not policy.update?
  end

  def test_update_with_non_owner_user
    user = clients(:one)
    other_user = clients(:two)
    record = MockRecord.new(other_user.id)
    policy = ClientPolicy.new(record, user: user)

    assert_not policy.update?
  end

  def test_destroy_with_owner_user
    user = clients(:one)
    record = MockRecord.new(user.id)
    policy = ClientPolicy.new(record, user: user)

    assert_predicate policy, :destroy?
  end

  def test_destroy_with_staff_and_admin
    staff = operators(:one)
    policy = ClientPolicy.new(MockRecord.new, user: staff)
    policy.define_singleton_method(:operator?) { true }

    assert_predicate policy, :destroy?
  end

  def test_destroy_with_staff_without_admin
    staff = operators(:one)
    policy = ClientPolicy.new(MockRecord.new, user: staff)
    policy.define_singleton_method(:operator?) { false }

    assert_not policy.destroy?
  end

  def test_destroy_with_non_owner_user
    user = clients(:one)
    other_user = clients(:two)
    record = MockRecord.new(other_user.id)
    policy = ClientPolicy.new(record, user: user)

    assert_not policy.destroy?
  end

  def test_new_delegates_to_create
    policy = ClientPolicy.new(MockRecord.new, user: nil)

    assert_equal policy.send(:create?), policy.send(:new?)
  end

  def test_edit_delegates_to_update
    policy = ClientPolicy.new(MockRecord.new, user: nil)

    assert_equal policy.send(:update?), policy.send(:edit?)
  end

  def test_purge_sessions_is_operator_only
    staff = operators(:one)

    assert_predicate ClientPolicy.new(MockRecord.new, user: staff), :purge_sessions?
    assert_not ClientPolicy.new(MockRecord.new, user: clients(:one)).purge_sessions?
  end

  def test_relation_scope_filters_by_actor_type
    relation = Class.new do
      attr_reader :calls

      def initialize
        @calls = []
      end

      def all
        @calls << :all
        :all_scope
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

    manager = operators(:one)
    manager_policy = ClientPolicy.new(MockRecord.new, user: manager)
    manager_policy.define_singleton_method(:operator_or_manager?) { true }

    assert_equal :all_scope, manager_policy.apply_scope(relation, type: :active_record_relation)
    assert_equal [:all], relation.calls

    relation = relation.class.new
    client = clients(:one)
    client_policy = ClientPolicy.new(MockRecord.new, user: client)

    assert_equal :where_scope, client_policy.apply_scope(relation, type: :active_record_relation)
    assert_equal [[:where, { id: client.id }]], relation.calls

    relation = relation.class.new

    assert_equal :none_scope, ClientPolicy.new(MockRecord.new, user: nil).apply_scope(
      relation,
      type: :active_record_relation,
    )
    assert_equal [:none], relation.calls
  end
end
