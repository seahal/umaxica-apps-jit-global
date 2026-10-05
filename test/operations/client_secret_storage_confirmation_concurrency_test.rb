# frozen_string_literal: true

require "test_helper"
require "timeout"

class ClientSecretStorageConfirmationConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = %w(
    client_statuses client_visibilities client_mfa_levels client_mfa_statuses
    client_token_statuses client_token_kinds client_token_binding_methods client_token_dbsc_statuses
  )

  test "confirmation racing cancellation commits one consistent terminal state and releases the reservation" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
    )
    raw = SecureRandom.base58(32)
    candidate = ClientSecretCredential.create!(
      client: actor, issuance: issuance, name: "Confirmation cancellation race", password: raw,
      lookup_digest: SignSecretLookupDigest.digest(raw),
    )
    ClientSecretAuditOutbox.transaction do
      at = Client.database_now
      issuance.update!(presented_at: at)
      ClientSecretAuditOutbox.record!(
        actor_context: context, client_ref: actor.public_id, credential_ref: candidate.public_id,
        operation_ref: issuance.origin_operation_id, occurred_at: at, event_name: "secret.presented", item_count: 1,
      )
    end
    ready = Queue.new
    release = Queue.new
    ActiveRecord::Base.connection_handler.clear_active_connections!
    futures =
      %i(confirm cancel).map do |operation|
        Concurrent::Future.execute do
          AppZenithRecord.connected_to(role: :writing) do
            AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
              AppZenithRecord.transaction do
                connection.select_value("SELECT set_config('lock_timeout', '5000', true)")
                ready << connection.select_value("SELECT pg_backend_pid()")
                release.pop
                owner = Client.find(actor.id)
                bound = context.with(subject: owner)
                AppTicketRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
                  result =
                    case operation
                    when :confirm
                      ClientSecretStorageConfirmationCommitter.call!(
                        actor_context: bound, token: token, issuance: issuance,
                      )
                    when :cancel
                      ClientSecretManualIssuanceInvalidator.call!(
                        actor_context: bound, token: token, issuance: issuance, purge_after: 1.day,
                      )
                    end
                  result.state(at: Client.database_now)
                end
              end
            end
          end
        rescue ClientSecretStorageConfirmationCommitter::Denied, ClientSecretManualIssuanceInvalidator::Denied
          :denied
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
    terminal = issuance.reload.state(at: Client.database_now)

    assert_equal 2, pids.uniq.length
    assert_includes %i(confirmed canceled), terminal
    assert_equal [:denied, terminal].sort, results.sort
    counts = ClientSecretCapacityQuery.call(client: actor, at: Client.database_now)

    assert_equal 0, counts.reserved_count
    assert_equal(((terminal == :confirmed) ? 1 : 0), counts.active_count)
    assert_equal((terminal == :confirmed), candidate.reload.available_at?(at: Client.database_now))
    events = ClientSecretAuditOutbox.where(client_ref: actor.public_id)

    assert_equal(((terminal == :confirmed) ? 1 : 0), events.where(event_name: "secret.storage_declared").count)
    assert_equal(((terminal == :canceled) ? 1 : 0), events.where(event_name: "secret.issuance_canceled").count)
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

  test "separate writers converge duplicate confirmations on one declaration and one credential activation" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
    )
    raw = SecureRandom.base58(32)
    candidate = ClientSecretCredential.create!(
      client: actor, issuance: issuance, name: "Concurrent confirmation", password: raw,
      lookup_digest: SignSecretLookupDigest.digest(raw),
    )
    ClientSecretAuditOutbox.transaction do
      at = Client.database_now
      issuance.update!(presented_at: at)
      ClientSecretAuditOutbox.record!(
        actor_context: context, client_ref: actor.public_id, credential_ref: candidate.public_id,
        operation_ref: issuance.origin_operation_id, occurred_at: at, event_name: "secret.presented", item_count: 1,
      )
    end
    ready = Queue.new
    release = Queue.new
    ActiveRecord::Base.connection_handler.clear_active_connections!
    futures =
      2.times.map do
        Concurrent::Future.execute do
          AppZenithRecord.connected_to(role: :writing) do
            AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
              AppZenithRecord.transaction do
                connection.select_value("SELECT set_config('lock_timeout', '5000', true)")
                ready << connection.select_value("SELECT pg_backend_pid()")
                release.pop
                owner = Client.find(actor.id)
                bound = context.with(subject: owner)
                AppTicketRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
                  result = ClientSecretStorageConfirmationCommitter.call!(
                    actor_context: bound, token: token, issuance: issuance,
                  )
                  [result.public_id, result.confirmed_at]
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
    assert_equal 1, results.uniq.length
    assert_equal issuance.reload.confirmed_at, candidate.reload.confirmed_at
    assert_equal 1, ClientSecretAuditOutbox.where(client_ref: actor.public_id, event_name: "secret.created").count
    declarations = ClientSecretAuditOutbox.where(client_ref: actor.public_id, event_name: "secret.storage_declared")

    assert_equal 1, declarations.count
    counts = ClientSecretCapacityQuery.call(client: actor, at: Client.database_now)

    assert_equal 1, counts.active_count
    assert_equal 0, counts.reserved_count
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
end
