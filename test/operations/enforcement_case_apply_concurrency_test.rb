# frozen_string_literal: true

require "test_helper"
require "timeout"

class EnforcementCaseApplyConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "independent requests cannot both apply the same draft" do
    client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
    )
    enforcement_case = AppEnforcementCase.create!(
      kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: client.public_id, applied_by_operator_public_id: "apply-test-operator",
    )
    ready = Queue.new
    proceed = Queue.new
    workers =
      2.times.map do
        Thread.new do
          AppPrincipalRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
            candidate = AppEnforcementCase.find(enforcement_case.id)
            ready << candidate.state
            proceed.pop
            EnforcementCaseApplyOperation.call(
              enforcement_case: candidate,
              actor_operator_public_id: "apply-test-operator",
            )
          end
        rescue EnforcementCaseApplicable::InvalidStateTransitionError => e
          e
        ensure
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end
      end

    assert_equal ["draft", "draft"], [Timeout.timeout(10) { ready.pop }, Timeout.timeout(10) { ready.pop }]
    2.times { proceed << true }
    outcomes = workers.map { |worker| Timeout.timeout(10) { worker.value } }

    assert_equal 1, outcomes.count(true)
    assert_equal 1, outcomes.count { |result| result.is_a?(EnforcementCaseApplicable::InvalidStateTransitionError) }
    assert_equal "active", enforcement_case.reload.state
    assert_equal 1,
                 EnforcementEvent.where(
                   realm: "app", case_public_id: enforcement_case.public_id,
                   event_type: "applied",
                 ).count
  ensure
    2.times { proceed << true } if proceed
    workers&.each(&:join)
    EnforcementEvent.where(realm: "app", case_public_id: enforcement_case.public_id).delete_all if enforcement_case
    enforcement_case&.delete
    client&.delete
  end
end
