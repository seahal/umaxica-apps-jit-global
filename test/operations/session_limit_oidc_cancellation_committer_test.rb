# frozen_string_literal: true

require "test_helper"
require "timeout"

class SessionLimitOidcCancellationCommitterTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  uses_transaction :test_session_limit_cancel_waits_for_actor_before_locking_the_oidc_parent,
                   :test_org_session_limit_cancel_waits_for_operator_before_locking_the_oidc_parent

  class CancellationStore
    def issue!(raw_code:, **)
      raw_code
    end
  end

  test "session-limit cancel waits for actor before locking the OIDC parent" do
    ClientSessionLimitResolutionState::DEFAULTS.each do |id|
      ClientSessionLimitResolutionState.find_or_create_by!(id: id) do |state|
        state.created_at = Time.current
        state.updated_at = Time.current
      end
    end

    @actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    now = ClientSignInFlow.database_now
    @flow = ClientSignInFlow.create!(
      principal_id: @actor.id,
      state_id: ClientSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
      nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
      issued_at: now,
      expires_at: now + 5.minutes,
    )
    client_id = "core-app-jp"
    oidc_issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in",
      params: {
        response_type: "code",
        client_id: client_id,
        redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris.first,
        scope: "openid profile",
        state: SecureRandom.hex(16),
        nonce: SecureRandom.hex(16),
        code_challenge: SecureRandom.urlsafe_base64(32),
        code_challenge_method: "S256",
      },
    )
    @transaction = OidcAuthorizationTransactionCoordinator.register_result!(
      surface: "app", login_challenge: oidc_issuance.transaction.login_challenge,
      actor: @actor, session_ref: nil, auth_method: "passkey", authentication_event_at: now,
    ).transaction
    browser_binding = SecureRandom.urlsafe_base64(32)
    resolution_issuance = ClientSessionLimitResolutionTransaction.issue!(
      sign_in_flow: @flow, actor: @actor,
      browser_binding_digest: ClientSessionLimitResolutionTransaction.digest_challenge(browser_binding),
      oidc_authorization_transaction: @transaction,
    )
    @resolution = resolution_issuance.transaction
    backend_pid = Queue.new
    worker = nil
    actor_wait_observed = false

    Client.transaction do
      @actor.lock!
      worker =
        Thread.new do
          AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
            backend_pid << Integer(connection.select_value("SELECT pg_backend_pid()"))
            OpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
              SessionLimitOidcCancellationCommitter.call!(
                actor: Client.find(@actor.id),
                resolution: ClientSessionLimitResolutionTransaction.find(@resolution.id),
                transaction: ClientOidcAuthorizationTransaction.find(@transaction.id),
                challenge: resolution_issuance.challenge, browser_binding: browser_binding,
                store: CancellationStore.new,
              )
            end
          end
        rescue StandardError => e
          e
        ensure
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end
      worker_backend_pid = Timeout.timeout(5) { backend_pid.pop }
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
      loop do
        wait_event =
          AppZenithRecord.uncached do
            AppZenithRecord.connection.select_value("SELECT pg_stat_clear_snapshot()::text")
            AppZenithRecord.connection.select_value(
              "SELECT wait_event_type FROM pg_stat_activity WHERE pid = #{Integer(worker_backend_pid)}",
            )
          end
        actor_wait_observed = wait_event == "Lock"
        break if actor_wait_observed || !worker.alive? || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep 0.01
      end

      assert actor_wait_observed, "The cancellation must wait for the actor before entering its OP transaction"
      OpBaseAppRecord.transaction(requires_new: true) do
        assert_predicate ClientOidcAuthorizationTransaction.lock("FOR UPDATE NOWAIT").find(@transaction.id), :persisted?
      end
    end

    issuance = Timeout.timeout(10) { worker.value }

    assert_instance_of BaseAuthAdmissionCoordinator::CancellationIssuance, issuance
    assert_predicate @transaction.reload, :canceled?
    assert_predicate @resolution.reload, :cancelled?
    assert_predicate @flow.reload, :sign_in_cancelled?
  ensure
    worker&.join(5)
  end

  test "ORG session-limit cancel preserves the operator and authorization bindings" do
    OperatorSessionLimitResolutionState::DEFAULTS.each do |id|
      OperatorSessionLimitResolutionState.find_or_create_by!(id: id) do |state|
        state.created_at = Time.current
        state.updated_at = Time.current
      end
    end

    @actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    now = OperatorSignInFlow.database_now
    @flow = OperatorSignInFlow.create!(
      principal_id: @actor.id,
      state_id: OperatorSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
      nonce_digest: OperatorSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
      issued_at: now,
      expires_at: now + 5.minutes,
    )
    client_id = "core-org-jp"
    oidc_issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org", intent: "sign_in",
      params: {
        response_type: "code",
        client_id: client_id,
        redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris.first,
        scope: "openid profile",
        state: SecureRandom.hex(16),
        nonce: SecureRandom.hex(16),
        code_challenge: SecureRandom.urlsafe_base64(32),
        code_challenge_method: "S256",
      },
    )
    @transaction = OidcAuthorizationTransactionCoordinator.register_result!(
      surface: "org", login_challenge: oidc_issuance.transaction.login_challenge,
      actor: @actor, session_ref: nil, auth_method: "passkey", authentication_event_at: now,
    ).transaction
    browser_binding = SecureRandom.urlsafe_base64(32)
    resolution_issuance = OperatorSessionLimitResolutionTransaction.issue!(
      sign_in_flow: @flow, actor: @actor,
      browser_binding_digest: OperatorSessionLimitResolutionTransaction.digest_challenge(browser_binding),
      oidc_authorization_transaction: @transaction,
    )
    @resolution = resolution_issuance.transaction

    issuance = SessionLimitOidcCancellationCommitter.call!(
      actor: @actor, resolution: @resolution, transaction: @transaction,
      challenge: resolution_issuance.challenge, browser_binding:, store: CancellationStore.new,
    )

    assert_instance_of BaseAuthAdmissionCoordinator::CancellationIssuance, issuance
    assert_equal "org", @transaction.reload.surface
    assert_predicate @transaction, :canceled?
    assert_predicate @resolution.reload, :cancelled?
    assert_predicate @flow.reload, :sign_in_cancelled?
  end

  test "ORG session-limit cancel waits for operator before locking the OIDC parent" do
    OperatorSessionLimitResolutionState::DEFAULTS.each do |id|
      OperatorSessionLimitResolutionState.find_or_create_by!(id: id) do |state|
        state.created_at = Time.current
        state.updated_at = Time.current
      end
    end

    @actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    now = OperatorSignInFlow.database_now
    @flow = OperatorSignInFlow.create!(
      principal_id: @actor.id,
      state_id: OperatorSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
      nonce_digest: OperatorSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
      issued_at: now,
      expires_at: now + 5.minutes,
    )
    client_id = "core-org-jp"
    oidc_issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org", intent: "sign_in",
      params: {
        response_type: "code",
        client_id: client_id,
        redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris.first,
        scope: "openid profile",
        state: SecureRandom.hex(16),
        nonce: SecureRandom.hex(16),
        code_challenge: SecureRandom.urlsafe_base64(32),
        code_challenge_method: "S256",
      },
    )
    @transaction = OidcAuthorizationTransactionCoordinator.register_result!(
      surface: "org", login_challenge: oidc_issuance.transaction.login_challenge,
      actor: @actor, session_ref: nil, auth_method: "passkey", authentication_event_at: now,
    ).transaction
    browser_binding = SecureRandom.urlsafe_base64(32)
    resolution_issuance = OperatorSessionLimitResolutionTransaction.issue!(
      sign_in_flow: @flow, actor: @actor,
      browser_binding_digest: OperatorSessionLimitResolutionTransaction.digest_challenge(browser_binding),
      oidc_authorization_transaction: @transaction,
    )
    @resolution = resolution_issuance.transaction
    backend_pid = Queue.new
    worker = nil
    operator_wait_observed = false

    Operator.transaction do
      @actor.lock!
      worker =
        Thread.new do
          OrgZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
            backend_pid << Integer(connection.select_value("SELECT pg_backend_pid()"))
            OpBaseOrgRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
              SessionLimitOidcCancellationCommitter.call!(
                actor: Operator.find(@actor.id),
                resolution: OperatorSessionLimitResolutionTransaction.find(@resolution.id),
                transaction: OperatorOidcAuthorizationTransaction.find(@transaction.id),
                challenge: resolution_issuance.challenge, browser_binding: browser_binding,
                store: CancellationStore.new,
              )
            end
          end
        rescue StandardError => e
          e
        ensure
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end
      worker_backend_pid = Timeout.timeout(5) { backend_pid.pop }
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
      loop do
        wait_event =
          OrgZenithRecord.uncached do
            OrgZenithRecord.connection.select_value("SELECT pg_stat_clear_snapshot()::text")
            OrgZenithRecord.connection.select_value(
              "SELECT wait_event_type FROM pg_stat_activity WHERE pid = #{Integer(worker_backend_pid)}",
            )
          end
        operator_wait_observed = wait_event == "Lock"
        break if operator_wait_observed || !worker.alive? || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep 0.01
      end

      assert operator_wait_observed, "The cancellation must wait for the operator before entering its OP transaction"
      OpBaseOrgRecord.transaction(requires_new: true) do
        assert_predicate OperatorOidcAuthorizationTransaction.lock("FOR UPDATE NOWAIT").find(@transaction.id),
                         :persisted?
      end
    end

    issuance = Timeout.timeout(10) { worker.value }

    assert_instance_of BaseAuthAdmissionCoordinator::CancellationIssuance, issuance
    assert_predicate @transaction.reload, :canceled?
    assert_predicate @resolution.reload, :cancelled?
    assert_predicate @flow.reload, :sign_in_cancelled?
  ensure
    worker&.join(5)
  end

  teardown do
    case @actor
    when Client
      if @resolution
        ChronicleRecord.connected_to(role: :writing) do
          ClientChronicle.where(subject_type: "Client", subject_id: @actor.id.to_s)
            .where("context ->> 'resolution_transaction_id' = ?", @resolution.id.to_s).delete_all
        end
        OpBaseAppRecord.connected_to(role: :writing) do
          ClientSessionLimitResolutionTransaction.where(id: @resolution.id).delete_all
        end
      end
      if @transaction
        OpBaseAppRecord.connected_to(role: :writing) do
          ClientOidcAuthorizationTransaction.where(id: @transaction.id).delete_all
        end
      end
      if @flow
        OpBaseAppRecord.connected_to(role: :writing) do
          ClientSignInFlow.where(id: @flow.id).delete_all
        end
      end
      Client.where(id: @actor.id).delete_all
    when Operator
      if @resolution
        ChronicleRecord.connected_to(role: :writing) do
          OperatorChronicle.where(subject_type: "Operator", subject_id: @actor.id.to_s)
            .where("context ->> 'resolution_transaction_id' = ?", @resolution.id.to_s).delete_all
        end
        OpBaseOrgRecord.connected_to(role: :writing) do
          OperatorSessionLimitResolutionTransaction.where(id: @resolution.id).delete_all
        end
      end
      if @transaction
        OpBaseOrgRecord.connected_to(role: :writing) do
          OperatorOidcAuthorizationTransaction.where(id: @transaction.id).delete_all
        end
      end
      if @flow
        OpBaseOrgRecord.connected_to(role: :writing) do
          OperatorSignInFlow.where(id: @flow.id).delete_all
        end
      end
      Operator.where(id: @actor.id).delete_all
    end
  end
end
