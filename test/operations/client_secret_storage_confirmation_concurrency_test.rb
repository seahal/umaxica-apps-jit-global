# frozen_string_literal: true

require "test_helper"
require "concurrent/executor/simple_executor_service"
require "timeout"

class ClientSecretStorageConfirmationConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = %w(
    client_statuses client_visibilities client_security_modes client_mfa_statuses
    client_token_statuses client_token_kinds client_token_binding_methods client_token_dbsc_statuses
  )

  test "confirmation racing cancellation commits one consistent terminal state and releases the reservation" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up", last_step_up_full_reauthentication: false,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
    )
    raw = SecureRandom.base58(32)
    candidate = ClientSecretCredential.create!(
      client: actor, issuance: issuance, name: "Confirmation cancellation race", password: raw,
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
        Concurrent::Future.execute(executor: Concurrent::SimpleExecutorService.new) do
          AppZenithRecord.connected_to(role: :writing) do
            AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
              AppZenithRecord.transaction do
                connection.select_value("SELECT set_config('lock_timeout', '5000', true)")
                ready << connection.select_value("SELECT pg_backend_pid()")
                release.pop
                owner = Client.find(actor.id)
                bound = context.with(subject: owner)
                OpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
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
      # An Identity is physically erased only once it has lapsed and is purgeable.
      actor.reload.update!(discard_at: actor.created_at, purge_eligible_at: actor.created_at)
      destroy_test_client_after_cross_database_cleanup!(actor)
    end
  end

  test "confirmation racing claim never authenticates an unconfirmed candidate or reactivates a claim" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up", last_step_up_full_reauthentication: false,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
    )
    ClientSecretPresentationIssuer.prepare!(actor_context: context, token: token, issuance: issuance)
    raw = ClientSecretPresentationIssuer.call!(actor_context: context, token: token, issuance: issuance).first
    admission = OidcTestEntry.issue!(
      surface: "app",
      intent: "sign_in",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: admission.reference)
    _auth_session, raw_sid =
      begin
        admission_binding = binding
        admission_session, admission_raw_sid = admission_binding.class.auth_admission_session_class.issue!
        admission_binding.attach_auth_session!(
          auth_session: admission_session,
          confirmation_ref: SecureRandom.uuid,
        )
        admission_binding.confirm_base!(
          base_token: nil,
          browser_digest: AuthAdmissionBinding.browser_digest(
            surface: admission_binding.class.auth_admission_surface_name,
            entry_ref: admission_binding.entry_ref,
            nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          ),
        )
        [admission_session, admission_raw_sid]
      end
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: admission.reference, surface: "app", expected_intent: "sign_in",
      binding:, raw_auth_sid: raw_sid,
    )
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff",
      authorization_transaction_ref: admission.transaction.transaction_id,
    )
    transaction = admission.transaction

    assert_nil ClientSecretClaimCommitter.call_for_oidc!(client: actor, secret: raw, transaction:, ceremony:)
    ready = Queue.new
    release = Queue.new
    ActiveRecord::Base.connection_handler.clear_active_connections!
    futures =
      %i(confirm claim).map do |operation|
        Concurrent::Future.execute(executor: Concurrent::SimpleExecutorService.new) do
          AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
            connection.execute("SET lock_timeout = '5000'")
            ready << connection.select_value("SELECT pg_backend_pid()")
            release.pop
            OpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
              if operation == :confirm
                owner = Client.find(actor.id)
                ClientSecretStorageConfirmationCommitter.call!(
                  actor_context: context.with(subject: owner), token: token, issuance: issuance,
                ).public_id
              else
                ClientSecretClaimCommitter.call_for_oidc!(
                  client: actor, secret: raw, transaction:,
                  ceremony:,
                )&.public_id
              end
            end
          ensure
            connection.execute("RESET lock_timeout")
          end
        ensure
          # Release model-clock leases before the dedicated worker exits.
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end
      end
    pids, results =
      Timeout.timeout(20) do
        identifiers = [ready.pop, ready.pop]
        2.times { release << true }
        [identifiers, futures.map(&:value!)]
      end
    candidate = ClientSecretCredential.find_by!(issuance_id: issuance.id)

    assert_equal 2, pids.uniq.length
    assert_equal issuance.public_id, results.first
    assert_equal issuance.reload.confirmed_at, candidate.confirmed_at
    if results.last
      assert_equal candidate.public_id, results.last
      assert_operator candidate.claimed_at, :>=, candidate.confirmed_at
    else
      assert_nil candidate.claimed_at
      assert ClientSecretClaimCommitter.call_for_oidc!(client: actor, secret: raw, transaction:, ceremony:)
    end
    claim_operation = candidate.reload.claim_operation_id
    assert_raises(ClientSecretStorageConfirmationCommitter::Denied) do
      ClientSecretStorageConfirmationCommitter.call!(actor_context: context, token: token, issuance: issuance)
    end

    assert_equal claim_operation, candidate.reload.claim_operation_id
    assert_nil ClientSecretLookupQuery.call(client: actor, secret: raw)
    assert_nil ClientSecretClaimCommitter.call_for_oidc!(client: actor, secret: raw, transaction:, ceremony:)
    events = ClientSecretAuditOutbox.where(client_ref: actor.public_id)

    assert_equal 1, events.where(event_name: "secret.storage_declared").count
    assert_equal 1, events.where(event_name: "secret.claimed").count
    capacity = ClientSecretCapacityQuery.call(client: actor, at: Client.database_now)

    assert_equal 0, capacity.active_count
    assert_equal 0, capacity.reserved_count
    assert_equal 0, ClientSecretSignInReceipt.where(credential_ref: candidate.public_id).count
    assert_equal 1, ClientToken.where(user_id: actor.id).count
  ensure
    2.times { release << true } if release
    futures&.each { |future| future.wait(10) }
    flow = transaction&.reload&.secret_sign_in_flow
    transaction&.update_columns(secret_sign_in_flow_id: nil)
    ceremony&.destroy!
    flow&.destroy!
    if actor
      ClientSecretAuditOutbox.where(client_ref: actor.public_id).find_each(&:destroy!)
      ClientSecretCredential.where(client_id: actor.id).find_each(&:destroy!)
      ClientSecretIssuance.where(client_id: actor.id).find_each(&:destroy!)
      token&.destroy!
      # An Identity is physically erased only once it has lapsed and is purgeable.
      actor.reload.update!(discard_at: actor.created_at, purge_eligible_at: actor.created_at)
      destroy_test_client_after_cross_database_cleanup!(actor)
    end
  end

  test "concurrent confirmations spend one Step-Up once and activate one credential" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up", last_step_up_full_reauthentication: false,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
    )
    raw = SecureRandom.base58(32)
    candidate = ClientSecretCredential.create!(
      client: actor, issuance: issuance, name: "Concurrent confirmation", password: raw,
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
        Concurrent::Future.execute(executor: Concurrent::SimpleExecutorService.new) do
          AppZenithRecord.connected_to(role: :writing) do
            AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
              AppZenithRecord.transaction do
                connection.select_value("SELECT set_config('lock_timeout', '5000', true)")
                ready << connection.select_value("SELECT pg_backend_pid()")
                release.pop
                owner = Client.find(actor.id)
                bound = context.with(subject: owner)
                OpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
                  result = ClientSecretStorageConfirmationCommitter.call!(
                    actor_context: bound, token: token, issuance: issuance,
                  )
                  [result.public_id, result.confirmed_at]
                end
              end
            end
          end
        rescue ClientSecretStorageConfirmationCommitter::Denied
          :denied
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
    successful_results = results.reject { |result| result == :denied }

    assert_equal 1, successful_results.length
    assert_equal 1, results.count(:denied)
    assert_equal issuance.public_id, successful_results.first.first
    assert_nil token.reload.last_step_up_at
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
      # An Identity is physically erased only once it has lapsed and is purgeable.
      actor.reload.update!(discard_at: actor.created_at, purge_eligible_at: actor.created_at)
      destroy_test_client_after_cross_database_cleanup!(actor)
    end
  end
end
