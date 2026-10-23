# frozen_string_literal: true

require "test_helper"
require "timeout"

class SignUpCleanupPrincipalLockTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    ClientSignUpFlow.where(id: @app_flow.id).delete_all if @app_flow
    ClientTelephone.where(id: @app_contact.id).delete_all if @app_contact
    Client.where(id: @client.id).delete_all if @client
    VisitorSignUpFlow.where(id: @com_flow.id).delete_all if @com_flow
    VisitorTelephone.where(id: @com_contact.id).delete_all if @com_contact
    Visitor.where(id: @visitor.id).delete_all if @visitor
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

  test "COM cleanup rechecks the registered contact after waiting for the principal writer lock" do
    @visitor = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::ACTIVE)
    @com_contact = VisitorTelephone.create!(
      visitor: @visitor, raw_number: "+12345678908", confirm_policy: true,
      visitor_telephone_status_id: VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    @com_flow = VisitorSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(VisitorSignUpFlow),
      principal_id: @visitor.id, pending_contact_type: "telephone", pending_contact_id: @com_contact.id,
      entry_method: "telephone", status_id: VisitorSignUpFlowStatus::CANCELLED, step: "cancelled",
      nonce_digest: VisitorSignUpFlow.digest_nonce("cleanup-browser"),
      issued_at: Time.current, expires_at: 15.minutes.from_now,
    )
    pid_queue = Queue.new
    wait_observed = false
    worker = nil

    Visitor.transaction do
      @visitor.lock!
      worker =
        Thread.new do
          ComZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
            pid_queue << Integer(connection.select_value("SELECT pg_backend_pid()"))
            OpBaseComRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
              SignUpArtifactCleanup.call(cycle: VisitorSignUpFlow.find(@com_flow.id))
            end
          end
        end
      worker_pid = Timeout.timeout(5) { pid_queue.pop }
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1.5
      loop do
        event =
          ComZenithRecord.uncached do
            ComZenithRecord.connection.select_value("SELECT pg_stat_clear_snapshot()::text")
            ComZenithRecord.connection.select_value(
              "SELECT wait_event_type FROM pg_stat_activity WHERE pid = #{Integer(worker_pid)}",
            )
          end
        wait_observed = event == "Lock"
        break if wait_observed || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep 0.01
      end
      # COM registration is still classified by its contact until WU-34 introduces actor statuses.
      @com_contact.update!(visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED)
    end
    Timeout.timeout(5) { worker.value }

    assert wait_observed, "Cleanup must wait for the real principal row lock"
    assert_equal VisitorSignUpFlowCleanupStatus::COMPLETED, @com_flow.reload.cleanup_status_id
    assert_equal Float::INFINITY, @visitor.reload.discard_at
    assert_equal VisitorTelephoneStatus::VERIFIED, @com_contact.reload.visitor_telephone_status_id
    assert_equal Float::INFINITY, @com_contact.discard_at
  ensure
    worker&.join(5)
  end
end
