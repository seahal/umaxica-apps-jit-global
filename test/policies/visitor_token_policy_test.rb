# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Object-level authorization for the com (visitor) session listing.
# index? allows only the owning actor type (Visitor); all other defaults stay deny-all.
class VisitorTokenPolicyTest < ActiveSupport::TestCase
  def setup
    @user = nil
    @record = nil
    @policy = VisitorTokenPolicy.new(@record, user: @user)
  end

  def test_index
    assert_not @policy.index?
  end

  def test_index_allows_visitor
    assert_predicate VisitorTokenPolicy.new(nil, user: Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL)),
                     :index?
  end

  def test_index_denies_other_actor_types
    assert_not VisitorTokenPolicy.new(nil, user: Client.new(security_mode_id: SecurityModeConfigurable::NORMAL)).index?
    assert_not VisitorTokenPolicy.new(nil, user: Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED)).index?
  end

  def test_destroy_allows_owner_visitor_token
    visitor = Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 123)
    token = VisitorToken.new(visitor_id: visitor.id)

    assert_predicate VisitorTokenPolicy.new(token, user: visitor), :destroy?
  end

  def test_destroy_denies_other_visitor_token
    visitor = Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 123)
    token = VisitorToken.new(visitor_id: 456)

    assert_not VisitorTokenPolicy.new(token, user: visitor).destroy?
  end

  def test_destroy_denies_other_actor_types
    token = VisitorToken.new(visitor_id: 123)

    assert_not VisitorTokenPolicy.new(
      token,
      user: Client.new(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        id: 123,
      ),
    ).destroy?
    assert_not VisitorTokenPolicy.new(
      token,
      user: Operator.new(
        security_mode_id: SecurityModeConfigurable::ADVANCED,
        id: 123,
      ),
    ).destroy?
  end

  def test_revoke_others_allows_visitor_token_class_for_visitor
    assert_predicate VisitorTokenPolicy.new(VisitorToken, user: Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL)),
                     :revoke_others?
  end

  def test_revoke_others_denies_non_visitors_and_instances
    assert_not VisitorTokenPolicy.new(VisitorToken, user: Client.new(security_mode_id: SecurityModeConfigurable::NORMAL)).revoke_others?
    assert_not VisitorTokenPolicy.new(VisitorToken, user: Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED)).revoke_others?
    assert_not VisitorTokenPolicy.new(VisitorToken.new, user: Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL)).revoke_others?
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
end
