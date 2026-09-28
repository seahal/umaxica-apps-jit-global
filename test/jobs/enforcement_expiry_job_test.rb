# typed: false
# frozen_string_literal: true

require "test_helper"

class EnforcementExpiryJobTest < ActiveJob::TestCase
  test "ends an active cooldown case whose expires_at has passed and unlocks nothing since it never blocked access" do
    client = clients(:one)
    operator = operators(:one)

    the_case = AppEnforcementCase.new(
      kind: "cooldown",
      duration_mode: "timed",
      visibility: "visible",
      release_mode: "automatic",
      effective_at: 2.days.ago,
      expires_at: 1.hour.ago,
      reason_code: "abuse",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator.public_id,
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )

    EnforcementExpiryJob.perform_now

    the_case.reload

    assert_predicate the_case.ended_at, :present?
    assert_equal "expired", the_case.end_reason
  end

  test "expiring a temporary_freeze releases admin_locked when no other blocking case remains" do
    client = clients(:one)
    operator = operators(:one)

    the_case = AppEnforcementCase.new(
      kind: "temporary_freeze",
      duration_mode: "timed",
      visibility: "visible",
      release_mode: "operator",
      effective_at: 2.days.ago,
      expires_at: 1.hour.ago,
      reason_code: "security_incident",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator.public_id,
    )
    the_case.build_principal_effect(
      principal_public_id: client.public_id,
      access_blocking: true,
      effective_at: 2.days.ago,
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )

    EnforcementExpiryJob.perform_now
    client.reload

    assert_not_predicate client, :admin_locked?
  end

  test "does not touch a case whose expires_at has not yet passed" do
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

    EnforcementExpiryJob.perform_now

    assert_not_predicate the_case.reload.ended_at, :present?
  end
end
