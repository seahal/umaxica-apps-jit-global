# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class VisitorPolicyTest < ActiveSupport::TestCase
  class MockRecord
    attr_reader :id

    def initialize(id)
      @id = id
    end
  end

  def test_purge_sessions_allows_staff_only
    staff = build_actor(Operator, 20)
    policy = VisitorPolicy.new(MockRecord.new(20), user: staff)

    assert_predicate policy, :purge_sessions?

    visitor = build_actor(Visitor, 20)
    policy = VisitorPolicy.new(MockRecord.new(20), user: visitor)

    assert_not policy.purge_sessions?
  end

  def test_purge_sessions_denies_nil_user
    policy = VisitorPolicy.new(MockRecord.new(1), user: nil)

    assert_not policy.purge_sessions?
  end

  def test_purge_session_denies_client
    client = build_actor(Client, 1)
    policy = VisitorPolicy.new(MockRecord.new(1), user: client)

    assert_not policy.purge_sessions?
  end

  def test_index_denied_by_default
    policy = VisitorPolicy.new(MockRecord.new(1), user: build_actor(Visitor, 1))

    assert_not policy.index?
  end

  def test_show_denied_by_default
    policy = VisitorPolicy.new(MockRecord.new(1), user: build_actor(Visitor, 1))

    assert_not policy.show?
  end

  # show? gates owner-only viewing of account attributes (e.g. the birthdate page).
  def test_show_allows_owner_visitor
    owner = Visitor.new(id: 1)
    policy = VisitorPolicy.new(owner, user: owner)

    assert_predicate policy, :show?
  end

  def test_show_denies_different_visitor
    owner = Visitor.new(id: 1)
    other = Visitor.new(id: 2)
    policy = VisitorPolicy.new(owner, user: other)

    assert_not policy.show?
  end

  def test_create_denied_by_default
    policy = VisitorPolicy.new(MockRecord.new(1), user: build_actor(Visitor, 1))

    assert_not policy.create?
  end

  def test_update_denied_by_default
    policy = VisitorPolicy.new(MockRecord.new(1), user: build_actor(Visitor, 1))

    assert_not policy.update?
  end

  # update? gates owner-only mutation of account attributes (e.g. the MFA level page).
  def test_update_allows_owner_visitor
    owner = Visitor.new(id: 1)
    policy = VisitorPolicy.new(owner, user: owner)

    assert_predicate policy, :update?
  end

  def test_update_denies_different_visitor
    owner = Visitor.new(id: 1)
    other = Visitor.new(id: 2)
    policy = VisitorPolicy.new(owner, user: other)

    assert_not policy.update?
  end

  def test_destroy_denied_by_default
    policy = VisitorPolicy.new(MockRecord.new(1), user: build_actor(Visitor, 1))

    assert_not policy.destroy?
  end

  private

  def build_actor(type_class, id)
    actor = Object.new
    actor.define_singleton_method(:id) { id }
    actor.define_singleton_method(:is_a?) do |klass|
      klass == type_class || super(klass)
    end
    actor
  end
end
