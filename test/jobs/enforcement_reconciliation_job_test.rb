# typed: false
# frozen_string_literal: true

require "test_helper"

class EnforcementReconciliationJobTest < ActiveJob::TestCase
  test "reconciles a case whose sessions_revoked_at and audited_at are still nil after apply!" do
    client = clients(:one)
    operator = operators(:one)
    token = ClientToken.create!(user_id: client.id, established_authentication_method: "passkey")

    the_case = AppEnforcementCase.new(
      kind: "method_protection",
      duration_mode: "indefinite",
      visibility: "visible",
      release_mode: "operator",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator.public_id,
    )
    the_case.authentication_method_effects.build(
      principal_public_id: client.public_id,
      authentication_method: "passkey",
      effect: "unusable",
      effective_at: Time.current,
    )
    EnforcementCaseApplyOperation.call(enforcement_case: the_case)

    # Simulate a prior partial failure: the state transition committed, but
    # the convergent side effects never ran.
    the_case.update_columns(sessions_revoked_at: nil, audited_at: nil) # rubocop:disable Rails/SkipsModelValidations

    EnforcementReconciliationJob.perform_now

    token.reload
    the_case.reload

    assert_predicate token, :revoked?
    assert_predicate the_case.sessions_revoked_at, :present?
    assert_predicate the_case.audited_at, :present?
  end

  test "pending_convergence only selects active cases with an unconverged side effect" do
    client = clients(:one)
    operator = operators(:one)

    converged_case = AppEnforcementCase.new(
      kind: "cooldown",
      duration_mode: "timed",
      visibility: "visible",
      release_mode: "automatic",
      effective_at: Time.current,
      expires_at: 1.day.from_now,
      reason_code: "abuse",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator.public_id,
    )
    EnforcementCaseApplyOperation.call(enforcement_case: converged_case)

    assert_includes AppEnforcementCase.where(id: converged_case.id).to_a, converged_case
    assert_not_includes AppEnforcementCase.pending_convergence.to_a, converged_case
  end

  test "ended cases use end convergence instead of the active-case reconciler" do
    client = clients(:one)
    operator = operators(:one)

    ended_case = AppEnforcementCase.new(
      kind: "cooldown",
      duration_mode: "timed",
      visibility: "visible",
      release_mode: "automatic",
      effective_at: Time.current,
      expires_at: 1.day.from_now,
      reason_code: "abuse",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator.public_id,
    )
    EnforcementCaseApplyOperation.call(enforcement_case: ended_case)
    ended_case.update_columns(ended_at: Time.current, end_reason: "revoked", audited_at: nil) # rubocop:disable Rails/SkipsModelValidations

    assert_not_includes AppEnforcementCase.pending_convergence.to_a, ended_case
    assert_includes AppEnforcementCase.pending_end_convergence.to_a, ended_case
  end
end
