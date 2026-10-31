# frozen_string_literal: true

require "test_helper"

class EnforcementCaseEndMissingPrincipalTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a freshly loaded blocking Case can end without lazily loading its effect association" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    the_case = AppEnforcementCase.new(
      kind: "security_lock", state: "active", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: actor.public_id, applied_by_operator_public_id: operator.public_id,
    )
    the_case.build_principal_effect(principal_public_id: actor.public_id, access_blocking: true, effective_at: Time.current)
    the_case.save!

    assert EnforcementCaseEndOperation.call(enforcement_case: AppEnforcementCase.find(the_case.id), reason: "revoked")
    assert_predicate the_case.reload.ended_at, :present?
    assert the_case.audit_event_recorded?("ended")
  end

  [AppEnforcementCase, OrgEnforcementCase].each do |case_class|
    test "#{case_class.name} reports a missing principal rather than claiming a released lock" do
      the_case = case_class.new(
        kind: "security_lock", state: "active", duration_mode: "indefinite", visibility: "visible",
        release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
        principal_public_id: SecureRandom.uuid, applied_by_operator_public_id: "missing-operator",
      )
      the_case.build_principal_effect(
        principal_public_id: the_case.principal_public_id, access_blocking: true, effective_at: Time.current,
      )
      the_case.save!

      assert_raises(ActiveRecord::RecordNotFound) do
        EnforcementCaseEndOperation.call(enforcement_case: the_case, reason: "revoked")
      end
      assert_predicate the_case.reload.ended_at, :present?
      assert_not the_case.audit_event_recorded?("ended")
    end
  end

  test "a missing releasing operator does not claim the principal lock was released" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    the_case = AppEnforcementCase.new(
      kind: "security_lock", state: "active", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: actor.public_id, applied_by_operator_public_id: "missing-operator",
    )
    the_case.build_principal_effect(principal_public_id: actor.public_id, access_blocking: true, effective_at: Time.current)
    the_case.save!

    assert_raises(ActiveRecord::RecordNotFound) do
      EnforcementCaseEndOperation.call(enforcement_case: the_case, reason: "revoked")
    end
    assert_predicate the_case.reload.ended_at, :present?
    assert_not the_case.audit_event_recorded?("ended")
  end
end
