# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OrgOperatorLifecycleExecuteTest < ActiveSupport::TestCase
  fixtures :operators, :operator_tokens, :operator_token_statuses, :operator_token_kinds,
           :operator_token_binding_methods, :operator_token_dbsc_statuses

  ENTRA_TENANT_ID = "11111111-2222-3333-4444-555555555555"
  ENTRA_OBJECT_ID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

  test "executes approved withdrawal by suspending target operator and revoking sessions" do
    target = operators(:one)
    token = operator_tokens(:one)
    request = approved_request(
      action: OperatorLifecycleRequest::ACTION_WITHDRAW,
      target_operator: target,
      requested_by_operator: target,
    )

    result = OrgOperatorLifecycleExecute.call(request: request, actor: operators(:two))

    assert_predicate result, :success?
    assert_predicate request.reload, :executed?
    assert_not_nil target.reload.withdrawal_started_at
    assert_not_nil target.deactivated_at
    assert_operator target.purge_eligible_at, :>, target.deactivated_at
    assert_predicate token.reload, :revoked?
  end

  test "prevents requester from executing their own request" do
    request = approved_request(
      action: OperatorLifecycleRequest::ACTION_WITHDRAW,
      target_operator: operators(:two),
      requested_by_operator: operators(:one),
    )

    result = OrgOperatorLifecycleExecute.call(request: request, actor: operators(:one))

    assert_not result.success?
    assert_predicate request.reload, :approved?
  end

  test "executes approved join by creating organization invitation" do
    request = OperatorLifecycleRequest.create!(
      action: OperatorLifecycleRequest::ACTION_JOIN,
      status: OperatorLifecycleRequest::STATUS_APPROVED,
      target_email: "invitee@example.com",
      organization_id: 123,
      role_id: 7,
      requested_by_operator: operators(:one),
      approved_by_operator: operators(:two),
      approved_at: Time.current,
    )

    result = OrgOperatorLifecycleExecute.call(request: request, actor: operators(:two))

    assert_predicate result, :success?
    assert_predicate request.reload, :executed?
    assert_equal "invitee@example.com", result.invitation.email
    assert_equal 123, result.invitation.organization_id
    assert_equal 7, result.invitation.role_id
    assert_equal result.invitation.id, request.invitation_id
  end

  test "rejects non-approved requests before execution" do
    target = operators(:one)
    request = OperatorLifecycleRequest.create!(
      action: OperatorLifecycleRequest::ACTION_WITHDRAW,
      status: OperatorLifecycleRequest::STATUS_PENDING,
      target_operator: target,
      requested_by_operator: target,
      reason: "pending",
    )

    result = OrgOperatorLifecycleExecute.call(request: request, actor: operators(:two))

    assert_not result.success?
    assert_match(/Only approved/, result.error)
  end

  test "executes approved terminate by discarding target operator" do
    target = operators(:one)
    token = operator_tokens(:one)
    request = approved_request(
      action: OperatorLifecycleRequest::ACTION_TERMINATE,
      target_operator: target,
      requested_by_operator: target,
    )

    result = OrgOperatorLifecycleExecute.call(request: request, actor: operators(:two))

    assert_predicate result, :success?
    assert_predicate request.reload, :executed?
    assert_not_nil target.reload.withdrawn_at
    assert_not_nil target.deactivated_at
    assert_equal target.discard_at, target.purge_eligible_at
    assert_predicate token.reload, :revoked?
  end

  test "executes approved restore by clearing deactivation dates" do
    target = operators(:one)
    now = Time.current
    target.update!(
      withdrawal_started_at: now,
      deactivated_at: now,
      withdrawn_at: now,
      discard_at: now,
      purge_eligible_at: now,
    )
    request = approved_request(
      action: OperatorLifecycleRequest::ACTION_RESTORE,
      target_operator: target,
      requested_by_operator: target,
    )

    result = OrgOperatorLifecycleExecute.call(request: request, actor: operators(:two))

    assert_predicate result, :success?
    assert_nil target.reload.withdrawal_started_at
    assert_nil target.deactivated_at
    assert_nil target.withdrawn_at
    # Restore resets the discard sentinel to the far-future value (Float::INFINITY),
    # which OrgOperatorLifecycleExecute uses to mark an operator active. Comparing
    # Float::INFINITY with a TimeWithZone via :> raises, so assert the sentinel directly.
    assert_equal Float::INFINITY, target.discard_at
  end

  # A leave of absence is not a departure. This used to share the withdrawal
  # branch, so filing a suspension scheduled the operator for deletion in 31 days
  # and someone away for a quarter came back to a purged record.
  test "suspension blocks sign-in and sets no deletion countdown" do
    target = operators(:one)
    token = operator_tokens(:one)
    request = approved_request(
      action: OperatorLifecycleRequest::ACTION_SUSPEND,
      target_operator: target,
      requested_by_operator: target,
    )

    result = OrgOperatorLifecycleExecute.call(request: request, actor: operators(:two))

    assert_predicate result, :success?
    target.reload

    assert_predicate target, :suspended?
    assert_not target.login_allowed?
    assert_predicate token.reload, :revoked?

    # The record must survive a leave of any length.
    assert_nil target.withdrawal_started_at
    assert_nil target.withdrawn_at
    assert_equal Float::INFINITY, target.discard_at
    assert_equal Float::INFINITY, target.purge_eligible_at
  end

  test "a suspended operator is restored by restore" do
    target = operators(:one)
    suspend_request = approved_request(
      action: OperatorLifecycleRequest::ACTION_SUSPEND,
      target_operator: target,
      requested_by_operator: target,
    )
    OrgOperatorLifecycleExecute.call(request: suspend_request, actor: operators(:two))

    restore_request = approved_request(
      action: OperatorLifecycleRequest::ACTION_RESTORE,
      target_operator: target,
      requested_by_operator: target,
    )
    OrgOperatorLifecycleExecute.call(request: restore_request, actor: operators(:two))

    assert_predicate target.reload, :login_allowed?
  end

  # Withdrawal keeps its countdown; only suspension lost one.
  test "withdrawal still schedules the purge" do
    target = operators(:one)
    request = approved_request(
      action: OperatorLifecycleRequest::ACTION_WITHDRAW,
      target_operator: target,
      requested_by_operator: target,
    )

    OrgOperatorLifecycleExecute.call(request: request, actor: operators(:two))

    target.reload

    assert_not_nil target.withdrawal_started_at
    assert_operator target.purge_eligible_at, :>, target.deactivated_at
    assert_not_equal Float::INFINITY, target.purge_eligible_at
  end

  # Offboarding has to reach the federated credential too. The operator gate
  # already blocks sign-in, but leaving the mapping ACTIVE means a later restore
  # silently re-grants Entra sign-in.
  test "withdrawal withdraws the target's Entra identity without deleting it" do
    target = operators(:one)
    identity = active_entra_identity_for(target)
    request = approved_request(
      action: OperatorLifecycleRequest::ACTION_WITHDRAW,
      target_operator: target,
      requested_by_operator: target,
    )

    OrgOperatorLifecycleExecute.call(request: request, actor: operators(:two))

    assert_equal OperatorEntraIdentityState::SUSPENDED, identity.reload.status_id
    # Logical delete: the mapping and its evidence stay auditable.
    assert_equal ENTRA_OBJECT_ID, identity.entra_object_id
  end

  test "termination revokes the target's Entra identity without deleting it" do
    target = operators(:one)
    identity = active_entra_identity_for(target)
    request = approved_request(
      action: OperatorLifecycleRequest::ACTION_TERMINATE,
      target_operator: target,
      requested_by_operator: target,
    )

    OrgOperatorLifecycleExecute.call(request: request, actor: operators(:two))

    assert_equal OperatorEntraIdentityState::REVOKED, identity.reload.status_id
    assert_equal 1, OperatorEntraIdentity.where(operator_id: target.id).count
  end

  # Restoring an operator returns their own credentials. Re-granting a federated
  # sign-in is a separate decision and must be made explicitly.
  test "restore does not re-grant Entra sign-in" do
    target = operators(:one)
    identity = active_entra_identity_for(target, status_id: OperatorEntraIdentityState::SUSPENDED)
    now = Time.current
    target.update!(
      withdrawal_started_at: now, deactivated_at: now, withdrawn_at: now,
      discard_at: now, purge_eligible_at: now,
    )
    request = approved_request(
      action: OperatorLifecycleRequest::ACTION_RESTORE,
      target_operator: target,
      requested_by_operator: target,
    )

    OrgOperatorLifecycleExecute.call(request: request, actor: operators(:two))

    assert_predicate target.reload, :login_allowed?
    assert_equal OperatorEntraIdentityState::SUSPENDED, identity.reload.status_id
  end

  test "an operator with no Entra identity is unaffected by offboarding" do
    target = operators(:one)
    request = approved_request(
      action: OperatorLifecycleRequest::ACTION_WITHDRAW,
      target_operator: target,
      requested_by_operator: target,
    )

    result = OrgOperatorLifecycleExecute.call(request: request, actor: operators(:two))

    assert_predicate result, :success?
    assert_equal 0, OperatorEntraIdentity.count
  end

  test "suspend fails when target would be the last active operator" do
    target = operators(:one)
    # Deactivate all other operators so :one is the last active
    Operator.where.not(id: target.id).update_all(deactivated_at: Time.current)

    request = approved_request(
      action: OperatorLifecycleRequest::ACTION_WITHDRAW,
      target_operator: target,
      requested_by_operator: operators(:two),
    )

    # Executor must differ from the requester; otherwise the self-execution guard
    # fires before the last-active-operator check this test targets.
    result = OrgOperatorLifecycleExecute.call(request: request, actor: operators(:sample_staff))

    assert_not result.success?
    assert_match(/last active operator/, result.error)
  end

  private

  def active_entra_identity_for(operator, status_id: OperatorEntraIdentityState::ACTIVE)
    OperatorEntraIdentityState.ensure_defaults!
    OperatorEntraIdentity.create!(
      operator_id: operator.id,
      entra_tenant_id: ENTRA_TENANT_ID,
      entra_object_id: ENTRA_OBJECT_ID,
      status_id: status_id,
    )
  end

  def approved_request(action:, target_operator:, requested_by_operator:)
    OperatorLifecycleRequest.create!(
      action: action,
      status: OperatorLifecycleRequest::STATUS_APPROVED,
      target_operator: target_operator,
      requested_by_operator: requested_by_operator,
      approved_by_operator: operators(:two),
      approved_at: Time.current,
      reason: "approved",
    )
  end
end
