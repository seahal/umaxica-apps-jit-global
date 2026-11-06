# frozen_string_literal: true

require "test_helper"
require "concurrent/executor/simple_executor_service"
require "timeout"

class ClientSecretResolutionConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = %w(
    client_statuses client_visibilities client_security_modes client_mfa_statuses
    client_token_statuses client_token_kinds client_token_binding_methods client_token_dbsc_statuses
  )

  # This file loads only status fixtures, so nothing else wipes the rows it commits, and the
  # flows, resolutions, OIDC parents and chronicles it writes are not fixture tables at all.
  # A recycled synthetic principal id then makes a later journey teardown match them and abort
  # on their RESTRICT references, leaking rows that break fixture-load validation.
  setup do
    @initial_chronicle_ids = ClientChronicle.pluck(:id)
    @initial_resolution_ids = ClientSessionLimitResolutionTransaction.pluck(:id)
    @initial_authorization_ids = ClientOidcAuthorizationTransaction.pluck(:id)
    @initial_sign_in_flow_ids = ClientSignInFlow.pluck(:id)
    @initial_device_session_ids = ClientDeviceSession.pluck(:id)
    @initial_token_ids = ClientToken.pluck(:id)
    @initial_client_ids = Client.pluck(:id)
  end

  teardown do
    ClientChronicle.where.not(id: @initial_chronicle_ids).delete_all
    # Resolutions reference both the flow and the OIDC parent, so they go first.
    ClientSessionLimitResolutionTransaction.where.not(id: @initial_resolution_ids).delete_all
    # The OIDC parent holds the secret sign-in reference to the flow, so it goes before it.
    ClientOidcAuthorizationTransaction.where.not(id: @initial_authorization_ids).delete_all
    ClientSignInFlow.where.not(id: @initial_sign_in_flow_ids).delete_all
    # client_tokens references client_device_sessions with ON DELETE RESTRICT, so tokens go
    # first; the reverse reference is SET NULL and clears itself.
    ClientToken.where.not(id: @initial_token_ids).delete_all
    ClientDeviceSession.where.not(id: @initial_device_session_ids).delete_all
    Client.where.not(id: @initial_client_ids).delete_all
  end

  %i(cancellation expiration).each do |terminal|
    test "a separately connected selection blocked behind #{terminal} cannot revoke a session" do
      actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
      token = ClientToken.create!(authentication_epoch: 0, user: actor)
      now = ClientSignInFlow.database_now
      flow = ClientSignInFlow.create!(
        principal_id: actor.id, authentication_method: "secret", authentication_event_at: now,
        authentication_context: "normal", state_id: ClientSignInFlowState::SESSION_ISSUANCE_PENDING,
        nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.base58(32)), expires_at: now + 1.minute,
      )
      authorization = ClientOidcAuthorizationTransaction.create_transaction!(
        surface: "app", intent: "sign_in", client_id: "core-app-jp", redirect_uri: "https://example.com/callback",
        response_type: "code", scope: "openid", state: "state", nonce: "nonce",
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256", login_challenge: SecureRandom.base58(32),
        login_challenge_expires_at: now + 1.minute, expires_at: now + 1.minute,
      )
      authorization.update!(secret_sign_in_flow: flow)
      authorization.register_authentication!(
        actor_ref: actor.public_id, session_ref: nil, auth_method: "passcode", acr: "aal1",
        authentication_event_at: now,
      )
      raw_binding = SecureRandom.urlsafe_base64(32)
      binding_digest = ClientSessionLimitResolutionTransaction.digest_challenge(raw_binding)
      issued = ClientSessionLimitResolutionTransaction.issue!(
        actor: actor, sign_in_flow: flow, browser_binding_digest: binding_digest,
        oidc_authorization_transaction: authorization,
      )
      resolution = issued.transaction
      ready = Queue.new
      mutated = Queue.new
      future = nil
      source_pids = []
      actor.with_lock do
        source_pids << Client.lease_connection.select_value("SELECT pg_backend_pid()")
        future =
          Concurrent::Future.execute(executor: Concurrent::SimpleExecutorService.new) do
            AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
              connection.execute("SET lock_timeout = '10000'")
              ready << connection.select_value("SELECT pg_backend_pid()")
              begin
                resolution.select_session!(
                  actor: Client.find(actor.id),
                  challenge: issued.challenge,
                  session_ref: token.public_id,
                  browser_binding_digest: binding_digest,
                )
                mutated << true
                token.revoke!
                :accepted
              rescue FlowInvalidTransition
                :refused
              ensure
                connection.execute("RESET lock_timeout")
              end
            end
          ensure
            # Release model-clock leases before the dedicated worker exits.
            ActiveRecord::Base.connection_handler.clear_active_connections!
          end
        worker_pid = Timeout.timeout(10) { ready.pop }
        source_pids << worker_pid
        Timeout.timeout(10) do
          loop do
            if future.complete?
              raise RuntimeError, "selection finished before the lock barrier: #{future.value!.inspect}"
            end

            blocked =
              Client.uncached do
                Client.lease_connection.select_value(
                  "SELECT cardinality(pg_blocking_pids(#{Integer(worker_pid)})) > 0",
                )
              end
            break if blocked

            Thread.pass
          end
        end
        OpBaseAppRecord.transaction do
          authorization.lock!
          resolution.lock!
          flow.lock!
          if terminal == :cancellation
            flow.halt_sign_in!
            resolution.cancel!(
              actor: actor, challenge: issued.challenge, browser_binding_digest: binding_digest,
            )
          else
            flow.update!(expires_at: ClientSignInFlow.database_now)
            resolution.expire!
          end
        end
      end

      assert_equal :refused, Timeout.timeout(10) { future.value! }
      assert_equal 2, source_pids.uniq.size
      assert_predicate mutated, :empty?
      assert_equal ClientTokenStatus::ACTIVE, token.reload.user_token_status_id
      if terminal == :cancellation
        assert_predicate resolution.reload, :cancelled?
        assert_predicate flow.reload, :sign_in_halted?
      else
        assert_predicate resolution.reload, :expired?
        assert flow.reload.expired?(ClientSignInFlow.database_now)
      end

      assert_nil flow.token_id
      assert_nil flow.session_issued_at
    ensure
      future&.wait(10)
    end
  end

  test "selection holds cancellation out until its selected-session mutation finishes" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    now = ClientSignInFlow.database_now
    flow = ClientSignInFlow.create!(
      principal_id: actor.id, authentication_method: "secret", authentication_event_at: now,
      authentication_context: "normal", state_id: ClientSignInFlowState::SESSION_ISSUANCE_PENDING,
      nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.base58(32)), expires_at: now + 1.minute,
    )
    authorization = ClientOidcAuthorizationTransaction.create_transaction!(
      surface: "app", intent: "sign_in", client_id: "core-app-jp", redirect_uri: "https://example.com/callback",
      response_type: "code", scope: "openid", state: "state", nonce: "nonce",
      code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      code_challenge_method: "S256", login_challenge: SecureRandom.base58(32),
      login_challenge_expires_at: now + 1.minute, expires_at: now + 1.minute,
    )
    authorization.update!(secret_sign_in_flow: flow)
    authorization.register_authentication!(
      actor_ref: actor.public_id, session_ref: nil, auth_method: "passcode", acr: "aal1",
      authentication_event_at: now,
    )
    raw_binding = SecureRandom.urlsafe_base64(32)
    binding_digest = ClientSessionLimitResolutionTransaction.digest_challenge(raw_binding)
    issued = ClientSessionLimitResolutionTransaction.issue!(
      actor: actor, sign_in_flow: flow, browser_binding_digest: binding_digest,
      oidc_authorization_transaction: authorization,
    )
    resolution = issued.transaction
    ready = Queue.new
    future = nil
    source_pids = []
    actor.with_lock do
      OpBaseAppRecord.transaction do
        authorization.lock!
        resolution.lock!
        flow.lock!
        source_pids << Client.lease_connection.select_value("SELECT pg_backend_pid()")
        future =
          Concurrent::Future.execute(executor: Concurrent::SimpleExecutorService.new) do
            AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
              connection.execute("SET lock_timeout = '10000'")
              ready << connection.select_value("SELECT pg_backend_pid()")
              begin
                Client.find(actor.id).with_lock do
                  OpBaseAppRecord.transaction do
                    current_authorization = ClientOidcAuthorizationTransaction.find(authorization.id)
                    current_authorization.lock!
                    current_resolution = ClientSessionLimitResolutionTransaction.find(resolution.id)
                    current_resolution.lock!
                    current_flow = ClientSignInFlow.find(flow.id)
                    current_flow.lock!
                    current_flow.halt_sign_in!
                    current_resolution.cancel!(
                      actor: Client.find(actor.id), challenge: issued.challenge,
                      browser_binding_digest: binding_digest,
                    )
                  end
                end
                :canceled
              ensure
                connection.execute("RESET lock_timeout")
              end
            end
          ensure
            # Release model-clock leases before the dedicated worker exits.
            ActiveRecord::Base.connection_handler.clear_active_connections!
          end
        worker_pid = Timeout.timeout(10) { ready.pop }
        source_pids << worker_pid
        Timeout.timeout(10) do
          loop do
            if future.complete?
              raise RuntimeError, "cancellation escaped selection locks: #{future.value!.inspect}"
            end

            blocked =
              Client.uncached do
                Client.lease_connection.select_value(
                  "SELECT cardinality(pg_blocking_pids(#{Integer(worker_pid)})) > 0",
                )
              end
            break if blocked

            Thread.pass
          end
        end

        assert_predicate resolution.reload, :pending?
        resolution.select_session!(
          actor: actor, challenge: issued.challenge, session_ref: token.public_id,
          browser_binding_digest: binding_digest,
        )
        token.revoke!
      end
    end

    assert_equal :canceled, Timeout.timeout(10) { future.value! }
    assert_equal 2, source_pids.uniq.size
    assert_equal ClientTokenStatus::REVOKED, token.reload.user_token_status_id
    assert_predicate resolution.reload, :cancelled?
    assert_predicate flow.reload, :sign_in_halted?
    assert_nil flow.token_id
    assert_nil flow.session_issued_at
    assert_equal 1, ClientToken.where(user_id: actor.id).count
  ensure
    future&.wait(10)
  end
end
