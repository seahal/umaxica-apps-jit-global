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

  test "A35-2 replayed termination waits behind cleanup job without a cross-store lock cycle" do
    @flow.update!(cleanup_status_id: ClientSignUpFlowCleanupStatus::PENDING)

    assert_not FeatureFlags.enabled?(RetentionPurgeJob::FEATURE_NAME), "cleanup must be enabled"
    selected = ClientSignUpFlow.where(
      cleanup_status_id: [ClientSignUpFlowCleanupStatus::PENDING, ClientSignUpFlowCleanupStatus::FAILED],
      status_id: SignUpArtifactCleanup.cleanup_status_ids(ClientSignUpFlow),
    ).order(:id).first

    assert_equal @flow.id, selected.id, "cleanup must select the test Flow in its first batch"
    cleanup_pid = Queue.new
    replay_pid = Queue.new
    cleanup = nil
    replay = nil
    Client.transaction do
      Client.lock.find(@actor.id)
      cleanup =
        Thread.new do
          AppZenithRecord.connection_pool.with_connection do |connection|
            cleanup_pid << Integer(connection.select_value("SELECT pg_backend_pid()"))
            OpBaseAppRecord.connection_pool.with_connection do
              RetentionPurgeJob.perform_now(batch_size: 1)
            end
          end
        end
      pid = Timeout.timeout(5) { cleanup_pid.pop }
      waited = false
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
      loop do
        event =
          Client.uncached do
            Client.connection.select_value("SELECT pg_stat_clear_snapshot()::text")
            Client.connection.select_value("SELECT wait_event_type FROM pg_stat_activity WHERE pid = #{Integer(pid)}")
          end
        waited = event == "Lock"
        break if waited || !cleanup.alive? || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep 0.01
      end

      assert waited, "The cleanup job must hold the Flow while waiting for the principal"
      replay =
        Thread.new do
          OpBaseAppRecord.connection_pool.with_connection do |connection|
            replay_pid << Integer(connection.select_value("SELECT pg_backend_pid()"))
            SignUpTermination.call(cycle: ClientSignUpFlow.find(@flow.id), event: :cancel)
          end
        end
      pid = Timeout.timeout(5) { replay_pid.pop }
      waited = false
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
      loop do
        event =
          OpBaseAppRecord.uncached do
            OpBaseAppRecord.connection.select_value("SELECT pg_stat_clear_snapshot()::text")
            OpBaseAppRecord.connection.select_value(
              "SELECT wait_event_type FROM pg_stat_activity WHERE pid = #{Integer(pid)}",
            )
          end
        waited = event == "Lock"
        break if waited || !replay.alive? || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep 0.01
      end

      assert waited, "The replay must wait for the cleanup job's Flow lock"
    end
    Timeout.timeout(15) { cleanup.value }
    result = Timeout.timeout(10) { replay.value }

    assert_equal :ok, result.status
    assert_equal ClientSignUpFlowStatus::CANCELLED, @flow.reload.status_id
    assert_predicate @flow, :cleanup_completed?
    assert_equal 1, @flow.cleanup_attempts_count
  ensure
    cleanup&.join(5)
    replay&.join(5)
  end
end
