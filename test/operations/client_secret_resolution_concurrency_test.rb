# frozen_string_literal: true

require "test_helper"
require "timeout"

class ClientSecretResolutionConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = %w(
    client_statuses client_visibilities client_mfa_levels client_mfa_statuses
    client_token_statuses client_token_kinds client_token_binding_methods client_token_dbsc_statuses
  )

  %i(cancellation expiration).each do |terminal|
    test "a separately connected selection blocked behind #{terminal} cannot revoke a session" do
      actor = Client.create!(status_id: ClientStatus::ACTIVE)
      token = ClientToken.create!(user: actor)
      now = ClientSignInFlow.database_now
      flow = ClientSignInFlow.create!(
        principal_id: actor.id, authentication_method: "secret", authentication_event_at: now,
        authentication_context: "normal", state_id: ClientSignInFlowState::SESSION_ISSUANCE_PENDING,
        nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.base58(32)), expires_at: now + 1.minute,
      )
      authorization = ClientOidcAuthorizationTransaction.create_transaction!(
        surface: "app", intent: "sign_in", client_id: "core-app", redirect_uri: "https://example.com/callback",
        response_type: "code", scope: "openid", state: "state", nonce: "nonce", code_challenge: "challenge",
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
          Concurrent::Future.execute do
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
        AppTicketRecord.transaction do
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
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor)
    now = ClientSignInFlow.database_now
    flow = ClientSignInFlow.create!(
      principal_id: actor.id, authentication_method: "secret", authentication_event_at: now,
      authentication_context: "normal", state_id: ClientSignInFlowState::SESSION_ISSUANCE_PENDING,
      nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.base58(32)), expires_at: now + 1.minute,
    )
    authorization = ClientOidcAuthorizationTransaction.create_transaction!(
      surface: "app", intent: "sign_in", client_id: "core-app", redirect_uri: "https://example.com/callback",
      response_type: "code", scope: "openid", state: "state", nonce: "nonce", code_challenge: "challenge",
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
      AppTicketRecord.transaction do
        authorization.lock!
        resolution.lock!
        flow.lock!
        source_pids << Client.lease_connection.select_value("SELECT pg_backend_pid()")
        future =
          Concurrent::Future.execute do
            AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
              connection.execute("SET lock_timeout = '10000'")
              ready << connection.select_value("SELECT pg_backend_pid()")
              begin
                Client.find(actor.id).with_lock do
                  AppTicketRecord.transaction do
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
