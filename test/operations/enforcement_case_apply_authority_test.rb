# frozen_string_literal: true

require "test_helper"

class EnforcementCaseApplyAuthorityTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a stale draft cannot apply an APP or ORG Case already applied by another request" do
    [[Client, ClientStatus::ACTIVE, AppEnforcementCase],
     [Operator, OperatorStatus::ACTIVE, OrgEnforcementCase],].each do |actor_class, status, case_class|
      actor = actor_class.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: status)
      enforcement_case = case_class.create!(
        kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
        release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
        principal_public_id: actor.public_id, applied_by_operator_public_id: "apply-test-operator",
      )
      first = case_class.find(enforcement_case.id)
      stale = case_class.find(enforcement_case.id)
      EnforcementCaseApplyOperation.call(enforcement_case: first, actor_operator_public_id: "apply-test-operator")

      assert_raises(EnforcementCaseApplicable::InvalidStateTransitionError) do
        EnforcementCaseApplyOperation.call(enforcement_case: stale, actor_operator_public_id: "apply-test-operator")
      end
      assert_equal "active", enforcement_case.reload.state
    end
  end

  test "a draft changed after it was read is not applied with stale attributes" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    enforcement_case = AppEnforcementCase.create!(
      kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: client.public_id, applied_by_operator_public_id: "apply-test-operator",
    )
    stale = AppEnforcementCase.find(enforcement_case.id)
    enforcement_case.update!(effective_at: 1.hour.from_now)

    assert_raises(EnforcementCaseApplicable::InvalidStateTransitionError) do
      EnforcementCaseApplyOperation.call(enforcement_case: stale, actor_operator_public_id: "apply-test-operator")
    end
    assert_equal "draft", enforcement_case.reload.state
  end

  test "applying a persisted Case retains its newly attached principal effect" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    enforcement_case = AppEnforcementCase.create!(
      kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: client.public_id, applied_by_operator_public_id: "apply-test-operator",
    )
    enforcement_case = AppEnforcementCase.includes(:principal_effect).find(enforcement_case.id)
    enforcement_case.build_principal_effect(
      principal_public_id: client.public_id, effective_at: Time.current, access_blocking: false,
      recovery_blocked: true, reactivation_blocked: false, withdrawal_purge_blocked: false,
      principal_hard_delete_blocked: false,
    )

    assert EnforcementCaseApplyOperation.call(
      enforcement_case: enforcement_case, actor_operator_public_id: "apply-test-operator",
    )
    assert_predicate AppEnforcementPrincipalEffect.find_by!(app_enforcement_case_id: enforcement_case.id),
                     :recovery_blocked?
  end
end
