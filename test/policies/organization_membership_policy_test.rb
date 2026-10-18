# typed: false
# frozen_string_literal: true

require "test_helper"

class OrganizationMembershipPolicyTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "app client can manage memberships in its own enterprise" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: client)
    membership = bootstrap.account.current_memberships.first

    assert_predicate OrganizationMembershipPolicy.new(bootstrap.collective, user: client), :index?
    assert_predicate OrganizationMembershipPolicy.new(membership, user: client), :update?
  end

  test "app client cannot manage memberships in another enterprise" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    other_client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    other_bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: other_client)

    assert_not OrganizationMembershipPolicy.new(other_bootstrap.collective, user: client).index?
    assert_not OrganizationMembershipPolicy.new(other_bootstrap.account.current_memberships.first, user: client).update?
  end

  test "nil actor is denied" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: client)

    assert_not OrganizationMembershipPolicy.new(bootstrap.collective, user: nil).index?
  end

  # Holding a membership (even the OWNER kind the selector bootstrap assigns) lets an operator read
  # their bureau's roster, not change it: who may change org memberships is not yet decided.
  test "org operator can read but not change memberships in its own bureau" do
    operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :org, principal: operator)
    membership = bootstrap.account.current_memberships.first

    assert_predicate OrganizationMembershipPolicy.new(bootstrap.collective, user: operator), :index?
    assert_predicate OrganizationMembershipPolicy.new(membership, user: operator), :show?
    assert_not OrganizationMembershipPolicy.new(bootstrap.collective, user: operator).create?
    assert_not OrganizationMembershipPolicy.new(membership, user: operator).update?
    assert_not OrganizationMembershipPolicy.new(membership, user: operator).destroy?
  end

  test "visitor cannot manage app enterprise memberships" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: client)

    assert_not OrganizationMembershipPolicy.new(bootstrap.collective, user: visitor).index?
  end
end
