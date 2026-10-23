# frozen_string_literal: true

require "test_helper"
require "timeout"

class SignUpSecretLockOrderTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    @flow = ClientSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
      principal_id: @actor.id, entry_method: "telephone",
      status_id: ClientSignUpFlowStatus::CANCELLED, step: "cancelled",
      nonce_digest: ClientSignUpFlow.digest_nonce("lock-order-browser"),
      issued_at: Time.current, expires_at: 15.minutes.from_now,
    )
  end

  teardown do
    ClientSignUpFlow.where(id: @flow.id).delete_all if @flow
    Client.where(id: @actor.id).delete_all if @actor
  end

  test "Secret retirement waits for the sign-up Flow without holding the principal lock" do
    worker = nil
    pid_queue = Queue.new
    principal_lock_acquired = false
    wait_observed = false

    OpBaseAppRecord.transaction do
      ClientSignUpFlow.lock.find(@flow.id)
      worker =
        Thread.new do
          OpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
            pid_queue << Integer(connection.select_value("SELECT pg_backend_pid()"))
            ClientSecretPasskeyReservationIssuer.terminate_sign_up!(
              flow: @flow, purge_after: SignUpTermination::PHYSICAL_PURGE_DELAY,
            )
          end
        rescue StandardError => e
          e
        end

      worker_pid = Timeout.timeout(5) { pid_queue.pop }
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1.5
      loop do
        # A read-only observation of the specific worker proves it is actually waiting on the Flow.
        event =
          OpBaseAppRecord.uncached do
            OpBaseAppRecord.connection.select_value("SELECT pg_stat_clear_snapshot()::text")
            OpBaseAppRecord.connection.select_value(
              "SELECT wait_event_type FROM pg_stat_activity WHERE pid = #{Integer(worker_pid)}",
            )
          end
        wait_observed = event == "Lock"
        break if wait_observed || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep 0.01
      end

      begin
        Client.transaction(requires_new: true) do
          Client.lock("FOR UPDATE NOWAIT").find(@actor.id)
          principal_lock_acquired = true
        end
      rescue ActiveRecord::LockWaitTimeout
        principal_lock_acquired = false
      end
    end

    result = Timeout.timeout(5) { worker.value }

    assert wait_observed, "The worker must reach a real PostgreSQL Flow-lock wait"
    assert principal_lock_acquired, "A Flow waiter must not block the principal row"
    assert_not_kind_of StandardError, result
  ensure
    worker&.join(5)
  end
end
