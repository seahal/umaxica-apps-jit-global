# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OrgOperatorLifecycleRequestCreateTest < ActiveSupport::TestCase
  fixtures :operators, :organization_statuses

  test "creates withdrawal request for requesting operator when target is omitted" do
    actor = operators(:one)

    result = OrgOperatorLifecycleRequestCreate.call(
      actor: actor,
      attributes: {
        action: OperatorLifecycleRequest::ACTION_WITHDRAW,
        reason: "leaving org",
      },
    )

    assert_predicate result, :success?
    assert_equal actor, result.request.requested_by_operator
    assert_equal actor, result.request.target_operator
    assert_equal OperatorLifecycleRequest::STATUS_PENDING, result.request.status
  end

  test "rejects non join request when target operator is unknown" do
    result = OrgOperatorLifecycleRequestCreate.call(
      actor: operators(:one),
      attributes: {
        action: OperatorLifecycleRequest::ACTION_SUSPEND,
        target_operator_public_id: "UNKNOWN",
      },
    )

    assert_not result.success?
    assert_predicate result.request.errors[:target_operator], :present?
  end

  test "creates join request when actor owns the organization" do
    org = OperatorOrganization.create!(
      name: "Owned Corp",
      domain: "owned-corp-#{SecureRandom.hex(4)}",
      operator_id: operators(:one).id,
      workspace_status_id: organization_statuses(:nothing).id,
    )

    result = OrgOperatorLifecycleRequestCreate.call(
      actor: operators(:one),
      attributes: {
        action: OperatorLifecycleRequest::ACTION_JOIN,
        target_email: " INVITEE@EXAMPLE.COM ",
        organization_id: org.id,
        role_id: 4,
      },
    )

    assert_predicate result, :success?
    assert_equal "invitee@example.com", result.request.target_email
    assert_equal org.id, result.request.organization_id
    assert_equal 4, result.request.role_id
  end

  test "join request is rejected when actor does not own the organization" do
    org = OperatorOrganization.create!(
      name: "Foreign Corp",
      domain: "foreign-corp-#{SecureRandom.hex(4)}",
      operator_id: operators(:two).id,
      workspace_status_id: organization_statuses(:nothing).id,
    )

    result = OrgOperatorLifecycleRequestCreate.call(
      actor: operators(:one),
      attributes: {
        action: OperatorLifecycleRequest::ACTION_JOIN,
        target_email: "invitee@example.com",
        organization_id: org.id,
        role_id: 4,
      },
    )

    assert_not result.success?
    assert_predicate result.request.errors[:organization_id], :present?
  end

  test "join request is rejected when the organization does not exist" do
    result = OrgOperatorLifecycleRequestCreate.call(
      actor: operators(:one),
      attributes: {
        action: OperatorLifecycleRequest::ACTION_JOIN,
        target_email: "invitee@example.com",
        organization_id: 999_999_999,
        role_id: 4,
      },
    )

    assert_not result.success?
    assert_predicate result.request.errors[:organization_id], :present?
  end
end
