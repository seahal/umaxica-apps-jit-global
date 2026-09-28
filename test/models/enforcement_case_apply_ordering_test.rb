# typed: false
# frozen_string_literal: true

require "test_helper"

# adr/unified-enforcement.md: apply! commits the state change in a transaction and then performs
# its side effects outside it, deliberately. A committed security decision must never be rolled
# back because a downstream effect failed, and end_case! must not release a lock another Case is
# still holding.
#
# These are the two guarantees that survive no matter where apply! and end_case! live, so they are
# pinned before #871 moves them into app/operations. Both use real failures rather than stubbed
# collaborators, per generic/no-test-only-code.mdc.
class EnforcementCaseApplyOrderingTest < ActiveSupport::TestCase
  test "a side effect failing after the transaction leaves the case active" do
    client = clients(:one)

    # A real failure with no stubbing: perform_principal_access_effect! resolves the operator with
    # find_by!, and presence is all the model validates about that column.
    the_case = blocking_case_for(client, operator_public_id: "operator-that-does-not-exist")

    assert_raises(ActiveRecord::RecordNotFound) { EnforcementCaseApplyOperation.call(enforcement_case: the_case, actor_operator_public_id: the_case.applied_by_operator_public_id) }

    the_case.reload

    assert_equal "active", the_case.state,
                 "the state change committed before the side effect ran and must not be rolled back"
    assert_nil the_case.sessions_revoked_at, "the raise happened before the later side effects"
    assert_not_predicate client.reload, :admin_locked?
  end

  test "end_case! leaves the account locked while another blocking case is still in force" do
    client = clients(:one)
    operator = operators(:one)

    first = blocking_case_for(client, operator_public_id: operator.public_id)
    EnforcementCaseApplyOperation.call(
      enforcement_case: first,
      actor_operator_public_id: first.applied_by_operator_public_id,
    )
    second = blocking_case_for(client, operator_public_id: operator.public_id)
    EnforcementCaseApplyOperation.call(
      enforcement_case: second,
      actor_operator_public_id: second.applied_by_operator_public_id,
    )

    assert_predicate client.reload, :admin_locked?

    EnforcementCaseEndOperation.call(
      enforcement_case: first, reason: "revoked",
      ended_by_operator_public_id: operator.public_id,
    )

    assert_predicate client.reload, :admin_locked?,
                     "the refcount rule: the second Case still holds the lock"

    EnforcementCaseEndOperation.call(
      enforcement_case: second, reason: "revoked",
      ended_by_operator_public_id: operator.public_id,
    )

    assert_not_predicate client.reload, :admin_locked?
  end

  private

  def blocking_case_for(client, operator_public_id:)
    the_case = AppEnforcementCase.new(
      kind: "temporary_freeze",
      duration_mode: "timed",
      visibility: "visible",
      release_mode: "operator",
      effective_at: Time.current,
      expires_at: 1.day.from_now,
      reason_code: "security_incident",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator_public_id,
    )
    the_case.build_principal_effect(
      principal_public_id: client.public_id,
      access_blocking: true,
      effective_at: Time.current,
    )
    the_case
  end
end
