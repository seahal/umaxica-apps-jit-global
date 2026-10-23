# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Object-level authorization for the com (visitor) passkey listing.
# index? allows any authenticated actor reaching the surface; nil is denied. Other defaults
# stay deny-all (allowlist).
class VisitorPasskeyPolicyTest < ActiveSupport::TestCase
  def test_index_denied_for_nil_user
    policy = VisitorPasskeyPolicy.new(VisitorPasskey.new, user: nil)

    assert_not policy.index?
  end

  def test_index_allowed_for_authenticated_user
    policy = VisitorPasskeyPolicy.new(
      VisitorPasskey.new,
      user: Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1),
    )

    assert_predicate policy, :index?
  end

  def test_show_denied_by_default
    policy = VisitorPasskeyPolicy.new(
      VisitorPasskey.new,
      user: Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1),
    )

    assert_not policy.show?
  end

  # create? gates registration (fresh record) to any authenticated visitor.
  def test_create_allowed_for_authenticated_user
    policy = VisitorPasskeyPolicy.new(
      VisitorPasskey.new,
      user: Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1),
    )

    assert_predicate policy, :create?
    assert_predicate policy, :new?
  end

  def test_create_denied_for_nil_user
    assert_not VisitorPasskeyPolicy.new(VisitorPasskey.new, user: nil).create?
  end

  # show?/update?/destroy? require ownership (record.visitor_id == visitor.id).
  def test_per_record_rules_allow_owner
    owner = Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1)
    record = VisitorPasskey.new(visitor_id: 1)

    assert_predicate VisitorPasskeyPolicy.new(record, user: owner), :show?
    assert_predicate VisitorPasskeyPolicy.new(record, user: owner), :update?
    assert_predicate VisitorPasskeyPolicy.new(record, user: owner), :edit?
    assert_predicate VisitorPasskeyPolicy.new(record, user: owner), :destroy?
  end

  def test_per_record_rules_deny_non_owner
    owner = Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1)
    record = VisitorPasskey.new(visitor_id: 2)

    assert_not VisitorPasskeyPolicy.new(record, user: owner).show?
    assert_not VisitorPasskeyPolicy.new(record, user: owner).update?
    assert_not VisitorPasskeyPolicy.new(record, user: owner).destroy?
  end
end
