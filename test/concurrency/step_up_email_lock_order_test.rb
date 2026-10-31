# frozen_string_literal: true

require "test_helper"
require "timeout"

class StepUpEmailLockOrderTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "delivery recording waits on the parent without locking the session needed by cancellation" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    device = token.device_session_record!
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: actor.public_id, session_ref: token.public_id, required_scope: "settings_email",
      required_aal: "none", allowed_methods: ["email_otp"], return_to: "/identity/emails",
    )
    session_record = ClientStepUpSession.create!(
      user_token: token, step_up_ceremony_transaction_ref: transaction.transaction_id,
      scope: transaction.required_scope, return_to: transaction.return_to,
      status: "PENDING", discard_at: transaction.expires_at,
    )
    generation = session_record.issue_bound_email_code!(
      transaction: transaction, credential_ref: SecureRandom.uuid, code: "012345",
    )
    worker_ready = Queue.new
    worker = nil

    transaction.with_lock do
      worker = Thread.new do
        OpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
          other_transaction = ClientStepUpCeremonyTransaction.find(transaction.id)
          other_session = ClientStepUpSession.find(session_record.id)
          worker_ready << connection.select_value("SELECT pg_backend_pid()").to_i
          other_session.mark_bound_email_delivery!(transaction: other_transaction, generation: generation, success: true)
        end
      ensure
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end

      pid = Timeout.timeout(10) { worker_ready.pop }
      Timeout.timeout(10) do
        loop do
          waiting = OpBaseAppRecord.uncached do
            OpBaseAppRecord.lease_connection.select_value(
              "SELECT cardinality(pg_blocking_pids(#{Integer(pid)})) > 0",
            )
          end
          break if waiting

          Thread.pass
        end
      end
      assert ClientStepUpSession.lock("FOR UPDATE NOWAIT").find(session_record.id)
      transaction.commit_cancellation!(now: ClientStepUpCeremonyTransaction.database_now)
    end

    assert_not Timeout.timeout(10) { worker.value }
    assert_equal "canceled", transaction.reload.status
    assert_equal "pending", session_record.reload.email_delivery_state
  ensure
    worker&.join(10)
    session_record&.delete
    transaction&.delete
    device&.update!(current_refresh_token_id: nil)
    token&.delete
    device&.delete
    actor&.delete
  end
end
