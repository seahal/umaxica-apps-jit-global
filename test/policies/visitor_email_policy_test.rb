# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Object-level authorization for the com (visitor) email listing.
# index? allows only the owning actor type (Visitor); all other defaults stay deny-all.
class VisitorEmailPolicyTest < ActiveSupport::TestCase
  def setup
    @user = nil
    @record = nil
    @policy = VisitorEmailPolicy.new(@record, user: @user)
  end

  def test_index
    assert_not @policy.index?
  end

  def test_index_allows_visitor
    assert_predicate VisitorEmailPolicy.new(nil, user: Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL)),
                     :index?
  end

  def test_index_denies_other_actor_types
    assert_not VisitorEmailPolicy.new(nil, user: Client.new(security_mode_id: SecurityModeConfigurable::NORMAL)).index?
    assert_not VisitorEmailPolicy.new(nil, user: Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED)).index?
  end

  def test_show
    assert_not @policy.show?
  end

  def test_create
    assert_not @policy.create?
  end

  def test_update
    assert_not @policy.update?
  end

  def test_destroy
    assert_not @policy.destroy?
  end

  # create? gates registration (fresh record) to the owning actor type.
  def test_create_allows_visitor
    assert_predicate VisitorEmailPolicy.new(nil, user: Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL)),
                     :create?
    assert_predicate VisitorEmailPolicy.new(nil, user: Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL)),
                     :new?
  end

  def test_create_denies_other_actor_types
    assert_not VisitorEmailPolicy.new(nil, user: Client.new(security_mode_id: SecurityModeConfigurable::NORMAL)).create?
    assert_not VisitorEmailPolicy.new(nil, user: Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED)).create?
  end

  # update?/destroy? require ownership of the specific record (record.visitor_id == visitor.id).
  def test_update_and_destroy_allow_owner
    owner = Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1)
    record = VisitorEmail.new(visitor_id: 1)

    assert_predicate VisitorEmailPolicy.new(record, user: owner), :update?
    assert_predicate VisitorEmailPolicy.new(record, user: owner), :edit?
    assert_predicate VisitorEmailPolicy.new(record, user: owner), :destroy?
  end

  def test_update_and_destroy_deny_non_owner
    owner = Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1)
    record = VisitorEmail.new(visitor_id: 2)

    assert_not VisitorEmailPolicy.new(record, user: owner).update?
    assert_not VisitorEmailPolicy.new(record, user: owner).destroy?
  end
end
