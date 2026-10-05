# frozen_string_literal: true

require "test_helper"
require "timeout"

class ClientSecretManualReservationConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = %w(
    client_statuses client_visibilities client_mfa_levels client_mfa_statuses
    client_token_statuses client_token_kinds client_token_binding_methods client_token_dbsc_statuses
  )

  test "separate writer connections and sessions serialize manual reservations at eighteen nineteen and twenty" do
    [18, 19, 20].each do |count|
      actor = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::BOTH)
      tokens =
        Array.new(2) do
          token = ClientToken.create!(user: actor)
          token.update!(
            last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
            last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
            last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
          )
          token
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
          lookup_digest: SignSecretLookupDigest.digest(raw), confirmed_at: now,
        )
      end
      ready = Queue.new
      release = Queue.new
      ActiveRecord::Base.connection_handler.clear_active_connections!
      futures =
        tokens.map do |token|
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
                    ClientSecretManualReservationIssuer.call!(
                      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
                    )
                  end
                  :reserved
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
      assert_equal(((count == 20) ? %i(full full) : %i(conflict reserved)), results.sort)
      capacity = ClientSecretCapacityQuery.call(client: actor, at: Client.database_now)

      assert_equal count, capacity.active_count
      assert_equal(((count == 20) ? 0 : 1), capacity.reserved_count)
      assert_operator capacity.active_count + capacity.reserved_count, :<=, 20
      assert_equal(((count == 20) ? 0 : 1), ClientSecretAuditOutbox.where(client_ref: actor.public_id).count)
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

  test "expiry cleanup racing a new reservation preserves writer capacity and the new operation" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::BOTH)
    token = ClientToken.create!(user: actor)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
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
        lookup_digest: SignSecretLookupDigest.digest(raw), confirmed_at: now,
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
      lookup_digest: SignSecretLookupDigest.digest(raw),
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
        lookup_digest: SignSecretLookupDigest.digest(raw), confirmed_at: now,
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
