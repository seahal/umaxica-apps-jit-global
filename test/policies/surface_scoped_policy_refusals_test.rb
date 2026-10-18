# typed: false
# frozen_string_literal: true

require "test_helper"

# Policies that answer per surface have to refuse an input they do not serve
# rather than fall through to a permissive default. Each case below is a record,
# actor type or class the policy was never taught about; letting any of them
# through would authorise a cross-surface read or write.
class SurfaceScopedPolicyRefusalsTest < ActiveSupport::TestCase
  fixtures :operators, :operator_statuses

  test "a record type the membership policy does not serve is refused rather than allowed" do
    policy = OrganizationMembershipPolicy.new(Object.new, user: operators(:one))

    assert_not policy.manage_memberships?
    assert_not policy.index?
    assert_not policy.destroy?
  end

  test "an anonymous caller manages no memberships" do
    assert_not OrganizationMembershipPolicy.new(Object.new, user: nil).manage_memberships?
  end

  # Lifecycle requests are staff-only, and an operator may never approve or
  # execute their own -- that separation is the whole point of the request.
  test "lifecycle requests are refused to anyone who is not an operator" do
    request = Struct.new(:requested_by_operator_id, :pending?, :approved?).new(1, true, true)
    client = Client.create!(status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER)
    policy = OperatorLifecycleRequestPolicy.new(request, user: client)

    assert_not policy.index?
    assert_not policy.show?
    assert_not policy.create?
    assert_not policy.approve?
    assert_not policy.execute?
  end

  # The lifecycle policy is closed until operator-to-operator capabilities are specified.
  test "an operator can neither raise nor action a lifecycle request, their own or another's" do
    operator = operators(:one)
    own = Struct.new(:requested_by_operator_id, :pending?, :approved?).new(operator.id, true, true)
    someone_elses = Struct.new(:requested_by_operator_id, :pending?, :approved?).new(operator.id + 1, true, true)

    own_policy = OperatorLifecycleRequestPolicy.new(own, user: operator)

    assert_not own_policy.index?
    assert_not own_policy.create?
    assert_not own_policy.approve?

    others_policy = OperatorLifecycleRequestPolicy.new(someone_elses, user: operator)

    assert_not others_policy.approve?
    assert_not others_policy.reject?
    assert_not others_policy.execute?
  end

  test "an unapproved request cannot be executed even by another operator" do
    unapproved = Struct.new(:requested_by_operator_id, :pending?, :approved?).new(operators(:one).id + 1, true, false)

    assert_not OperatorLifecycleRequestPolicy.new(unapproved, user: operators(:one)).execute?
  end
end
