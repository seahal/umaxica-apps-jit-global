# frozen_string_literal: true

require "test_helper"

class EnforcementCaseApplyFailureTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  [AppEnforcementCase, OrgEnforcementCase].each do |case_class|
    test "#{case_class.name} reports a missing principal after committing the decision" do
      enforcement_case = case_class.new(
        kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
        release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
        principal_public_id: SecureRandom.uuid, applied_by_operator_public_id: "apply-test-operator",
      )

      assert_raises(ActiveRecord::RecordNotFound) do
        EnforcementCaseApplyOperation.call(
          enforcement_case: enforcement_case, actor_operator_public_id: "apply-test-operator",
        )
      end
      assert_equal "active", enforcement_case.reload.state
      assert_nil enforcement_case.sessions_revoked_at
      assert_nil enforcement_case.audited_at
      assert case_class.pending_convergence.exists?(id: enforcement_case.id)
    end
  end

  test "a rejected post-commit effect keeps the committed Case in force for reconciliation" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    enforcement_case = AppEnforcementCase.create!(
      kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: client.public_id, applied_by_operator_public_id: "apply-test-operator",
    )

    enforcement_case.stub(:revoke_method_sessions!, -> { raise ActiveRecord::RecordNotUnique }) do
      assert_raises(ActiveRecord::RecordNotUnique) do
        EnforcementCaseApplyOperation.call(
          enforcement_case: enforcement_case,
          actor_operator_public_id: "apply-test-operator",
        )
      end
    end

    assert_equal "active", enforcement_case.reload.state
    assert AppEnforcementCase.in_force.exists?(id: enforcement_case.id)
    assert AppEnforcementCase.pending_convergence.exists?(id: enforcement_case.id)
  end

  test "a new Case outside the applicable states is not persisted" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    enforcement_case = AppEnforcementCase.new(
      kind: "security_lock", state: "failed", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: client.public_id, applied_by_operator_public_id: "apply-test-operator",
    )

    assert_no_difference "AppEnforcementCase.count" do
      assert_raises(EnforcementCaseApplicable::InvalidStateTransitionError) do
        EnforcementCaseApplyOperation.call(
          enforcement_case: enforcement_case,
          actor_operator_public_id: "apply-test-operator",
        )
      end
    end
    assert_not_predicate enforcement_case, :persisted?
  end
end
