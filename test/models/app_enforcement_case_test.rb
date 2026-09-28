# typed: false
# frozen_string_literal: true

require "test_helper"

class AppEnforcementCaseTest < ActiveSupport::TestCase
  test "in_force requires an active unended currently effective unexpired case" do
    the_case = AppEnforcementCase.new(state: "draft")

    assert_not the_case.in_force?

    the_case.state = "active"
    the_case.ended_at = Time.current

    assert_not the_case.in_force?

    the_case.ended_at = nil
    the_case.effective_at = 1.day.from_now

    assert_not the_case.in_force?

    the_case.effective_at = 1.day.ago
    the_case.expires_at = 1.minute.ago

    assert_not the_case.in_force?

    the_case.expires_at = 1.day.from_now

    assert_predicate the_case, :in_force?
  end

  test "requires_approval is true for break glass and hidden operator bans" do
    the_case = AppEnforcementCase.new(kind: "cooldown", visibility: "visible")
    the_case.define_singleton_method(:break_glass?) { true }

    assert_predicate the_case, :requires_approval?

    ban = AppEnforcementCase.new(kind: "permanent_ban", visibility: "hidden")
    ban.define_singleton_method(:break_glass?) { false }

    assert_predicate ban, :requires_approval?
  end

  test "end_case rejects an unknown reason" do
    the_case = AppEnforcementCase.new

    assert_raises(ArgumentError) {
      EnforcementCaseEndOperation.call(enforcement_case: the_case, reason: "not-a-reason")
    }
  end

  test "cooldown requires expires_at and rejects a missing one at the database level" do
    client = clients(:one)
    operator = operators(:one)

    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        AppEnforcementCase.create!(
          kind: "cooldown",
          duration_mode: "timed",
          visibility: "visible",
          release_mode: "automatic",
          effective_at: Time.current,
          reason_code: "abuse",
          principal_public_id: client.public_id,
          applied_by_operator_public_id: operator.public_id,
        )
      end

    assert_match(/chk_app_enforcement_cases_cooldown_duration/, error.message)
  end

  test "permanent_ban rejects a non-nil expires_at at the database level" do
    client = clients(:one)
    operator = operators(:one)

    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        AppEnforcementCase.create!(
          kind: "permanent_ban",
          duration_mode: "permanent",
          visibility: "visible",
          release_mode: "break_glass_only",
          effective_at: Time.current,
          expires_at: 1.day.from_now,
          reason_code: "abuse",
          principal_public_id: client.public_id,
          applied_by_operator_public_id: operator.public_id,
        )
      end

    assert_match(/chk_app_enforcement_cases_permanent_ban_duration/, error.message)
  end

  test "indefinite temporary_freeze requires review_due_at and release_mode operator" do
    client = clients(:one)
    operator = operators(:one)

    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        AppEnforcementCase.create!(
          kind: "temporary_freeze",
          duration_mode: "indefinite",
          visibility: "visible",
          release_mode: "automatic",
          effective_at: Time.current,
          reason_code: "abuse",
          principal_public_id: client.public_id,
          applied_by_operator_public_id: operator.public_id,
        )
      end

    assert_match(/chk_app_enforcement_cases_indefinite_freeze_review/, error.message)
  end

  test "hidden visibility is only legal on permanent_ban" do
    client = clients(:one)
    operator = operators(:one)

    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        AppEnforcementCase.create!(
          kind: "cooldown",
          duration_mode: "timed",
          visibility: "hidden",
          release_mode: "automatic",
          effective_at: Time.current,
          expires_at: 1.day.from_now,
          reason_code: "abuse",
          principal_public_id: client.public_id,
          applied_by_operator_public_id: operator.public_id,
        )
      end

    assert_match(/chk_app_enforcement_cases_hidden/, error.message)
  end

  test "operator applying against their own public_id as principal is rejected" do
    operator = operators(:one)

    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        AppEnforcementCase.create!(
          kind: "cooldown",
          duration_mode: "timed",
          visibility: "visible",
          release_mode: "automatic",
          effective_at: Time.current,
          expires_at: 1.day.from_now,
          reason_code: "abuse",
          principal_public_id: operator.public_id,
          applied_by_operator_public_id: operator.public_id,
        )
      end

    assert_match(/chk_app_enforcement_cases_no_self_action/, error.message)
  end

  test "approved_by_operator_public_id must differ from applied_by_operator_public_id" do
    client = clients(:one)
    operator = operators(:one)

    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        AppEnforcementCase.create!(
          kind: "cooldown",
          duration_mode: "timed",
          visibility: "visible",
          release_mode: "automatic",
          effective_at: Time.current,
          expires_at: 1.day.from_now,
          reason_code: "abuse",
          principal_public_id: client.public_id,
          applied_by_operator_public_id: operator.public_id,
          approved_by_operator_public_id: operator.public_id,
        )
      end

    assert_match(/chk_app_enforcement_cases_approval_separation/, error.message)
  end

  test "break_glass true requires a break_glass_approved_by_operator_public_id" do
    client = clients(:one)
    operator = operators(:one)

    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        AppEnforcementCase.create!(
          kind: "cooldown",
          duration_mode: "timed",
          visibility: "visible",
          release_mode: "automatic",
          effective_at: Time.current,
          expires_at: 1.day.from_now,
          reason_code: "abuse",
          principal_public_id: client.public_id,
          applied_by_operator_public_id: operator.public_id,
          break_glass: true,
        )
      end

    assert_match(/chk_app_enforcement_cases_break_glass_approver/, error.message)
  end

  test "a valid cooldown case saves and defaults to draft state" do
    client = clients(:one)
    operator = operators(:one)

    the_case = AppEnforcementCase.create!(
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

    assert_equal "draft", the_case.state
    assert_predicate the_case.public_id, :present?
  end

  test "apply! transitions a temporary_freeze with an access-blocking Principal Effect to active and locks the " \
       "account" do
    client = clients(:one)
    operator = operators(:one)

    the_case = AppEnforcementCase.new(
      kind: "temporary_freeze",
      duration_mode: "timed",
      visibility: "visible",
      release_mode: "operator",
      effective_at: Time.current,
      expires_at: 1.day.from_now,
      reason_code: "security_incident",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator.public_id,
    )
    the_case.build_principal_effect(
      principal_public_id: client.public_id,
      access_blocking: true,
      effective_at: Time.current,
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )
    client.reload

    assert_equal "active", the_case.state
    assert_predicate client, :admin_locked?
    assert_predicate the_case.sessions_revoked_at, :present?
    assert_predicate the_case.audited_at, :present?
    assert_equal 1, EnforcementEvent.where(case_public_id: the_case.public_id, event_type: "applied").count
  end

  test "apply! on a method_protection case revokes only sessions matching the target method" do
    client = clients(:one)
    operator = operators(:one)
    matching_token = ClientToken.create!(user_id: client.id, established_authentication_method: "passkey")
    other_token = ClientToken.create!(user_id: client.id, established_authentication_method: "email")

    the_case = AppEnforcementCase.new(
      kind: "method_protection",
      duration_mode: "indefinite",
      visibility: "visible",
      release_mode: "operator",
      effective_at: Time.current,
      reason_code: "security_incident",
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
    matching_token.reload
    other_token.reload

    assert_predicate matching_token, :revoked?
    assert_not_predicate other_token, :revoked?
  end

  test "apply! raises ApprovalRequiredError for a hidden permanent_ban with no approval" do
    client = clients(:one)
    operator = operators(:one)

    the_case = AppEnforcementCase.new(
      kind: "permanent_ban",
      duration_mode: "permanent",
      visibility: "hidden",
      release_mode: "break_glass_only",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator.public_id,
    )

    assert_raises(EnforcementCaseApplicable::ApprovalRequiredError) { EnforcementCaseApplyOperation.call(enforcement_case: the_case, actor_operator_public_id: the_case.applied_by_operator_public_id) }
    assert_predicate the_case, :new_record?
  end

  test "apply! is blocked from re-applying an already active case" do
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

    assert_raises(EnforcementCaseApplicable::InvalidStateTransitionError) { EnforcementCaseApplyOperation.call(enforcement_case: the_case, actor_operator_public_id: the_case.applied_by_operator_public_id) }
  end

  test "applying a new open method effect closes the prior open row for the same slot" do
    client = clients(:one)
    operator = operators(:one)

    first_case = AppEnforcementCase.new(
      kind: "method_protection",
      duration_mode: "indefinite",
      visibility: "visible",
      release_mode: "operator",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator.public_id,
    )
    first_case.authentication_method_effects.build(
      principal_public_id: client.public_id,
      authentication_method: "email",
      effect: "mutation_locked",
      effective_at: Time.current,
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: first_case,
      actor_operator_public_id: first_case.applied_by_operator_public_id,
    )
    first_effect = first_case.authentication_method_effects.first

    second_case = AppEnforcementCase.new(
      kind: "method_protection",
      duration_mode: "indefinite",
      visibility: "visible",
      release_mode: "operator",
      effective_at: Time.current,
      reason_code: "security_incident",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator.public_id,
    )
    second_case.authentication_method_effects.build(
      principal_public_id: client.public_id,
      authentication_method: "email",
      effect: "unusable",
      effective_at: Time.current,
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: second_case,
      actor_operator_public_id: second_case.applied_by_operator_public_id,
    )

    first_effect.reload

    assert_predicate first_effect.ended_at, :present?
  end

  test "end_case! closes open effects and unlocks the account when no other blocking case remains" do
    client = clients(:one)
    operator = operators(:one)

    the_case = AppEnforcementCase.new(
      kind: "temporary_freeze",
      duration_mode: "timed",
      visibility: "visible",
      release_mode: "operator",
      effective_at: Time.current,
      expires_at: 1.day.from_now,
      reason_code: "security_incident",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator.public_id,
    )
    the_case.build_principal_effect(
      principal_public_id: client.public_id,
      access_blocking: true,
      effective_at: Time.current,
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )

    EnforcementCaseEndOperation.call(
      enforcement_case: the_case, reason: "revoked",
      ended_by_operator_public_id: operator.public_id,
    )
    client.reload

    assert_predicate the_case.ended_at, :present?
    assert_not_predicate client, :admin_locked?
  end

  test "requires_approval? is false for a visible permanent_ban in the app realm (target is never an Operator)" do
    client = clients(:one)
    operator = operators(:one)

    the_case = AppEnforcementCase.new(
      kind: "permanent_ban",
      duration_mode: "permanent",
      visibility: "visible",
      release_mode: "break_glass_only",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator.public_id,
    )

    assert_not_predicate the_case, :requires_approval?
  end

  test "open? tracks whether the case still has no end timestamp" do
    the_case = AppEnforcementCase.new

    assert_predicate the_case, :open?

    the_case.ended_at = Time.current

    assert_not_predicate the_case, :open?
  end

  test "pending_convergence finds active cases whose session revocation or audit write never landed" do
    client = clients(:one)
    operator = operators(:one)

    converged = AppEnforcementCase.new(
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
      enforcement_case: converged,
      actor_operator_public_id: converged.applied_by_operator_public_id,
    )

    stalled = AppEnforcementCase.create!(
      kind: "cooldown",
      duration_mode: "timed",
      visibility: "visible",
      release_mode: "automatic",
      effective_at: Time.current,
      expires_at: 1.day.from_now,
      reason_code: "abuse",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator.public_id,
      state: "active",
    )

    pending = AppEnforcementCase.pending_convergence

    assert_includes pending, stalled
    assert_not_includes pending, converged
  end

  test "principal_effect_blocking? answers only for an in-force case carrying the flag" do
    client = clients(:one)
    operator = operators(:one)

    the_case = AppEnforcementCase.new(
      kind: "permanent_ban",
      duration_mode: "permanent",
      visibility: "visible",
      release_mode: "break_glass_only",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator.public_id,
    )
    the_case.build_principal_effect(
      principal_public_id: client.public_id,
      access_blocking: true,
      withdrawal_purge_blocked: true,
      effective_at: Time.current,
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )

    assert AppEnforcementCase.principal_effect_blocking?(client.public_id, :withdrawal_purge_blocked)
    assert_not AppEnforcementCase.principal_effect_blocking?(client.public_id, :recovery_blocked)
    assert_not AppEnforcementCase.principal_effect_blocking?("client-standing-unknown", :withdrawal_purge_blocked)

    EnforcementCaseEndOperation.call(
      enforcement_case: the_case,
      reason: "revoked",
      ended_by_operator_public_id: operator.public_id,
    )

    assert_not AppEnforcementCase.principal_effect_blocking?(client.public_id, :withdrawal_purge_blocked)
  end

  test "authentication_method_effect_blocking? sees a revoking effect but not a mutation lock" do
    client = clients(:one)
    operator = operators(:one)

    the_case = AppEnforcementCase.new(
      kind: "method_protection",
      duration_mode: "indefinite",
      visibility: "visible",
      release_mode: "operator",
      effective_at: Time.current,
      reason_code: "security_incident",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator.public_id,
    )
    the_case.authentication_method_effects.build(
      principal_public_id: client.public_id,
      authentication_method: "passkey",
      effect: "unusable",
      effective_at: Time.current,
    )
    the_case.authentication_method_effects.build(
      principal_public_id: client.public_id,
      authentication_method: "totp",
      effect: "mutation_locked",
      effective_at: Time.current,
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )

    assert AppEnforcementCase.authentication_method_effect_blocking?(client.public_id, "passkey")
    assert_not AppEnforcementCase.authentication_method_effect_blocking?(client.public_id, "totp")
    assert_not AppEnforcementCase.authentication_method_effect_blocking?(client.public_id, "email")
  end
end
