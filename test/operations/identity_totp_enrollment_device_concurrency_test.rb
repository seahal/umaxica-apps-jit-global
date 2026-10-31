# frozen_string_literal: true

require "test_helper"
require "timeout"

class IdentityTotpEnrollmentDeviceConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "enrollment start waits for device revocation and refuses after it commits" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE,
    )
    token = ClientToken.create!(
      authentication_epoch: 0, id: SecureRandom.random_number(1 << 60) + 1_000_000_000, user: actor,
    )
    device = token.device_session_record!
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: actor.public_id, session_ref: token.public_id, purpose: "credential_registration",
      required_scope: "settings_totp", step_up_required: false, allowed_methods: ["totp"],
    )
    record = ClientStepUpSession.create!(
      user_token: token, scope: "settings_totp", return_to: "/identity", status: "PENDING",
      step_up_ceremony_transaction_ref: transaction.transaction_id, discard_at: transaction.expires_at,
    )
    ready = Queue.new
    proceed = Queue.new
    worker =
      Thread.new do
        Client.connection_pool.with_connection(prevent_permanent_checkout: true) do
          OpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
            principal = Client.find(actor.id)
            root = ClientToken.find(token.id)
            parent = ClientStepUpCeremonyTransaction.find(transaction.id)
            ready << connection.select_value("SELECT pg_backend_pid()").to_i
            proceed.pop
            IdentityTotpEnrollmentIssuer.call!(actor: principal, token: root, transaction: parent)
          end
        end
      rescue IdentityTotpCeremonyContract::Error => e
        e
      ensure
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
    backend_pid = Timeout.timeout(10) { ready.pop }
    ClientDeviceSession.transaction do
      device.lock!
      device.revoke!
      proceed << true
      Timeout.timeout(10) do
        loop do
          state =
            ClientDeviceSession.lease_connection.uncached do
              ClientDeviceSession.lease_connection.select_value(
                "SELECT wait_event_type FROM pg_stat_activity WHERE pid = #{Integer(backend_pid)}",
              )
            end
          break if state == "Lock"

          sleep 0.01
        end
      end
    end

    result = Timeout.timeout(10) { worker.value }

    assert_instance_of IdentityTotpCeremonyContract::Error, result
    assert_equal "TOTP enrollment device unavailable", result.message
    assert_equal 0,
                 ClientTotpCeremonyTransaction.where(step_up_ceremony_transaction_ref: transaction.transaction_id).count
    assert_equal 0, IdentityTotpCeremonyCandidate.where(actor_ref: actor.public_id).count
    assert_equal "pending", transaction.reload.status
    assert_equal 0, record.reload.attempt_count
  ensure
    proceed << true if proceed
    worker&.join
    record&.delete
    transaction&.delete
    device&.update!(current_refresh_token_id: nil)
    token&.delete
    device&.delete
    actor&.delete
  end
end
