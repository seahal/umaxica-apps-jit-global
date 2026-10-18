# typed: false
# frozen_string_literal: true

require "test_helper"

class OrgEnforcementCaseTest < ActiveSupport::TestCase
  test "org realm supports entra as an authentication method" do
    operator = operators(:one)
    target = operators(:two)

    the_case = OrgEnforcementCase.create!(
      kind: "method_protection",
      duration_mode: "indefinite",
      visibility: "visible",
      release_mode: "operator",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: target.public_id,
      applied_by_operator_public_id: operator.public_id,
    )

    effect = the_case.authentication_method_effects.create!(
      principal_public_id: target.public_id,
      authentication_method: "entra",
      effect: "mutation_locked",
      effective_at: Time.current,
    )

    assert_predicate effect, :persisted?
  end

  test "a permanent_ban targeting an Operator requires approval even when visible" do
    operator = operators(:one)
    target = operators(:two)

    the_case = OrgEnforcementCase.new(
      kind: "permanent_ban",
      duration_mode: "permanent",
      visibility: "visible",
      release_mode: "break_glass_only",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: target.public_id,
      applied_by_operator_public_id: operator.public_id,
    )

    assert_predicate the_case, :requires_approval?
    assert_raises(EnforcementCaseApplicable::ApprovalRequiredError) { EnforcementCaseApplyOperation.call(enforcement_case: the_case, actor_operator_public_id: the_case.applied_by_operator_public_id) }
  end

  test "an approved permanent_ban targeting an Operator applies successfully" do
    operator = operators(:one)
    approver = operators(:two)
    target = operators(:sample_staff)

    the_case = OrgEnforcementCase.new(
      kind: "permanent_ban",
      duration_mode: "permanent",
      visibility: "visible",
      release_mode: "break_glass_only",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: target.public_id,
      applied_by_operator_public_id: operator.public_id,
      approved_by_operator_public_id: approver.public_id,
    )
    the_case.build_principal_effect(
      principal_public_id: target.public_id,
      access_blocking: true,
      principal_hard_delete_blocked: true,
      effective_at: Time.current,
    )

    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )
    target.reload

    assert_equal "active", the_case.state
    assert_predicate target, :admin_locked?
  end
end
