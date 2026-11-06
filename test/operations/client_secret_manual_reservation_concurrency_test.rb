# frozen_string_literal: true

require "test_helper"
require "concurrent/executor/simple_executor_service"
require "timeout"

class ClientSecretManualReservationConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = %w(
    client_statuses client_visibilities client_security_modes client_mfa_statuses
    client_token_statuses client_token_kinds client_token_binding_methods client_token_dbsc_statuses
  )

  test "reservation waits for device revocation and refuses after it commits" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::BOTH,
    )
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    evidence_by_token_id ||= {}
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
    evidence_by_token_id[token.id] = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: evidence_now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    device_id = token.device_session_record!.id
    operation_id = SecureRandom.uuid
    locked = Queue.new
    release = Queue.new
    ready = Queue.new

    revoker =
      Concurrent::Future.execute(executor: Concurrent::SimpleExecutorService.new) do
        OpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
          OpBaseAppRecord.transaction do
            device = ClientDeviceSession.lock.find(device_id)
            locked << connection.select_value("SELECT pg_backend_pid()")
            release.pop
            device.revoke!
          end
        end
      ensure
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end

    revoker_pid = Timeout.timeout(10) { locked.pop }
    reserver =
      Concurrent::Future.execute(executor: Concurrent::SimpleExecutorService.new) do
        AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
          OpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
            ready << connection.select_value("SELECT pg_backend_pid()")
            owner = Client.find(actor.id)
            context = ActorValuesContext.empty.with(subject: owner, actor_type: :client, tld: :app, surface: :base)
            ClientSecretManualReservationIssuer.call!(
              actor_context: context, token: ClientToken.find(token.id), operation_id: operation_id,
              expires_after: 1.minute,
              step_up_evidence: evidence_by_token_id[token.id],
            )
          end
        end
      rescue ClientSecretManualReservationIssuer::Denied => e
        e.message
      ensure
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end

    reserver_pid = Timeout.timeout(10) { ready.pop }
    connection = OpBaseAppRecord.lease_connection
    Timeout.timeout(10) do
      loop do
        waiting =
          connection.uncached do
            connection.select_value(
              "SELECT #{Integer(revoker_pid)} = ANY(pg_blocking_pids(#{Integer(reserver_pid)}))",
            )
          end
        break if waiting

        sleep 0.01
      end
    end

    assert_not_equal revoker_pid, reserver_pid
    release << true

    assert revoker.value!
    assert_equal "Secret reservation device is unavailable", reserver.value!
    assert_predicate OpBaseAppRecord.uncached { ClientDeviceSession.find(device_id) }, :revoked?
    assert_empty ClientSecretIssuance.where(origin_operation_id: operation_id)
    assert_empty ClientSecretAuditOutbox.where(operation_ref: operation_id)
  ensure
    release << true if release
    revoker&.wait(10)
    reserver&.wait(10)
    if actor
      ClientSecretAuditOutbox.where(client_ref: actor.public_id).find_each(&:destroy!)
      ClientSecretIssuance.where(client_id: actor.id).find_each(&:destroy!)
      OpAppGrant.where(client_token_id: ClientToken.where(user_id: actor.id)).delete_all
      token&.association(:op_app_grants)&.reset
      token&.destroy!
      actor.reload.update!(discard_at: actor.created_at, purge_eligible_at: actor.created_at)
      destroy_test_client_after_cross_database_cleanup!(actor)
    end
  end

  test "separate writers serialize manual and registered Passkey reservations at eighteen nineteen and twenty" do
    [18, 19, 20].product([%i(manual manual), %i(manual passkey), %i(passkey passkey)]).each do |count, paths|
      actor = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
        visibility_id: ClientVisibility::BOTH,
      )
      evidence_by_token_id = {}
      tokens =
        Array.new(2) do |_index|
          token = ClientToken.create!(authentication_epoch: 0, user: actor)
          evidence_now = ClientToken.database_now
          token.update!(root_login_established_at: evidence_now, established_authentication_method: "passkey")
          token.rotate_refresh_token!(now: evidence_now)
          token.device_session_record!
          oidc_client = OidcClientRegistry.find!("base-app-ww")
          grant = OpAppGrant.create!(
            authentication_epoch: token.authentication_epoch,
            client_token: token,
            oidc_client_id: oidc_client.client_id,
            oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
            oidc_auth_time: Time.at(evidence_now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
            oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: evidence_now + 1.hour,
          )
          grant.issue_refresh_token!(now: evidence_now)
          evidence_by_token_id[token.id] = StepUpEvidenceValue.new(
            acr: grant.oidc_acr, amr: ["passkey"], auth_time: evidence_now.to_i, sid: grant.public_id,
            sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
            aud: [oidc_client.aud], jti: grant.oidc_jti,
          )
          token
        end
      passkeys =
        paths.each_with_index.map do |path, _index|
          actor.client_passkeys.create!(
            webauthn_id: SecureRandom.uuid, public_key: "public-key",
          ) if path == :passkey
        end
      now = Client.database_now
      count.times do
        completed = ClientSecretIssuance.create!(
          client: actor, origin_operation_id: SecureRandom.uuid, origin: "manual", attempt_number: 1,
          browser_session_ref: tokens.first.public_id, planned_count: 1, expires_at: now + 1.hour,
          presented_at: now, confirmed_at: now,
        )
        raw = SecureRandom.base58(32)
        ClientSecretCredential.create!(
          client: actor, issuance: completed, name: "Concurrent capacity fixture", password: raw,
          confirmed_at: now,
        )
      end
      ready = Queue.new
      release = Queue.new
      ActiveRecord::Base.connection_handler.clear_active_connections!
      futures =
        tokens.each_with_index.map do |token, index|
          Concurrent::Future.execute(executor: Concurrent::SimpleExecutorService.new) do
            AppZenithRecord.connected_to(role: :writing) do
              AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
                AppZenithRecord.transaction do
                  connection.select_value("SELECT set_config('lock_timeout', '5000', true)")
                  ready << connection.select_value("SELECT pg_backend_pid()")
                  release.pop
                  owner = Client.find(actor.id)
                  context = ActorValuesContext.empty.with(
                    subject: owner, actor_type: :client, tld: :app,
                    surface: :base,
                  )
                  OpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
                    issuance =
                      if paths[index] == :manual
                        ClientSecretManualReservationIssuer.call!(
                          actor_context: context, token: token, operation_id: SecureRandom.uuid,
                          expires_after: 1.minute,
                          step_up_evidence: evidence_by_token_id[token.id],
                        )
                      else
                        ClientSecretPasskeyReservationIssuer.call!(
                          actor_context: context, token: token, passkey: passkeys[index], expires_after: 1.minute,
                          step_up_evidence: evidence_by_token_id[token.id],
                        )
                      end
                    issuance.planned_count.zero? ? :omitted : :reserved
                  end
                end
              end
            end
          rescue ClientSecretIssuanceCountValue::ReservationConflict
            :conflict
          rescue ClientSecretManualReservationIssuer::CapacityFull
            :full
          rescue StandardError => e
            ready << e
            raise
          ensure
            # Release model-clock leases before the dedicated worker exits.
            ActiveRecord::Base.connection_handler.clear_active_connections!
          end
        end
      pids = nil
      results =
        Timeout.timeout(20) do
          pids = [ready.pop, ready.pop]
          2.times { release << true }
          futures.map(&:value!)
        end

      assert_equal 2, pids.uniq.length
      expected =
        if count == 20
          paths.map { |path| (path == :manual) ? :full : :omitted }
        else
          %i(conflict reserved)
        end

      assert_equal expected.sort, results.sort
      capacity = ClientSecretCapacityQuery.call(client: actor, at: Client.database_now)
      winner = results.index(:reserved)
      reserved_count = winner ? ((paths[winner] == :manual || count == 19) ? 1 : 2) : 0

      assert_equal count, capacity.active_count
      assert_equal reserved_count, capacity.reserved_count
      assert_operator capacity.active_count + capacity.reserved_count, :<=, 20
      assert_equal(
        (count == 20) ? paths.count(:passkey) : 1,
        ClientSecretAuditOutbox.where(client_ref: actor.public_id).count,
      )
      assert_equal 0, ClientSecretIssuance.where(client_id: actor.id, planned_count: 0).where.not(
        encrypted_payload: nil,
      ).count
    ensure
      2.times { release << true } if release
      futures&.each { |future| future.wait(10) }
      if actor
        ClientSecretAuditOutbox.where(client_ref: actor.public_id).find_each(&:destroy!)
        ClientSecretCredential.where(client_id: actor.id).find_each(&:destroy!)
        ClientSecretIssuance.where(client_id: actor.id).find_each(&:destroy!)
        passkeys&.compact&.each(&:destroy!)
        OpAppGrant.where(client_token_id: ClientToken.where(user_id: actor.id)).delete_all
        tokens&.each { |session| session.association(:op_app_grants).reset } if defined?(tokens) && tokens
        tokens&.each(&:destroy!)
        # An Identity is physically erased only once it has lapsed and is purgeable.
        actor.reload.update!(discard_at: actor.created_at, purge_eligible_at: actor.created_at)
        destroy_test_client_after_cross_database_cleanup!(actor)
      end
    end
  end

  test "expiry cleanup racing a new reservation preserves writer capacity and the new operation" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::BOTH,
    )
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    evidence_by_token_id ||= {}
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
    evidence_by_token_id[token.id] = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: evidence_now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    now = Client.database_now
    19.times do
      confirmed = ClientSecretIssuance.create!(
        client: actor, origin_operation_id: SecureRandom.uuid, origin: "manual", attempt_number: 1,
        browser_session_ref: token.public_id, planned_count: 1, expires_at: now + 1.hour,
        presented_at: now, confirmed_at: now,
      )
      raw = SecureRandom.base58(32)
      ClientSecretCredential.create!(
        client: actor, issuance: confirmed, name: "Expiry race fixture", password: raw,
        confirmed_at: now,
      )
    end
    old = ClientSecretIssuance.create!(
      client: actor, origin_operation_id: SecureRandom.uuid, origin: "manual", attempt_number: 1,
      browser_session_ref: token.public_id, planned_count: 1, expires_at: now - 1.second,
      created_at: now - 1.minute, encrypted_payload: "opaque-expiry-fixture",
    )
    raw = SecureRandom.base58(32)
    candidate = ClientSecretCredential.create!(
      client: actor, issuance: old, name: "Expired race fixture", password: raw,
    )
    job_id = ApplicationJob.new.job_id
    ready = Queue.new
    release = Queue.new
    ActiveRecord::Base.connection_handler.clear_active_connections!
    futures =
      2.times.map do |index|
        Concurrent::Future.execute(executor: Concurrent::SimpleExecutorService.new) do
          AppZenithRecord.connected_to(role: :writing) do
            AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
              AppZenithRecord.transaction do
                connection.select_value("SELECT set_config('lock_timeout', '5000', true)")
                ready << connection.select_value("SELECT pg_backend_pid()")
                release.pop
                if index.zero?
                  ClientSecretIssuanceExpiryInvalidator.call!(
                    issuance: old, executor_job_id: job_id, purge_after: 1.day,
                  )
                elsif index == 1
                  owner = Client.find(actor.id)
                  context = ActorValuesContext.empty.with(
                    subject: owner, actor_type: :client, tld: :app,
                    surface: :base,
                  )
                  OpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
                    ClientSecretManualReservationIssuer.call!(
                      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
                      step_up_evidence: evidence_by_token_id[token.id],
                    )
                  end
                else
                  raise ArgumentError, "unexpected expiry competitor"
                end
              end
            end
          end
        rescue StandardError => e
          ready << e
          raise
        ensure
          # Release model-clock leases before the dedicated worker exits.
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end
      end
    pids = nil
    results =
      Timeout.timeout(20) do
        pids = [ready.pop, ready.pop]
        2.times { release << true }
        futures.map(&:value!)
      end

    assert_equal 2, pids.uniq.length
    assert_equal :expired, results.first.state(at: Client.database_now)
    assert_equal :pending_presentation, results.last.state(at: Client.database_now)
    assert_nil old.reload.encrypted_payload
    assert_nil old.canceled_at
    assert candidate.reload.lapsed?(Client.database_now)
    capacity = ClientSecretCapacityQuery.call(client: actor, at: Client.database_now)

    assert_equal 19, capacity.active_count
    assert_equal 1, capacity.reserved_count
    assert_equal 3, ClientSecretAuditOutbox.where(client_ref: actor.public_id).count
  ensure
    2.times { release << true } if release
    futures&.each { |future| future.wait(10) }
    if actor
      ClientSecretAuditOutbox.where(client_ref: actor.public_id).find_each(&:destroy!)
      ClientSecretCredential.where(client_id: actor.id).find_each(&:destroy!)
      ClientSecretIssuance.where(client_id: actor.id).find_each(&:destroy!)
      OpAppGrant.where(client_token_id: ClientToken.where(user_id: actor.id)).delete_all
      token&.association(:op_app_grants)&.reset
      token&.destroy!
      # An Identity is physically erased only once it has lapsed and is purgeable.
      actor.reload.update!(discard_at: actor.created_at, purge_eligible_at: actor.created_at)
      destroy_test_client_after_cross_database_cleanup!(actor)
    end
  end

  test "cancellation racing another session reservation never exceeds capacity or revives the old operation" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::BOTH,
    )
    evidence_by_token_id = {}
    tokens =
      Array.new(2) do
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
        evidence_by_token_id[token.id] = StepUpEvidenceValue.new(
          acr: grant.oidc_acr, amr: ["passkey"], auth_time: evidence_now.to_i, sid: grant.public_id,
          sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
          aud: [oidc_client.aud], jti: grant.oidc_jti,
        )
        token
      end
    now = Client.database_now
    19.times do
      completed = ClientSecretIssuance.create!(
        client: actor, origin_operation_id: SecureRandom.uuid, origin: "manual", attempt_number: 1,
        browser_session_ref: tokens.first.public_id, planned_count: 1, expires_at: now + 1.hour,
        presented_at: now, confirmed_at: now,
      )
      raw = SecureRandom.base58(32)
      ClientSecretCredential.create!(
        client: actor, issuance: completed, name: "Concurrent cancellation fixture", password: raw,
        confirmed_at: now,
      )
    end
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    old = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: tokens.first, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      step_up_evidence: evidence_by_token_id[tokens.first.id],
    )
    ready = Queue.new
    release = Queue.new
    ActiveRecord::Base.connection_handler.clear_active_connections!
    futures =
      tokens.each_with_index.map do |token, index|
        Concurrent::Future.execute(executor: Concurrent::SimpleExecutorService.new) do
          AppZenithRecord.connected_to(role: :writing) do
            AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
              AppZenithRecord.transaction do
                connection.select_value("SELECT set_config('lock_timeout', '5000', true)")
                ready << connection.select_value("SELECT pg_backend_pid()")
                release.pop
                owner = Client.find(actor.id)
                bound = ActorValuesContext.empty.with(subject: owner, actor_type: :client, tld: :app, surface: :base)
                OpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
                  if index.zero?
                    ClientSecretManualIssuanceInvalidator.call!(
                      actor_context: bound, token: token, issuance: old, purge_after: 1.day,
                      step_up_evidence: evidence_by_token_id[token.id],
                    )
                    :canceled
                  elsif index == 1
                    ClientSecretManualReservationIssuer.call!(
                      actor_context: bound, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
                      step_up_evidence: evidence_by_token_id[token.id],
                    )
                    :reserved
                  else
                    raise ArgumentError, "unexpected competing operation"
                  end
                end
              end
            end
          end
        rescue ClientSecretIssuanceCountValue::ReservationConflict
          :conflict
        rescue StandardError => e
          ready << e
          raise
        ensure
          # Release model-clock leases before the dedicated worker exits.
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end
      end
    pids = nil
    results =
      Timeout.timeout(20) do
        pids = [ready.pop, ready.pop]
        2.times { release << true }
        futures.map(&:value!)
      end

    assert_equal 2, pids.uniq.length
    assert_equal :canceled, results.first
    assert_includes %i(reserved conflict), results.last
    assert_equal :canceled, old.reload.state(at: Client.database_now)
    capacity = ClientSecretCapacityQuery.call(client: actor, at: Client.database_now)

    assert_equal 19, capacity.active_count
    assert_equal(((results.last == :reserved) ? 1 : 0), capacity.reserved_count)
    assert_operator capacity.active_count + capacity.reserved_count, :<=, 20
    assert_equal 1, ClientSecretAuditOutbox.where(
      operation_ref: old.origin_operation_id, event_name: "secret.issuance_canceled",
    ).count
  ensure
    2.times { release << true } if release
    futures&.each { |future| future.wait(10) }
    if actor
      ClientSecretAuditOutbox.where(client_ref: actor.public_id).find_each(&:destroy!)
      ClientSecretCredential.where(client_id: actor.id).find_each(&:destroy!)
      ClientSecretIssuance.where(client_id: actor.id).find_each(&:destroy!)
      OpAppGrant.where(client_token_id: ClientToken.where(user_id: actor.id)).delete_all
      tokens&.each { |session| session.association(:op_app_grants).reset } if defined?(tokens) && tokens
      tokens&.each(&:destroy!)
      # An Identity is physically erased only once it has lapsed and is purgeable.
      actor.reload.update!(discard_at: actor.created_at, purge_eligible_at: actor.created_at)
      destroy_test_client_after_cross_database_cleanup!(actor)
    end
  end
end
