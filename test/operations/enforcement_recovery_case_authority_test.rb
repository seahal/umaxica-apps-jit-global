# frozen_string_literal: true

require "test_helper"

class EnforcementRecoveryCaseAuthorityTest < ActiveSupport::TestCase
  test "a committed recovery Case can reconcile after its audit writer fails" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    enforcement_case = AppEnforcementCase.create!(
      kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: client.public_id, applied_by_operator_public_id: "recovery-test-operator",
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: enforcement_case, actor_operator_public_id: enforcement_case.applied_by_operator_public_id,
    )
    ceremony = ClientEnforcementRecoveryCeremony.issue!(subject: client, request: ActionDispatch::TestRequest.create)

    enforcement_case.stub(:write_audit_event_once!, ->(*) { raise ActiveRecord::ConnectionNotEstablished }) do
      assert_raises(ActiveRecord::ConnectionNotEstablished) do
        EnforcementCaseEndOperation.call(
          enforcement_case: enforcement_case, reason: "verification_completed", recovery_ceremony: ceremony,
        )
      end
    end

    assert_not_nil enforcement_case.reload.ended_at
    assert_not_predicate ceremony.reload, :active?
    assert EnforcementCaseEndOperation.new(
      enforcement_case: enforcement_case, reason: "verification_completed",
    ).reconcile
    assert enforcement_case.audit_event_recorded?("ended")
  end

  test "recovery completion requires its own ceremony and rolls back on ceremony consumption failure" do
    %i(missing_ceremony foreign_subject consume_failure).each do |scenario|
      client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
      other = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
      enforcement_case = AppEnforcementCase.create!(
        kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
        release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
        principal_public_id: client.public_id, applied_by_operator_public_id: "recovery-test-operator",
      )
      EnforcementCaseApplyOperation.call(
        enforcement_case: enforcement_case, actor_operator_public_id: enforcement_case.applied_by_operator_public_id,
      )
      ceremony = ClientEnforcementRecoveryCeremony.issue!(
        subject: (scenario == :foreign_subject) ? other : client, request: ActionDispatch::TestRequest.create,
      )

      if scenario == :missing_ceremony
        assert_raises(ArgumentError) do
          EnforcementCaseEndOperation.call(enforcement_case: enforcement_case, reason: "verification_completed")
        end
      elsif scenario == :foreign_subject
        assert_raises(ActiveRecord::RecordNotFound) do
          EnforcementCaseEndOperation.call(
            enforcement_case: enforcement_case, reason: "verification_completed", recovery_ceremony: ceremony,
          )
        end
      else
        fired = false
        fault =
          lambda do |_name, _start, _finish, _id, event|
            sql = event.fetch(:sql)
            next unless sql.match?(/\A\s*UPDATE\s+"client_enforcement_recovery_ceremonies"/i)

            fired = true
            raise ActiveRecord::StatementInvalid, "injected recovery ceremony write failure"
          end

        ActiveSupport::Notifications.subscribed(fault, "sql.active_record") do
          assert_raises(ActiveRecord::StatementInvalid) do
            EnforcementCaseEndOperation.call(
              enforcement_case: enforcement_case, reason: "verification_completed", recovery_ceremony: ceremony,
            )
          end
        end
        assert fired
      end

      assert_nil enforcement_case.reload.ended_at
      assert_predicate ceremony.reload, :active?
    end
  end
end
