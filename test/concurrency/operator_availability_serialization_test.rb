# frozen_string_literal: true

require "test_helper"
require "timeout"

class OperatorAvailabilitySerializationTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "an operator lifecycle stop waits for an in-flight administrative lock" do
    first = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    second = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    keeper = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    request = OperatorLifecycleRequest.create!(
      action: OperatorLifecycleRequest::ACTION_SUSPEND, status: OperatorLifecycleRequest::STATUS_APPROVED,
      target_operator: second, requested_by_operator: first, approved_by_operator: keeper,
      approved_at: Time.current, reason: "approved",
    )
    paused = Queue.new
    proceed = Queue.new
    second_ready = Queue.new
    first_thread = second_thread = nil
    captured = false
    observer =
      lambda do |_name, _start, _finish, _id, event|
        next unless Thread.current == first_thread && !captured &&
          event.fetch(:sql).match?(/\A\s*UPDATE\s+"operators"/i)

        captured = true
        paused << Operator.lease_connection.select_value("SELECT pg_backend_pid()").to_i
        proceed.pop
      end

    OpIdentityEventInvalidator.stub(:deliver, :applied) do
      ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
        first_thread =
          Thread.new do
            AdministrativeAccessLock.lock!(account: first, operator: keeper, reason_code: "security_incident")
          end
        first_pid = Timeout.timeout(10) { paused.pop }
        second_thread =
          Thread.new do
            Operator.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
              second_ready << connection.select_value("SELECT pg_backend_pid()").to_i
              fresh_request = OperatorLifecycleRequest.includes(:target_operator).find(request.id)
              OrgOperatorLifecycleExecute.call(request: fresh_request, actor: keeper)
            end
          end
        second_pid = Timeout.timeout(10) { second_ready.pop }
        waiting =
          Timeout.timeout(3) do
            loop do
              blocked =
                Operator.uncached do
                  Operator.lease_connection.select_value(
                    "SELECT #{Integer(first_pid)} = ANY(pg_blocking_pids(#{Integer(second_pid)}))",
                  )
                end
              break true if blocked
              break false unless second_thread.alive?

              Thread.pass
            end
          end

        assert waiting, "lifecycle stop must wait for the in-flight administrative decision"
        proceed << true
        Timeout.timeout(10) { first_thread.value }

        assert_predicate Timeout.timeout(10) { second_thread.value }, :success?
      end
    end
  ensure
    proceed << true if proceed
    [first_thread, second_thread].compact.each do |thread|
      begin
        thread.join(10)
      rescue StandardError
        # Preserve the test failure while cleaning up synthetic data.
      end
    end
    OperatorLifecycleRequest.where(id: request.id).delete_all if request
    [first, second, keeper].compact.each do |operator|
      AccountAccessEvent.where(account_type: "Operator", account_id: operator.id).delete_all
      OrgIdentityAuthenticationEvent.where(actor_ref: operator.id.to_s).delete_all
      operator.delete
    end
  end
end
