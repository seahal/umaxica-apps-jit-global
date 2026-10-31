# frozen_string_literal: true

require "test_helper"
require "timeout"

class IdentityStepUpTotpDeviceConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "revocation commits during source verification and prevents Ticket evidence" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE,
    )
    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    token = ClientToken.create!(
      authentication_epoch: 0, id: SecureRandom.random_number(1 << 60) + 1_000_000_000, user: actor,
    )
    device = token.device_session_record!
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: actor.public_id, session_ref: token.public_id, required_scope: "settings_email",
      required_aal: "none", allowed_methods: ["totp"], return_to: "/identity/emails",
    )
    record = ClientStepUpSession.create!(
      user_token: token, step_up_ceremony_transaction_ref: transaction.transaction_id,
      scope: transaction.required_scope, return_to: transaction.return_to,
      status: "PENDING", discard_at: transaction.expires_at,
    )
    code = ROTP::TOTP.new(credential.private_key).now
    ready = Queue.new
    proceed = Queue.new
    consumer = TotpWindowConsumer.method(:call)
    pause_after_verification =
      lambda do |**arguments|
        result = consumer.call(**arguments)
        ready << result.accepted?
        proceed.pop
        result
      end
    worker = nil
    TotpWindowConsumer.stub(:call, pause_after_verification) do
      worker =
        Thread.new do
          Client.connection_pool.with_connection(prevent_permanent_checkout: true) do
            OpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
              IdentityStepUpTotpVerificationCommitter.call!(
                actor: Client.find(actor.id), transaction: ClientStepUpCeremonyTransaction.find(transaction.id),
                session_record: ClientStepUpSession.find(record.id), code: code,
                credential_public_id: credential.public_id,
              )
            end
          end
        rescue IdentityStepUpCeremonyContract::Error => e
          e
        ensure
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end

      assert Timeout.timeout(10) { ready.pop }
      device.revoke!
      proceed << true
      result = Timeout.timeout(10) { worker.value }

      assert_instance_of IdentityStepUpCeremonyContract::Error, result
      assert_equal "pending", transaction.reload.status
      assert_not_nil credential.reload.last_otp_at
      assert_nil token.reload.last_step_up_at
    end
  ensure
    proceed << true if proceed
    worker&.join
    record&.delete
    transaction&.delete
    device&.update!(current_refresh_token_id: nil)
    token&.delete
    device&.delete
    credential&.delete
    actor&.delete
  end
  test "Ticket evidence commits before a waiting device revocation" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE,
    )
    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    token = ClientToken.create!(
      authentication_epoch: 0, id: SecureRandom.random_number(1 << 60) + 1_000_000_000, user: actor,
    )
    device = token.device_session_record!
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: actor.public_id, session_ref: token.public_id, required_scope: "settings_email",
      required_aal: "none", allowed_methods: ["totp"], return_to: "/identity/emails",
    )
    record = ClientStepUpSession.create!(
      user_token: token, step_up_ceremony_transaction_ref: transaction.transaction_id,
      scope: transaction.required_scope, return_to: transaction.return_to,
      status: "PENDING", discard_at: transaction.expires_at,
    )
    code = ROTP::TOTP.new(credential.private_key).now
    ready = Queue.new
    proceed = Queue.new
    revoker_ready = Queue.new
    original_record = transaction.method(:record_verification!)
    pause_before_record =
      lambda do |**arguments|
        ready << true
        proceed.pop
        original_record.call(**arguments)
      end
    worker = nil
    revoker = nil
    ceremony = nil
    transaction.stub(:record_verification!, pause_before_record) do
      worker =
        Thread.new do
          Client.connection_pool.with_connection(prevent_permanent_checkout: true) do
            OpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
              IdentityStepUpTotpVerificationCommitter.call!(
                actor: Client.find(actor.id), transaction: transaction,
                session_record: ClientStepUpSession.find(record.id), code: code,
                credential_public_id: credential.public_id,
              )
            end
          end
        ensure
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end
      Timeout.timeout(10) { ready.pop }
      revoker =
        Thread.new do
          ClientDeviceSession.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
            target = ClientDeviceSession.find(device.id)
            revoker_ready << connection.select_value("SELECT pg_backend_pid()").to_i
            target.revoke!
          end
        ensure
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end
      backend_pid = Timeout.timeout(10) { revoker_ready.pop }
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
      proceed << true

      assert Timeout.timeout(10) { worker.value }
      assert Timeout.timeout(10) { revoker.value }
      assert_equal "verified", transaction.reload.status
      assert_predicate device.reload, :revoked?
      assert_not_nil credential.reload.last_otp_at
      assert_nil token.reload.last_step_up_at
      ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
      )
      result = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: transaction,
        ceremony_session_ref: ceremony.id.to_s,
      )
      requirement = StepUpRequirement.new(
        scope: "settings_email", step_up_required: true, allowed_methods: [:totp], purpose: "step_up",
        phishing_resistant_required: false, user_verification_required: false, full_reauthentication_required: false,
        ttl: 15.minutes, actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil, audience: "step_up:app",
        session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
      )
      error =
        assert_raises(IdentityStepUpCeremonyContract::Error) do
          IdentityStepUpCeremonyFreshnessCommitter.call!(
            actor: actor, token: token, transaction: transaction, requirement: requirement, raw_result: result.code,
          )
        end

      assert_equal "session_expired", error.code
      assert_equal "verified", transaction.reload.status
      assert_nil token.reload.last_step_up_at
      assert_not_predicate ceremony.reload, :completed?
    end
  ensure
    proceed << true if proceed
    worker&.join
    revoker&.join
    ceremony&.delete
    record&.delete
    transaction&.delete
    device&.update!(current_refresh_token_id: nil)
    token&.delete
    device&.delete
    credential&.delete
    actor&.delete
  end
end
