# frozen_string_literal: true

require "test_helper"
require "timeout"

class ClientSecretManualReservationConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = %w(
    client_statuses client_visibilities client_mfa_levels client_mfa_statuses
    client_token_statuses client_token_kinds client_token_binding_methods client_token_dbsc_statuses
  )

  test "separate writers serialize manual and registered Passkey reservations at eighteen nineteen and twenty" do
    [18, 19, 20].product([%i(manual manual), %i(manual passkey), %i(passkey passkey)]).each do |count, paths|
      actor = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::BOTH)
      tokens =
        Array.new(2) do |index|
          token = ClientToken.create!(user: actor)
          token.update!(
            last_step_up_at: ClientToken.database_now,
            last_step_up_scope: ((paths[index] == :manual) ? "settings_secret_credential" : "settings_passkey"),
            last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
            last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
            last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
            last_step_up_credential_ref: "test-step-up", last_step_up_full_reauthentication: false,
          )
          token
        end
      passkeys =
        paths.map do |path|
          actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public-key") if path == :passkey
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
          Concurrent::Future.execute do
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
                  AppTicketRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
                    issuance =
                      if paths[index] == :manual
                        ClientSecretManualReservationIssuer.call!(
                          actor_context: context, token: token, operation_id: SecureRandom.uuid,
                          expires_after: 1.minute,
                        )
                      else
                        ClientSecretPasskeyReservationIssuer.call!(
                          actor_context: context, token: token, passkey: passkeys[index], expires_after: 1.minute,
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
        tokens&.each(&:destroy!)
        actor.reload.destroy!
      end
    end
  end

  test "expiry cleanup racing a new reservation preserves writer capacity and the new operation" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::BOTH)
    token = ClientToken.create!(user: actor)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up", last_step_up_full_reauthentication: false,
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
        Concurrent::Future.execute do
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
                  AppTicketRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
                    ClientSecretManualReservationIssuer.call!(
                      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
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
      token&.destroy!
      actor.reload.destroy!
    end
  end

  test "cancellation racing another session reservation never exceeds capacity or revives the old operation" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::BOTH)
    tokens =
      Array.new(2) do
        token = ClientToken.create!(user: actor)
        token.update!(
          last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
          last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
          last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
          last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
          last_step_up_credential_ref: "test-step-up", last_step_up_full_reauthentication: false,
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
    )
    ready = Queue.new
    release = Queue.new
    ActiveRecord::Base.connection_handler.clear_active_connections!
    futures =
      tokens.each_with_index.map do |token, index|
        Concurrent::Future.execute do
          AppZenithRecord.connected_to(role: :writing) do
            AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
              AppZenithRecord.transaction do
                connection.select_value("SELECT set_config('lock_timeout', '5000', true)")
                ready << connection.select_value("SELECT pg_backend_pid()")
                release.pop
                owner = Client.find(actor.id)
                bound = ActorValuesContext.empty.with(subject: owner, actor_type: :client, tld: :app, surface: :base)
                AppTicketRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
                  if index.zero?
                    ClientSecretManualIssuanceInvalidator.call!(
                      actor_context: bound, token: token, issuance: old, purge_after: 1.day,
                    )
                    :canceled
                  elsif index == 1
                    ClientSecretManualReservationIssuer.call!(
                      actor_context: bound, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
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
      tokens&.each(&:destroy!)
      actor.reload.destroy!
    end
  end
end
