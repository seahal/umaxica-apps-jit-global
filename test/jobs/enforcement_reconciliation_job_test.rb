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
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )

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
    EnforcementCaseApplyOperation.call(
      enforcement_case: converged_case,
      actor_operator_public_id: converged_case.applied_by_operator_public_id,
    )

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
    EnforcementCaseApplyOperation.call(
      enforcement_case: ended_case,
      actor_operator_public_id: ended_case.applied_by_operator_public_id,
    )
    ended_case.update_columns(ended_at: Time.current, end_reason: "revoked", audited_at: nil) # rubocop:disable Rails/SkipsModelValidations

    assert_not_includes AppEnforcementCase.pending_convergence.to_a, ended_case
    assert_includes AppEnforcementCase.pending_end_convergence.to_a, ended_case
  end

  test "records the end audit event for an ended case whose end convergence never ran" do
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
    EnforcementCaseApplyOperation.call(
      enforcement_case: ended_case,
      actor_operator_public_id: ended_case.applied_by_operator_public_id,
    )
    ended_case.update_columns(ended_at: Time.current, end_reason: "revoked", audited_at: nil) # rubocop:disable Rails/SkipsModelValidations

    EnforcementReconciliationJob.perform_now

    assert ended_case.audit_event_recorded?("ended")
  end

  test "ends an active case whose approved appeal did not finish ending it" do
    client = clients(:one)
    operator = operators(:one)
    the_case = AppEnforcementCase.new(
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
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )
    AppEnforcementAppeal.create!(
      enforcement_case: the_case,
      reason_code: "incorrect_decision",
      statement: "Please review the decision.", # rubocop:disable I18n/RailsI18n/DecorateString -- Fixed fixture copy.
      submitted_at: Time.current,
      state: "approved",
      reviewer_operator_public_id: "operator-reviewer",
    )

    EnforcementReconciliationJob.perform_now

    the_case.reload

    assert_predicate the_case.ended_at, :present?
    assert_equal "appeal_approved", the_case.end_reason
    assert_equal "operator-reviewer", the_case.ended_by_operator_public_id
    assert the_case.audit_event_recorded?("appeal_approved")
  end

  test "completes the end audit for an approved appeal whose case already ended" do
    client = clients(:one)
    operator = operators(:one)
    the_case = AppEnforcementCase.new(
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
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )
    ended_at = 1.minute.ago.change(usec: 0)
    the_case.update_columns(ended_at: ended_at, end_reason: "appeal_approved") # rubocop:disable Rails/SkipsModelValidations
    AppEnforcementAppeal.create!(
      enforcement_case: the_case,
      reason_code: "incorrect_decision",
      statement: "Please review the decision.", # rubocop:disable I18n/RailsI18n/DecorateString -- Fixed fixture copy.
      submitted_at: Time.current,
      state: "approved",
      reviewer_operator_public_id: "operator-reviewer",
    )

    EnforcementReconciliationJob.perform_now

    the_case.reload

    assert_equal ended_at, the_case.ended_at
    assert the_case.audit_event_recorded?("ended")
    assert the_case.audit_event_recorded?("appeal_approved")
  end

  test "records a rejected appeal without ending the case" do
    client = clients(:one)
    operator = operators(:one)
    the_case = AppEnforcementCase.new(
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
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )
    AppEnforcementAppeal.create!(
      enforcement_case: the_case,
      reason_code: "incorrect_decision",
      statement: "Please review the decision.", # rubocop:disable I18n/RailsI18n/DecorateString -- Fixed fixture copy.
      submitted_at: Time.current,
      state: "rejected",
      reviewer_operator_public_id: "operator-reviewer",
    )

    EnforcementReconciliationJob.perform_now

    the_case.reload

    assert_nil the_case.ended_at
    assert the_case.audit_event_recorded?("appeal_rejected")
  end

  test "logs a failed end reconciliation instead of aborting the job" do
    client = clients(:one)
    operator = operators(:one)
    the_case = AppEnforcementCase.new(
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
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )
    the_case.update_columns(ended_at: Time.current, end_reason: "revoked", audited_at: nil) # rubocop:disable Rails/SkipsModelValidations
    failing_operation = Object.new
    failing_operation.define_singleton_method(:reconcile) { raise ActiveRecord::ConnectionNotEstablished, "chronicle down" }
    logged = []

    Rails.logger.stub(:error, ->(message) { logged << message }) do
      EnforcementCaseEndOperation.stub(:new, failing_operation) do
        assert_nothing_raised { EnforcementReconciliationJob.perform_now }
      end
    end

    assert logged.any? { |line|
      line.include?("enforcement.reconciliation.failed") && line.include?(the_case.public_id)
    }
  end
end
