# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Object-level authorization for the com (visitor) secret-credential management.
# Listing/registration allow any visitor actor; per-record actions require visitor ownership
# (record.visitor_id == user.id). ApplicationPolicy#owner? does not resolve visitor_id, so the
# policy overrides it -- these tests pin that behavior.
class VisitorSecretCredentialPolicyTest < ActiveSupport::TestCase
  def setup
    @user = nil
    @record = nil
    @policy = VisitorSecretCredentialPolicy.new(@record, user: @user)
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

  def test_destroy
    assert_not @policy.destroy?
  end

  def test_index_and_create_allow_visitor
    policy = VisitorSecretCredentialPolicy.new(
      VisitorSecretCredential.new,
      user: Visitor.new(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        id: 1,
      ),
    )

    assert_predicate policy, :index?
    assert_predicate policy, :create?
    assert_predicate policy, :new?
  end

  def test_index_and_create_deny_other_actor_types
    policy = VisitorSecretCredentialPolicy.new(
      VisitorSecretCredential.new,
      user: Client.new(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        id: 1,
      ),
    )

    assert_not policy.index?
    assert_not policy.create?
  end

  # Per-record actions require ownership (record.visitor_id == user.id).
  def test_owner_may_manage_own_record
    owner = Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1)
    record = VisitorSecretCredential.new(visitor_id: owner.id)
    policy = VisitorSecretCredentialPolicy.new(record, user: owner)

    assert_predicate policy, :show?
    assert_predicate policy, :update?
    assert_predicate policy, :edit?
    assert_predicate policy, :destroy?
    assert_predicate policy, :regenerate?
  end

  def test_non_owner_may_not_manage_record
    record = VisitorSecretCredential.new(visitor_id: 1)
    policy = VisitorSecretCredentialPolicy.new(
      record,
      user: Visitor.new(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        id: 2,
      ),
    )

    assert_not policy.show?
    assert_not policy.update?
    assert_not policy.destroy?
    assert_not policy.regenerate?
  end
end
