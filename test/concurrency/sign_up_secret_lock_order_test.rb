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

      assert waited, "The cleanup job must wait for the principal"
      replay =
        Thread.new do
          AppZenithRecord.connection_pool.with_connection do |connection|
            OpBaseAppRecord.connection_pool.with_connection do
              replay_pid << Integer(connection.select_value("SELECT pg_backend_pid()"))
              SignUpTermination.call(cycle: ClientSignUpFlow.find(@flow.id), event: :cancel)
            end
          end
        end
      pid = Timeout.timeout(5) { replay_pid.pop }
      waited = false
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
      loop do
        event =
          Client.uncached do
            Client.connection.select_value("SELECT pg_stat_clear_snapshot()::text")
            Client.connection.select_value("SELECT wait_event_type FROM pg_stat_activity WHERE pid = #{Integer(pid)}")
          end
        waited = event == "Lock"
        break if waited || !replay.alive? || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep 0.01
      end

      assert waited, "The replay must wait for the principal"
      OpBaseAppRecord.transaction(requires_new: true) do
        assert_predicate ClientSignUpFlow.lock("FOR UPDATE NOWAIT").find(@flow.id), :persisted?
      end
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
  %i(delivery reattempt reservation retirement).each do |operation|
    test "signup Secret #{operation} waits for principal before locking Flow" do
      passkey = @actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public-key")
      issuance =
        if operation != :retirement
          ClientSecretIssuance.create!(
            client: @actor, origin_operation_id: SecureRandom.uuid, origin: "passkey_registration", attempt_number: 1,
            planned_count: 1, sign_up_flow_ref: @flow.public_id, expires_at: 1.minute.from_now,
          )
        end
      worker = nil
      worker_pid = Queue.new
      flow_available = false
      waited = false
      Client.transaction do
        Client.lock.find(@actor.id)
        worker =
          Thread.new do
            AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
              OpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
                worker_pid << Integer(connection.select_value("SELECT pg_backend_pid()"))
                case operation
                when :delivery
                  ClientSecretPasskeyReservationIssuer.with_sign_up_delivery!(
                    flow: ClientSignUpFlow.find(@flow.id), nonce: "lock-order-browser", issuance: issuance,
                  ) { raise ArgumentError, "invalid flow was accepted" }
                when :reattempt
                  ClientSecretPasskeyReservationIssuer.reattempt_for_sign_up!(
                    flow: ClientSignUpFlow.find(@flow.id), nonce: "lock-order-browser", predecessor: issuance,
                    expires_after: 1.minute,
                  )
                when :retirement
                  ClientSecretPasskeyReservationIssuer.terminate_sign_up!(
                    flow: ClientSignUpFlow.find(@flow.id), purge_after: 1.day,
                  )
                when :reservation
                  ClientSecretPasskeyReservationIssuer.call_for_sign_up!(
                    flow: ClientSignUpFlow.find(@flow.id), nonce: "lock-order-browser", passkey: passkey,
                    expires_after: 1.minute,
                  )
                end
              end
            end
          rescue StandardError => e
            e
          ensure
            ActiveRecord::Base.connection_handler.clear_active_connections!
          end
        pid = Timeout.timeout(5) { worker_pid.pop }
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
        loop do
          event =
            Client.uncached do
              Client.connection.select_value("SELECT pg_stat_clear_snapshot()::text")
              Client.connection.select_value("SELECT wait_event_type FROM pg_stat_activity WHERE pid = #{Integer(pid)}")
            end
          waited = event == "Lock"
          break if waited || !worker.alive? || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

          sleep 0.01
        end
        begin
          OpBaseAppRecord.transaction(requires_new: true) do
            ClientSignUpFlow.lock("FOR UPDATE NOWAIT").find(@flow.id)
            flow_available = true
          end
        rescue ActiveRecord::LockWaitTimeout
          flow_available = false
        end
      end
      result = Timeout.timeout(5) { worker.value }

      assert waited, "The worker must wait for the principal row"
      assert flow_available, "A principal waiter must not hold the Flow row"
      if operation == :retirement
        assert_nil result
      else
        assert_instance_of ClientSecretPasskeyReservationIssuer::Denied, result
      end
    ensure
      worker&.join(5)
      issuance&.delete
      passkey&.delete
    end
  end
  %i(verify finalize).each do |operation|
    test "signup Email #{operation} waits for owner before locking Flow" do
      email = @actor.client_emails.create!(
        raw_address: "lock-order-#{SecureRandom.hex(8)}@example.test", confirm_policy: true,
        user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
      )
      worker = nil
      worker_pid = Queue.new
      waited = false
      flow_available = false
      Client.transaction do
        Client.lock.find(@actor.id)
        worker =
          Thread.new do
            AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
              OpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
                worker_pid << Integer(connection.select_value("SELECT pg_backend_pid()"))
                flow = ClientSignUpFlow.find(@flow.id)
                candidate = ClientEmail.find(email.id)
                if operation == :verify
                  candidate.mark_sign_up_verified!(
                    flow: flow, session_nonce: "lock-order-browser",
                    code: "000000",
                  )
                else
                  candidate.finalize_sign_up_binding!(flow: flow, session_nonce: "lock-order-browser")
                end
              end
            end
          rescue StandardError => e
            e
          ensure
            ActiveRecord::Base.connection_handler.clear_active_connections!
          end
        pid = Timeout.timeout(5) { worker_pid.pop }
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
        loop do
          event =
            Client.uncached do
              Client.connection.select_value("SELECT pg_stat_clear_snapshot()::text")
              Client.connection.select_value("SELECT wait_event_type FROM pg_stat_activity WHERE pid = #{Integer(pid)}")
            end
          waited = event == "Lock"
          break if waited || !worker.alive? || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

          sleep 0.01
        end
        begin
          OpBaseAppRecord.transaction(requires_new: true) do
            ClientSignUpFlow.lock("FOR UPDATE NOWAIT").find(@flow.id)
            flow_available = true
          end
        rescue ActiveRecord::LockWaitTimeout
          flow_available = false
        end
      end
      result = Timeout.timeout(5) { worker.value }

      assert waited, "The writer must wait for the owner"
      assert flow_available, "The owner waiter must leave the Flow unlocked"
      assert_instance_of ArgumentError, result
      assert_nil email.reload.binding_finalized_at
    ensure
      worker&.join(5)
      email&.delete
    end
  end

  test "signup Email rejects an unbound or different actor Flow before changing a candidate" do
    email = @actor.client_emails.create!(
      raw_address: "lock-order-#{SecureRandom.hex(8)}@example.test", confirm_policy: true,
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    [nil, @actor.id + 1].each do |principal_id|
      stale_flow = ClientSignUpFlow.find(@flow.id)
      stale_flow.principal_id = principal_id
      assert_raises(ArgumentError) do
        email.mark_sign_up_verified!(flow: stale_flow, session_nonce: "lock-order-browser", code: "000000")
      end
      assert_raises(ArgumentError) do
        email.finalize_sign_up_binding!(flow: stale_flow, session_nonce: "lock-order-browser")
      end
    end

    assert_nil email.reload.binding_finalized_at
    assert_equal ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP, email.user_email_status_id
  ensure
    email&.delete
  end
  %i(verify finalize).each do |operation|
    test "signup Email #{operation} holds owner when waiting for Flow" do
      email = @actor.client_emails.create!(
        raw_address: "lock-order-#{SecureRandom.hex(8)}@example.test", confirm_policy: true,
        user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
      )
      worker = nil
      worker_pid = Queue.new
      waited = false
      owner_locked = false
      OpBaseAppRecord.transaction do
        ClientSignUpFlow.lock.find(@flow.id)
        worker =
          Thread.new do
            AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
              OpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
                worker_pid << Integer(connection.select_value("SELECT pg_backend_pid()"))
                flow = ClientSignUpFlow.find(@flow.id)
                candidate = ClientEmail.find(email.id)
                if operation == :verify
                  candidate.mark_sign_up_verified!(
                    flow: flow, session_nonce: "lock-order-browser",
                    code: "000000",
                  )
                else
                  candidate.finalize_sign_up_binding!(flow: flow, session_nonce: "lock-order-browser")
                end
              end
            end
          rescue StandardError => e
            e
          ensure
            ActiveRecord::Base.connection_handler.clear_active_connections!
          end
        pid = Timeout.timeout(5) { worker_pid.pop }
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
          break if waited || !worker.alive? || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

          sleep 0.01
        end
        begin
          Client.transaction(requires_new: true) { Client.lock("FOR UPDATE NOWAIT").find(@actor.id) }
        rescue ActiveRecord::LockWaitTimeout
          owner_locked = true
        end
      end
      result = Timeout.timeout(5) { worker.value }

      assert waited, "The writer must wait for the Flow"
      assert owner_locked, "The Flow waiter must already hold the owner"
      assert_instance_of ArgumentError, result
      assert_nil email.reload.binding_finalized_at
    ensure
      worker&.join(5)
      email&.delete
    end
  end
end
