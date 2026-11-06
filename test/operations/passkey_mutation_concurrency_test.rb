# frozen_string_literal: true

require "test_helper"
require "concurrent/executor/simple_executor_service"
require "timeout"

class PasskeyMutationConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  uses_transaction :test_rename_waits_for_device_revocation_and_refuses_the_stale_authority_after_the_lock_is_released,
                   :test_removal_waits_for_device_revocation_and_refuses_the_stale_authority_after_the_lock_is_released

  test "a source audit failure rolls back the rename and leaves OP evidence reusable" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    key = actor.client_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "commit-order-key", description: "Original",
      uv_verified_at: Time.current,
    )
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    evidence_now = ClientToken.database_now
    token.update!(root_login_established_at: evidence_now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now: evidence_now)
    token.device_session_record!
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(evidence_now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: evidence_now + 1.hour,
    )
    grant.issue_refresh_token!(now: evidence_now)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: evidence_now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    device = token.device_session_record!
    commits = []
    observer =
      lambda do |_name, _start, _finish, _id, event|
        commits << event.fetch(:connection).pool.db_config.name if event.fetch(:sql).start_with?("COMMIT")
      end
    failure = ->(**) { raise ActiveRecord::ConnectionNotEstablished, "injected source audit failure" }
    ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
      PasskeyAuditOutbox.stub(:record_for!, failure) do
        assert_raises(IdentityPasskeyNameCommitter::DependencyFailure) do
          IdentityPasskeyNameCommitter.call!(
            actor: actor, token: token, passkey: key, description: "Failed", step_up_evidence: evidence,
          )
        end
      end
    end

    assert_empty commits
    assert OpAppGrant.exists?(public_id: evidence.sid)
    assert_equal "Original", key.reload.description
    assert_equal 0, ClientPasskeyAuditOutbox.where(external_id: key.external_id).count
    OpBaseAppRecord.transaction do
      assert StepUpEvidenceVerifier.call(evidence:, actor:, token: token.reload)
    end
  ensure
    key&.delete
    OpAppGrant.where(client_token_id: token&.id).delete_all if token
    token&.association(:op_app_grants)&.reset
    token&.delete
    device&.delete
    actor&.delete
  end

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
      evidence_now = ClientToken.database_now
      token.update!(root_login_established_at: evidence_now, established_authentication_method: "passkey")
      token.rotate_refresh_token!(now: evidence_now)
      token.device_session_record!
      oidc_client = OidcClientRegistry.find!("base-app-ww")
      grant = OpAppGrant.create!(
        authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
        oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
        oidc_auth_time: Time.at(evidence_now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
        oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: evidence_now + 1.hour,
      )
      grant.issue_refresh_token!(now: evidence_now)
      evidence = StepUpEvidenceValue.new(
        acr: grant.oidc_acr, amr: ["passkey"], auth_time: evidence_now.to_i, sid: grant.public_id,
        sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
        aud: [oidc_client.aud], jti: grant.oidc_jti,
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
                    mutation.call!(
                      actor: owner, token: session, passkey: target, description: "Changed",
                      step_up_evidence: evidence,
                    )
                  rescue IdentityPasskeyNameCommitter::Denied
                    :denied
                  end
                when :removal
                  mutation.call!(
                    actor: owner, credential: target, current_session: nil, step_up_evidence: evidence,
                  )
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
      OpAppGrant.where(client_token_id: token&.id).delete_all if token
      token&.association(:op_app_grants)&.reset
      token&.delete
      device&.delete
      actor&.delete
    end
  end
end
