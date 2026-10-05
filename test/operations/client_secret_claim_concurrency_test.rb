# frozen_string_literal: true

require "test_helper"
require "timeout"

class ClientSecretClaimConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = %w(
    client_statuses client_visibilities client_mfa_levels client_mfa_statuses
    client_token_statuses client_token_kinds client_token_binding_methods client_token_dbsc_statuses
  )

  setup do
    @actor = Client.create!(status_id: ClientStatus::ACTIVE)
    @token = ClientToken.create!(user: @actor)
    @token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: @token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    context = ActorValuesContext.empty.with(subject: @actor, actor_type: :client, tld: :app, surface: :base)
    @issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: @token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
    )
    ClientSecretPresentationIssuer.prepare!(actor_context: context, token: @token, issuance: @issuance)
    @raw = ClientSecretPresentationIssuer.call!(actor_context: context, token: @token, issuance: @issuance).first
    ClientSecretStorageConfirmationCommitter.call!(actor_context: context, token: @token, issuance: @issuance)
    @browsers =
      Array.new(2) do
        admission = BaseAuthAdmissionCoordinator.issue_local_entry!(surface: "app", intent: "sign_in")
        payload = BaseAuthAdmissionCoordinator.consume_entry_reference!(
          reference: admission.reference, surface: "app", expected_intent: "sign_in",
        )
        flow = ClientSignInFlow.find_by!(public_id: payload.fetch("subject_ref"))
        ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
          admission_purpose: "local_sign_in", local_sign_in_flow_ref: flow.public_id,
        )
        [flow, ceremony]
      end
  end

  test "separate admitted browser flows racing a saved Secret persist exactly one claim" do
    ready = Queue.new
    release = Queue.new
    ActiveRecord::Base.connection_handler.clear_active_connections!
    futures =
      @browsers.map do |flow, ceremony|
        Concurrent::Future.execute do
          AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |source|
            source.execute("SET lock_timeout = '5000'")
            AppTicketRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |ticket|
              AppTicketRecord.transaction do
                ticket.select_value("SELECT set_config('lock_timeout', '5000', true)")
                ready << source.select_value("SELECT pg_backend_pid()")
                release.pop
                ClientSecretClaimCommitter.call!(secret: @raw, flow: flow, ceremony: ceremony)&.public_id
              end
            end
          ensure
            source.execute("RESET lock_timeout")
          end
        end
      end
    pids, results =
      Timeout.timeout(20) do
      identifiers = [ready.pop, ready.pop]
      2.times { release << true }
      [identifiers, futures.map(&:value!)]
    end

    assert_equal 2, pids.uniq.length
    assert_equal 1, results.compact.length
    credential = ClientSecretCredential.find_by!(issuance_id: @issuance.id)

    assert_equal credential.public_id, results.compact.first
    assert_equal 1,
                 ClientSecretAuditOutbox.where(credential_ref: credential.public_id, event_name: "secret.claimed").count
    assert_nil ClientSecretLookupQuery.call(secret: @raw)
    winner = @browsers.find { |flow, _| flow.public_id == credential.claim_sign_in_flow_ref }

    assert_equal winner.last.id, credential.claim_ceremony_session_id
    assert_equal @actor.id, winner.first.reload.principal_id
    assert_equal 0, ClientSecretSignInReceipt.where(credential_ref: credential.public_id).count
    assert_equal 1, ClientToken.where(user_id: @actor.id).count
  ensure
    2.times { release << true } if release
    futures&.each { |future| future.wait(10) }
  end

  test "withdrawal revokes a claimed Secret without collecting its live continuation proof" do
    flow, ceremony = @browsers.first
    credential = ClientSecretClaimCommitter.call!(secret: @raw, flow: flow, ceremony: ceremony)
    operation_id = credential.claim_operation_id
    now = Client.database_now
    @actor.update!(withdrawn_at: now, terminated_at: now)
    credential.commit_withdrawal_revocation!(at: now, purge_at: now + 1.day)

    assert credential.reload.revoked_at
    assert_equal operation_id, credential.claim_operation_id
    assert_equal Float::INFINITY, credential.discard_at
    assert_equal Float::INFINITY, credential.purge_eligible_at
    assert_nil ClientSecretLookupQuery.call(secret: @raw)
    assert_equal :pending, ClientSecretClaimFinalizer.call!(credential: credential, purge_after: 1.day)
    assert ClientSignInFlow.exists?(flow.id)
    flow.fail_sign_in!(now: ClientSignInFlow.database_now)

    assert_equal :abandoned, ClientSecretClaimFinalizer.call!(credential: credential, purge_after: 1.day)
    assert_operator credential.reload.discard_at, :<=, Client.database_now
    assert_nil credential.consumed_at
  end

  test "source claim survives Ticket rollback and terminal reconciliation retires the unbound flow" do
    flow, ceremony = @browsers.first
    AppTicketRecord.transaction do
      assert ClientSecretClaimCommitter.call!(secret: @raw, flow: flow, ceremony: ceremony)
      raise ActiveRecord::Rollback
    end
    credential = ClientSecretCredential.find_by!(issuance_id: @issuance.id)

    assert credential.claimed_at
    assert_nil flow.reload.principal_id
    assert_nil ClientSecretLookupQuery.call(secret: @raw)
    assert_equal :pending, ClientSecretClaimFinalizer.call!(credential: credential, purge_after: 1.minute)
    flow.with_lock { flow.fail_sign_in!(now: ClientSignInFlow.database_now) }

    assert_equal :abandoned, ClientSecretClaimFinalizer.call!(credential: credential, purge_after: 1.minute)
    assert_operator credential.reload.discard_at, :<=, Client.database_now
    assert_nil credential.consumed_at
    assert_equal @actor.id, flow.reload.principal_id
    assert_equal "flow_failed", ClientSecretAuditOutbox.find_by!(
      credential_ref: credential.public_id, event_name: "secret.discarded",
    ).reason
    assert_equal 0, ClientSecretSignInReceipt.where(credential_ref: credential.public_id).count
    assert_equal 1, ClientToken.where(user_id: @actor.id).count
    assert_nil ClientSecretClaimCommitter.call!(secret: @raw, flow: @browsers.last.first, ceremony: @browsers.last.last)
  end

  test "expiry refuses a live flow and reconciliation retains its reason after Ticket terminalization" do
    flow, ceremony = @browsers.first
    credential = ClientSecretClaimCommitter.call!(secret: @raw, flow: flow, ceremony: ceremony)
    assert_raises(FlowInvalidTransition) { flow.expire_sign_in! }
    assert_predicate flow.reload, :sign_in_primary_pending?
    now = ClientSignInFlow.database_now
    flow.update!(issued_at: now - 16.minutes, expires_at: now)
    flow.expire_sign_in!

    assert_predicate flow.reload, :sign_in_failed?
    assert_equal :abandoned, ClientSecretClaimFinalizer.call!(credential: credential, purge_after: 1.minute)
    assert_nil credential.reload.consumed_at
    assert_equal "flow_expired", ClientSecretAuditOutbox.find_by!(
      credential_ref: credential.public_id, event_name: "secret.discarded",
    ).reason
    assert_nil ClientSecretLookupQuery.call(secret: @raw)
    assert_equal 1, ClientToken.where(user_id: @actor.id).count
  end

  test "missing durable Ticket proof leaves the source claim unknown and permanently unusable" do
    flow, ceremony = @browsers.first
    credential = ClientSecretClaimCommitter.call!(secret: @raw, flow: flow, ceremony: ceremony)
    # Simulate loss of the independent Ticket evidence, without mocking a login
    # result. Source claim persistence must not infer success or safe retirement.
    ceremony.destroy!
    flow.destroy!

    assert_equal :unknown, ClientSecretClaimFinalizer.call!(credential: credential, purge_after: 1.minute)
    assert credential.reload.claimed_at
    assert_nil credential.consumed_at
    assert_equal Float::INFINITY, credential.discard_at
    assert_equal Float::INFINITY, credential.purge_eligible_at
    assert_nil ClientSecretLookupQuery.call(secret: @raw)
    assert_nil ClientSecretClaimCommitter.call!(secret: @raw, flow: @browsers.last.first, ceremony: @browsers.last.last)
    assert_equal 0, ClientSecretSignInReceipt.where(credential_ref: credential.public_id).count
    assert_equal 1, ClientToken.where(user_id: @actor.id).count
    assert_equal 0, ClientSecretAuditOutbox.where(
      credential_ref: credential.public_id, event_name: %w(secret.consumed secret.discarded),
    ).count
  end

  test "real retention job preserves a claimed flow while its authentication outcome remains pending" do
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "86400"
    ENV["APP_SECRET_OUTBOX_RETENTION_SECONDS"] = "604800"
    unless ChronicleRetentionPolicy.exists?(code: "security")
      @retention_policy = ChronicleRetentionPolicy.create!(
        code: "security", name: "Security", duration_days: 365, permanent: false,
      )
    end
    flow, ceremony = @browsers.first
    credential = ClientSecretClaimCommitter.call!(secret: @raw, flow: flow, ceremony: ceremony)
    now = ClientSignInFlow.database_now
    flow.update!(discard_at: now, purge_eligible_at: now)
    unrelated = @browsers.last.first
    @browsers.last.last.destroy!
    unrelated.update!(discard_at: now, purge_eligible_at: now)

    RetentionPurgeJob.perform_now(batch_size: 1)

    assert ClientSignInFlow.exists?(flow.id)
    assert_not ClientSignInFlow.exists?(unrelated.id)
    assert_equal :pending, ClientSecretClaimFinalizer.call!(credential: credential, purge_after: 1.minute)
    assert_nil credential.reload.consumed_at
    assert_equal Float::INFINITY, credential.discard_at
    assert_nil ClientSecretLookupQuery.call(secret: @raw)
    assert_equal 0, ClientSecretSignInReceipt.where(credential_ref: credential.public_id).count
  end

  teardown do
    @browsers&.each { |flow, ceremony| ceremony.destroy!; flow.destroy! }
    if @actor
      Chronicle.where(subject_type: "Client", subject_id: @actor.id).find_each(&:destroy!)
      ClientSecretAuditOutbox.where(client_ref: @actor.public_id).find_each(&:destroy!)
      ClientSecretCredential.where(client_id: @actor.id).find_each(&:destroy!)
      ClientSecretIssuance.where(client_id: @actor.id).find_each(&:destroy!)
      @token&.destroy!
      @actor.reload.destroy!
    end
    @retention_policy&.destroy!
  end
end
