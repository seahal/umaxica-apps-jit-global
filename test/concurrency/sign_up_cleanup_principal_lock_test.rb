# frozen_string_literal: true

require "test_helper"
require "timeout"

class SignUpCleanupPrincipalLockTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    ClientSignUpFlow.where(id: @app_flow.id).delete_all if @app_flow
    ClientTelephone.where(id: @app_contact.id).delete_all if @app_contact
    Client.where(id: @client.id).delete_all if @client
  end

  test "APP cleanup rechecks registration after waiting for the principal writer lock" do
    @client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    @app_contact = ClientTelephone.create!(
      user: @client, raw_number: "+12345678907", confirm_policy: true, confirm_using_mfa: true,
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    @app_flow = ClientSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
      principal_id: @client.id, pending_contact_type: "telephone", pending_contact_id: @app_contact.id,
      entry_method: "telephone", status_id: ClientSignUpFlowStatus::CANCELLED, step: "cancelled",
      nonce_digest: ClientSignUpFlow.digest_nonce("cleanup-browser"),
      issued_at: Time.current, expires_at: 15.minutes.from_now,
    )
    pid_queue = Queue.new
    wait_observed = false
    worker = nil

    Client.transaction do
      @client.lock!
      worker =
        Thread.new do
          AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
            pid_queue << Integer(connection.select_value("SELECT pg_backend_pid()"))
            OpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
              SignUpArtifactCleanup.call(cycle: ClientSignUpFlow.find(@app_flow.id))
            end
          end
        end
      worker_pid = Timeout.timeout(5) { pid_queue.pop }
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1.5
      loop do
        event =
          AppZenithRecord.uncached do
            AppZenithRecord.connection.select_value("SELECT pg_stat_clear_snapshot()::text")
            AppZenithRecord.connection.select_value(
              "SELECT wait_event_type FROM pg_stat_activity WHERE pid = #{Integer(worker_pid)}",
            )
          end
        wait_observed = event == "Lock"
        break if wait_observed || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep 0.01
      end
      # Commit the registration fact on the writer while cleanup waits; the stale selection
      # must not authorize pending-artifact retirement after this transaction commits.
      @client.update!(status_id: ClientStatus::ACTIVE)
    end
    Timeout.timeout(5) { worker.value }

    assert wait_observed, "Cleanup must wait for the real principal row lock"
    assert_equal ClientSignUpFlowCleanupStatus::COMPLETED, @app_flow.reload.cleanup_status_id
    assert_equal ClientStatus::ACTIVE, @client.reload.status_id
    assert_equal Float::INFINITY, @client.discard_at
    assert_equal ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP, @app_contact.reload.user_telephone_status_id
    assert_equal Float::INFINITY, @app_contact.discard_at
  ensure
    worker&.join(5)
  end

  test "APP cleanup drops the Flow lock before retrying a stale unbound instance actor-first" do
    @client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    @app_contact = ClientTelephone.create!(
      user: @client, raw_number: "+12345678908", confirm_policy: true, confirm_using_mfa: true,
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    @app_flow = ClientSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
      principal_id: nil, pending_contact_type: nil, pending_contact_id: nil,
      entry_method: "telephone", status_id: ClientSignUpFlowStatus::CANCELLED, step: "cancelled",
      nonce_digest: ClientSignUpFlow.digest_nonce("cleanup-stale-browser"),
      issued_at: Time.current, expires_at: 15.minutes.from_now,
    )
    stale_flow = ClientSignUpFlow.find(@app_flow.id)
    @app_flow.update!(
      principal_id: @client.id, pending_contact_type: "telephone", pending_contact_id: @app_contact.id,
    )

    pid_queue = Queue.new
    worker = nil
    actor_wait_observed = false
    Client.transaction do
      @client.lock!
      worker =
        Thread.new do
          AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
            pid_queue << Integer(connection.select_value("SELECT pg_backend_pid()"))
            OpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
              OpBaseAppRecord.transaction do
                SignUpArtifactCleanup.call(cycle: stale_flow)
              end
            end
          end
        end
      worker_pid = Timeout.timeout(5) { pid_queue.pop }
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
      loop do
        event =
          AppZenithRecord.uncached do
            AppZenithRecord.connection.select_value("SELECT pg_stat_clear_snapshot()::text")
            AppZenithRecord.connection.select_value(
              "SELECT wait_event_type FROM pg_stat_activity WHERE pid = #{Integer(worker_pid)}",
            )
          end
        actor_wait_observed = event == "Lock"
        break if actor_wait_observed || !worker.alive? || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep 0.01
      end

      assert actor_wait_observed, "Stale cleanup must release the Flow lock before waiting for the actor"
      OpBaseAppRecord.transaction(requires_new: true) do
        assert_predicate ClientSignUpFlow.lock("FOR UPDATE NOWAIT").find(@app_flow.id), :persisted?
      end
    end
    Timeout.timeout(5) { worker.value }

    assert_equal ClientSignUpFlowCleanupStatus::COMPLETED, @app_flow.reload.cleanup_status_id
    assert_equal ClientTelephoneStatus::DELETED, @app_contact.reload.user_telephone_status_id
  ensure
    worker&.join(5)
  end
end
