# frozen_string_literal: true

require "test_helper"
require "concurrent/executor/simple_executor_service"
require "timeout"

class PasskeyMutationConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  uses_transaction :test_rename_waits_for_device_revocation_and_refuses_the_stale_authority_after_the_lock_is_released,
                   :test_removal_waits_for_device_revocation_and_refuses_the_stale_authority_after_the_lock_is_released

  %i(rename removal).each do |operation|
    test "#{operation} waits for device revocation and refuses the stale authority after the lock is released" do
      actor = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        id: 1_000_000_000_000 + SecureRandom.random_number(1_000_000_000),
      )
      key = actor.client_passkeys.create!(
        webauthn_id: SecureRandom.uuid, public_key: "target-key", description: "Original", uv_verified_at: Time.current,
      )
      survivor = actor.client_passkeys.create!(
        webauthn_id: SecureRandom.uuid, public_key: "survivor-key", uv_verified_at: Time.current,
      )
      token = ClientToken.create!(authentication_epoch: 0, user: actor)
      token.update!(
        last_step_up_at: Time.current, last_step_up_scope: "settings_passkey", last_step_up_method: "passkey",
        last_step_up_credential_ref: key.public_id, last_step_up_session_public_id: token.public_id,
        last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
        last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
        last_step_up_full_reauthentication: false,
      )

      assert ClientPasskeyPolicy.new(key, user: actor).management_authorized?(
        token: token, now: ClientToken.database_now,
      )
      mutation = (operation == :rename) ? IdentityPasskeyNameCommitter : IdentityCredentialRemovalCommitter
      device = token.device_session
      ready = Queue.new
      start = Queue.new
      waiting_on_device = false
      worker = nil
      ActiveRecord::Base.connection_handler.clear_active_connections!
      device.with_lock do
        blocker =
          ClientDeviceSession.connection_pool.with_connection do |connection|
            connection.select_value("SELECT pg_backend_pid()")
          end
        worker =
          Concurrent::Future.execute(executor: Concurrent::SimpleExecutorService.new) do
            ClientToken.connection_class_for_self.connected_to(role: :writing) do
              ClientToken.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
                ready << connection.select_value("SELECT pg_backend_pid()")
                start.pop
                owner = Client.find(actor.id)
                session = ClientToken.find(token.id)
                target = ClientPasskey.find(key.id)
                case operation
                when :rename
                  begin
                    mutation.call!(actor: owner, token: session, passkey: target, description: "Changed")
                  rescue IdentityPasskeyNameCommitter::Denied
                    :denied
                  end
                when :removal
                  mutation.call!(actor: owner, credential: target, current_session: session)
                else raise ArgumentError, "unsupported mutation"
                end
              end
            end
          ensure
            ActiveRecord::Base.connection_handler.clear_active_connections!
          end
        backend = Timeout.timeout(10) { ready.pop }

        assert_not_equal blocker, backend, "the race requires independent PostgreSQL connections"
        start << true
        Timeout.timeout(10) do
          loop do
            waiting_on_device =
              ClientToken.uncached do
                ClientToken.connection_pool.with_connection do |connection|
                  connection.select_value(
                    ClientToken.sanitize_sql_array(
                      ["SELECT ? = ANY(pg_blocking_pids(?))", blocker,
                       backend,],
                    ),
                  )
                end
              end
            if worker.complete?
              worker.value!
              break
            end
            break if waiting_on_device

            Thread.pass
          end
        end
        device.revoke!
      end
      result = Timeout.timeout(10) { worker.value! }

      assert waiting_on_device, "mutation must serialize against the device row before reading its authority"
      assert_equal((operation == :rename) ? :denied : false, result)
      assert_equal "Original", key.reload.description
      assert_equal ClientPasskeyStatus::ACTIVE, key.status_id
      assert_predicate device.reload, :revoked?
    ensure
      start << true if start
      worker&.wait(10)
      key&.delete
      survivor&.delete
      token&.delete
      device&.delete
      actor&.delete
    end
  end
end
