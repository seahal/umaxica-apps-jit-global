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

  test "source audit failures after OP verification preserve Secret rename and revocation state" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "fallback", uv_verified_at: Time.current)
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
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      step_up_evidence: evidence,
    )
    candidate = ClientSecretCredential.create!(
      client: actor, issuance: issuance, name: "Original", password: SecureRandom.base58(32),
    )
    at = Client.database_now
    ClientSecretAuditOutbox.transaction do
      issuance.update!(presented_at: at)
      ClientSecretAuditOutbox.record!(
        actor_context: context, client_ref: actor.public_id, credential_ref: candidate.public_id,
        operation_ref: issuance.origin_operation_id, occurred_at: at, event_name: "secret.presented", item_count: 1,
      )
    end
    ClientSecretStorageConfirmationCommitter.call!(
      actor_context: context, token: token, issuance: issuance,
      step_up_evidence: evidence,
    )
    commits = []
    observer =
      lambda do |_name, _start, _finish, _id, event|
        commits << event.fetch(:connection).pool.db_config.name if event.fetch(:sql).start_with?("COMMIT")
      end
    failure = ->(**) { raise ActiveRecord::ConnectionNotEstablished, "injected source audit failure" }
    %i(rename revoke).each do |operation|
      commits.clear
      ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
        ClientSecretAuditOutbox.stub(:record!, failure) do
          case operation
          when :rename
            assert_raises(ClientSecretNameCommitter::DependencyFailure) do
              ClientSecretNameCommitter.call!(
                actor_context: context, token: token, credential: candidate, name: "Failed",
                step_up_evidence: evidence,
              )
            end
          when :revoke
            assert_raises(ClientSecretRevocationCommitter::DependencyFailure) do
              ClientSecretRevocationCommitter.call!(
                actor_context: context, token: token, credential: candidate, purge_after: 1.day,
                step_up_evidence: evidence,
              )
            end
          end
        end
      end

      assert_includes commits, "op_base_app"
      assert OpAppGrant.exists?(public_id: evidence.sid)
      assert_equal "Original", candidate.reload.name
      assert_nil candidate.revoked_at
      assert_equal 0, ClientSecretAuditOutbox.where(
        credential_ref: candidate.public_id, event_name: %w(secret.renamed secret.revoked secret.discarded),
      ).count
    end
  ensure
    if actor
      ClientSecretAuditOutbox.where(client_ref: actor.public_id).find_each(&:destroy!)
      ClientSecretCredential.where(client_id: actor.id).find_each(&:destroy!)
      ClientSecretIssuance.where(client_id: actor.id).find_each(&:destroy!)
      OpBaseAppRecord.connected_to(role: :writing) do
        OpAppGrant.where(client_token_id: token&.id).delete_all
        token&.association(:op_app_grants)&.reset
        token&.destroy!
        actor.reload.update!(discard_at: actor.created_at, purge_eligible_at: actor.created_at)
        actor.strict_loading!(false)
        actor.destroy!
      end
    end
  end

  test "a source write failure after OP verification does not confirm storage" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
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
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      step_up_evidence: evidence,
    )
    candidate = ClientSecretCredential.create!(
      client: actor, issuance: issuance, name: "Confirmation failure", password: SecureRandom.base58(32),
    )
    at = Client.database_now
    ClientSecretAuditOutbox.transaction do
      issuance.update!(presented_at: at)
      ClientSecretAuditOutbox.record!(
        actor_context: context, client_ref: actor.public_id, credential_ref: candidate.public_id,
        operation_ref: issuance.origin_operation_id, occurred_at: at, event_name: "secret.presented", item_count: 1,
      )
    end
    commits = []
    observer =
      lambda do |_name, _start, _finish, _id, event|
        sql = event.fetch(:sql)
        if sql.start_with?("COMMIT")
          commits << event.fetch(:connection).pool.db_config.name
        elsif sql.match?(/\A\s*UPDATE\s+"client_secret_issuances"/i)
          raise ActiveRecord::ConnectionNotEstablished, "injected source failure"
        end
      end

    ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
      assert_raises(ClientSecretStorageConfirmationCommitter::DependencyFailure) do
        ClientSecretStorageConfirmationCommitter.call!(
          actor_context: context, token: token, issuance: issuance,
          step_up_evidence: evidence,
        )
      end
    end

    assert_includes commits, "op_base_app"
    assert OpAppGrant.exists?(public_id: evidence.sid)
    assert_nil issuance.reload.confirmed_at
    assert_nil candidate.reload.confirmed_at
    assert_equal 0, ClientSecretAuditOutbox.where(
      operation_ref: issuance.origin_operation_id, event_name: "secret.storage_declared",
    ).count
  ensure
    if actor
      ClientSecretAuditOutbox.where(client_ref: actor.public_id).find_each(&:destroy!)
      ClientSecretCredential.where(client_id: actor.id).find_each(&:destroy!)
      ClientSecretIssuance.where(client_id: actor.id).find_each(&:destroy!)
      OpBaseAppRecord.connected_to(role: :writing) do
        OpAppGrant.where(client_token_id: token&.id).delete_all
        token&.association(:op_app_grants)&.reset
        token&.destroy!
        actor.reload.update!(discard_at: actor.created_at, purge_eligible_at: actor.created_at)
        actor.strict_loading!(false)
        actor.destroy!
      end
    end
  end

  test "a Zenith commit failure after OP verification confirms none of the batch" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
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
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      step_up_evidence: evidence,
    )
    candidate = ClientSecretCredential.create!(
      client: actor, issuance: issuance, name: "Original", password: SecureRandom.base58(32),
    )
    at = Client.database_now
    ClientSecretAuditOutbox.transaction do
      issuance.update!(presented_at: at)
      ClientSecretAuditOutbox.record!(
        actor_context: context, client_ref: actor.public_id, credential_ref: candidate.public_id,
        operation_ref: issuance.origin_operation_id, occurred_at: at, event_name: "secret.presented", item_count: 1,
      )
    end
    failed_commit = -> { raise ActiveRecord::ConnectionNotEstablished, "injected batch Zenith commit failure" }

    assert_raises(ClientSecretStorageConfirmationCommitter::DependencyFailure) do
      AppZenithRecord.lease_connection.stub(:commit_db_transaction, failed_commit) do
        ClientSecretStorageConfirmationCommitter.call!(
          actor_context: context, token: token, issuance: issuance,
          step_up_evidence: evidence,
        )
      end
    end

    assert_nil issuance.reload.confirmed_at
    assert_nil candidate.reload.confirmed_at
    assert_equal 0, ClientSecretAuditOutbox.where(
      operation_ref: issuance.origin_operation_id,
      event_name: %w(secret.storage_declared secret.created),
    ).count
    assert OpAppGrant.exists?(public_id: evidence.sid)
  ensure
    if actor
      ClientSecretAuditOutbox.where(client_ref: actor.public_id).find_each(&:destroy!)
      ClientSecretCredential.where(client_id: actor.id).find_each(&:destroy!)
      ClientSecretIssuance.where(client_id: actor.id).find_each(&:destroy!)
      OpBaseAppRecord.connected_to(role: :writing) do
        OpAppGrant.where(client_token_id: token&.id).delete_all
        token&.association(:op_app_grants)&.reset
        token&.destroy!
        actor.reload.update!(discard_at: actor.created_at, purge_eligible_at: actor.created_at)
        actor.strict_loading!(false)
        actor.destroy!
      end
    end
  end

  test "a lost Zenith commit acknowledgement retries the committed confirmation without duplicate audit" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
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
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      step_up_evidence: evidence,
    )
    candidate = ClientSecretCredential.create!(
      client: actor, issuance: issuance, name: "Lost acknowledgement", password: SecureRandom.base58(32),
    )
    presented_at = Client.database_now
    ClientSecretAuditOutbox.transaction do
      issuance.update!(presented_at: presented_at)
      ClientSecretAuditOutbox.record!(
        actor_context: context, client_ref: actor.public_id, credential_ref: candidate.public_id,
        operation_ref: issuance.origin_operation_id, occurred_at: presented_at,
        event_name: "secret.presented", item_count: 1,
      )
    end
    connection = AppZenithRecord.lease_connection
    commit = connection.method(:commit_db_transaction)
    lose_acknowledgement =
      lambda do
        commit.call
        connection.disconnect!
        raise ActiveRecord::ConnectionNotEstablished, "injected lost Secret confirmation commit acknowledgement"
      end

    assert_raises(ClientSecretStorageConfirmationCommitter::DependencyFailure) do
      connection.stub(:commit_db_transaction, lose_acknowledgement) do
        connection.stub(:rollback_db_transaction, -> { }) do
          ClientSecretStorageConfirmationCommitter.call!(
            actor_context: context, token: token, issuance: issuance,
            step_up_evidence: evidence,
          )
        end
      end
    end

    confirmed_issuance = ClientSecretIssuance.find(issuance.id)
    confirmed_candidate = ClientSecretCredential.find(candidate.id)

    assert_predicate confirmed_issuance.confirmed_at, :present?
    assert_equal confirmed_issuance.confirmed_at, confirmed_candidate.confirmed_at
    assert OpAppGrant.exists?(public_id: evidence.sid)
    assert_equal 1, ClientSecretAuditOutbox.where(
      operation_ref: issuance.origin_operation_id, event_name: "secret.storage_declared",
    ).count
    assert_equal 1, ClientSecretAuditOutbox.where(
      operation_ref: issuance.origin_operation_id, event_name: "secret.created",
    ).count

    retry_result = ClientSecretStorageConfirmationCommitter.call!(
      actor_context: context, token: token, issuance: confirmed_issuance,
      step_up_evidence: evidence,
    )

    assert_equal confirmed_issuance.id, retry_result.id
    assert_equal confirmed_issuance.confirmed_at, retry_result.confirmed_at
    assert OpAppGrant.exists?(public_id: evidence.sid), "the same evidence remains valid for a retry"
    assert_equal 1, ClientSecretAuditOutbox.where(
      operation_ref: issuance.origin_operation_id, event_name: "secret.storage_declared",
    ).count
    assert_equal 1, ClientSecretAuditOutbox.where(
      operation_ref: issuance.origin_operation_id, event_name: "secret.created",
    ).count
  ensure
    if actor
      ClientSecretAuditOutbox.where(client_ref: actor.public_id).find_each(&:destroy!)
      ClientSecretCredential.where(client_id: actor.id).find_each(&:destroy!)
      ClientSecretIssuance.where(client_id: actor.id).find_each(&:destroy!)
      OpBaseAppRecord.connected_to(role: :writing) do
        OpAppGrant.where(client_token_id: token&.id).delete_all
        token&.association(:op_app_grants)&.reset
        token&.destroy!
        actor.reload.update!(discard_at: actor.created_at, purge_eligible_at: actor.created_at)
        actor.strict_loading!(false)
        actor.destroy!
      end
    end
  end

  test "confirmation racing cancellation commits one consistent terminal state and releases the reservation" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
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
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      step_up_evidence: evidence,
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
                        step_up_evidence: evidence,
                      )
                    when :cancel
                      ClientSecretManualIssuanceInvalidator.call!(
                        actor_context: bound, token: token, issuance: issuance, purge_after: 1.day,
                        step_up_evidence: evidence,
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
      OpBaseAppRecord.connected_to(role: :writing) do
        OpAppGrant.where(client_token_id: token&.id).delete_all
        token&.association(:op_app_grants)&.reset
        token&.destroy!
        actor.reload.update!(discard_at: actor.created_at, purge_eligible_at: actor.created_at)
        actor.strict_loading!(false)
        destroy_test_client_after_cross_database_cleanup!(actor)
      end
    end
  end

  test "confirmation racing claim never authenticates an unconfirmed candidate or reactivates a claim" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
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
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      step_up_evidence: evidence,
    )
    ClientSecretPresentationIssuer.prepare!(
      actor_context: context, token: token, issuance: issuance,
      step_up_evidence: evidence,
    )
    raw = ClientSecretPresentationIssuer.call!(
      actor_context: context, token: token, issuance: issuance,
      step_up_evidence: evidence,
    ).first
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
                  step_up_evidence: evidence,
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
    claimed_at = candidate.claimed_at
    retry_result = ClientSecretStorageConfirmationCommitter.call!(
      actor_context: context, token: token, issuance: issuance,
      step_up_evidence: evidence,
    )

    assert_equal claim_operation, candidate.reload.claim_operation_id
    assert_equal issuance.public_id, retry_result.public_id
    assert_equal claimed_at, candidate.claimed_at
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
      OpBaseAppRecord.connected_to(role: :writing) do
        OpAppGrant.where(client_token_id: token&.id).delete_all
        token&.association(:op_app_grants)&.reset
        token&.destroy!
        actor.reload.update!(discard_at: actor.created_at, purge_eligible_at: actor.created_at)
        actor.strict_loading!(false)
        destroy_test_client_after_cross_database_cleanup!(actor)
      end
    end
  end

  test "concurrent confirmations reuse Step-Up evidence while activating one credential" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
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
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      step_up_evidence: evidence,
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
                    step_up_evidence: evidence,
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

    assert_equal 2, successful_results.length
    assert_equal 0, results.count(:denied)
    assert_equal issuance.public_id, successful_results.first.first
    assert_equal [issuance.public_id], successful_results.map(&:first).uniq
    assert_equal 1, successful_results.map(&:last).uniq.length
    assert OpAppGrant.exists?(public_id: evidence.sid)
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
      OpBaseAppRecord.connected_to(role: :writing) do
        OpAppGrant.where(client_token_id: token&.id).delete_all
        token&.association(:op_app_grants)&.reset
        token&.destroy!
        actor.reload.update!(discard_at: actor.created_at, purge_eligible_at: actor.created_at)
        actor.strict_loading!(false)
        destroy_test_client_after_cross_database_cleanup!(actor)
      end
    end
  end
end
