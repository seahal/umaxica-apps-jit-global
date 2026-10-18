# frozen_string_literal: true

require "test_helper"

class ClientSecretAuditDeliveryJobTest < ActiveSupport::TestCase
  setup do
    @security_policy = ChronicleRetentionPolicy.find_by(code: "security") ||
      ChronicleRetentionPolicy.create!(code: "security", name: "Security", duration_days: 365, permanent: false)
  end

  test "payload failure reaches Chronicle before real jobs delete the candidate and allocation" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor)
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
    candidate = ClientSecretCredential.find_by!(issuance_id: issuance.id)
    reference = candidate.public_id
    ClientSecretManualIssuanceInvalidator.call_for_payload_failure!(
      actor_context: context, token: token, issuance: issuance, purge_after: 0.000001.seconds,
    )
    previous = ENV.to_h.slice(
      "APP_SECRET_PURGE_DELAY_SECONDS", "APP_SECRET_OUTBOX_RETENTION_SECONDS", "APP_SECRET_PROOF_RETENTION_SECONDS",
    )
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "86400"
    ENV["APP_SECRET_OUTBOX_RETENTION_SECONDS"] = "604800"
    ENV["APP_SECRET_PROOF_RETENTION_SECONDS"] = "2592000"

    assert_equal :undelivered,
                 ClientSecretCredentialPurger.call!(credential: candidate, executor_job_id: "payload-before-audit")
    allocation_event = ClientSecretAuditOutbox.find_by!(
      operation_ref: issuance.origin_operation_id, event_name: "secret.issuance_canceled",
    )
    candidate_event = ClientSecretAuditOutbox.find_by!(credential_ref: reference, event_name: "secret.discarded")
    # One-row delivery preserves actual event order without directly marking acknowledgment.
    1000.times do
      break if allocation_event.reload.delivered_at

      ClientSecretAuditDeliveryJob.perform_now(batch_size: 1, retention_seconds: 604_800)
    end

    assert_not_nil allocation_event.reload.delivered_at
    assert_nil candidate_event.reload.delivered_at
    assert_equal :undelivered,
                 ClientSecretCredentialPurger.call!(credential: candidate, executor_job_id: "payload-partial-audit")
    assert ClientSecretCredential.exists?(candidate.id)
    ClientSecretLifecycleJob.perform_now(batch_size: 500)

    assert_not ClientSecretCredential.exists?(candidate.id)
    assert_not ClientSecretIssuance.exists?(issuance.id)
    terminal = ClientSecretAuditOutbox.find_by!(
      operation_ref: issuance.origin_operation_id, event_name: "secret.issuance_canceled",
    )

    assert_equal "payload_unavailable", terminal.reason
    assert Chronicle.exists?(event_uuid: terminal.event_id)
    purged = ClientSecretAuditOutbox.find_by!(credential_ref: reference, event_name: "secret.purged")
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 604_800)

    assert Chronicle.exists?(event_uuid: purged.event_id)
    assert_no_difference "Chronicle.count" do
      ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 604_800)
    end
  ensure
    if previous
      %w(
        APP_SECRET_PURGE_DELAY_SECONDS APP_SECRET_OUTBOX_RETENTION_SECONDS APP_SECRET_PROOF_RETENTION_SECONDS
      ).each do |key|
        previous.key?(key) ? ENV[key] = previous.fetch(key) : ENV.delete(key)
      end
    end
  end

  test "withdrawal candidate audit reaches Chronicle before real lifecycle deletion" do
    now = Client.database_now
    actor = Client.create!(status_id: ClientStatus::ACTIVE, withdrawn_at: now, terminated_at: now)
    issuance = ClientSecretIssuance.create!(
      client: actor, origin: "manual", origin_operation_id: SecureRandom.uuid, attempt_number: 1,
      browser_session_ref: "withdrawal-audit-session", planned_count: 1, expires_at: now + 1.minute,
      encrypted_payload: "opaque-test-payload",
    )
    raw = SecureRandom.base58(32)
    credential = ClientSecretCredential.create!(
      client: actor, issuance: issuance, name: "Pending", password: raw,
    )
    previous_delay = ENV["APP_SECRET_PURGE_DELAY_SECONDS"]
    previous_retention = ENV["APP_SECRET_OUTBOX_RETENTION_SECONDS"]
    previous_proof_retention = ENV["APP_SECRET_PROOF_RETENTION_SECONDS"]
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "1"
    ENV["APP_SECRET_OUTBOX_RETENTION_SECONDS"] = "3600"
    ENV["APP_SECRET_PROOF_RETENTION_SECONDS"] = "1"
    withdrawal_at = Client.database_now
    purge_at = withdrawal_at + 0.000001.seconds
    issuance.cancel_for_withdrawal!(at: withdrawal_at, purge_at: purge_at)
    credential.commit_withdrawal_revocation!(at: withdrawal_at, purge_at: purge_at)
    reference = credential.public_id

    assert_nil issuance.reload.encrypted_payload
    assert_nil ClientSecretLookupQuery.call(client: actor, secret: raw)
    assert_equal :undelivered,
                 ClientSecretCredentialPurger.call!(credential: credential, executor_job_id: "withdrawal-before-audit")
    ClientSecretLifecycleJob.perform_now(batch_size: 500)

    assert_not ClientSecretCredential.exists?(credential.id)
    assert_not ClientSecretIssuance.exists?(issuance.id)
    terminal = ClientSecretAuditOutbox.find_by!(credential_ref: reference, event_name: "secret.discarded")

    assert_equal "withdrawal", terminal.reason
    assert Chronicle.exists?(event_uuid: terminal.event_id)
    purged = ClientSecretAuditOutbox.find_by!(credential_ref: reference, event_name: "secret.purged")

    assert_nil purged.delivered_at
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 3600)

    assert Chronicle.exists?(event_uuid: purged.event_id)

    assert_no_difference "Chronicle.count" do
      ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 3600)
    end
  ensure
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = previous_delay
    ENV["APP_SECRET_OUTBOX_RETENTION_SECONDS"] = previous_retention
    ENV["APP_SECRET_PROOF_RETENTION_SECONDS"] = previous_proof_retention
  end

  test "retired allocation waits for Chronicle and legal hold and rolls deletion back with its outbox" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    now = Client.database_now
    issuance = ClientSecretIssuance.create!(
      client: actor, origin: "manual", origin_operation_id: SecureRandom.uuid, attempt_number: 1,
      browser_session_ref: SecureRandom.base58(21), planned_count: 1, expires_at: now - 1.second,
      created_at: now - 1.minute,
    )
    ClientSecretIssuanceExpiryInvalidator.call!(
      issuance: issuance, executor_job_id: "allocation-expiry", purge_after: 0.000001.seconds,
    )

    assert_equal :undelivered,
                 ClientSecretIssuancePurger.call!(issuance: issuance, executor_job_id: "before-Chronicle")
    assert ClientSecretIssuance.exists?(issuance.id)
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 60)
    hold = ClientRetentionHold.create!(client: actor, hold_kind: "legal_hold", reason_code: "legal_hold")

    assert_equal :held, ClientSecretIssuancePurger.call!(issuance: issuance, executor_job_id: "held-allocation")
    hold.update!(status_id: ClientRetentionHoldStatus::RELEASED)
    event_count = ClientSecretAuditOutbox.count
    ClientSecretIssuance.transaction do
      assert_equal :purged, ClientSecretIssuancePurger.call!(issuance: issuance, executor_job_id: "rollback")
      assert_not ClientSecretIssuance.exists?(issuance.id)
      assert_equal event_count + 1, ClientSecretAuditOutbox.count
      raise ActiveRecord::Rollback
    end

    assert ClientSecretIssuance.exists?(issuance.id)
    assert_equal event_count, ClientSecretAuditOutbox.count
    assert_equal :purged,
                 ClientSecretIssuancePurger.call!(issuance: issuance.reload, executor_job_id: "retry-allocation")
    assert_equal 1, ClientSecretAuditOutbox.where(
      operation_ref: issuance.origin_operation_id, event_name: "secret.issuance_purged",
    ).count
  end

  test "unconfirmed allocation collector preserves confirmed and omitted operation facts" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    now = Client.database_now
    confirmed = ClientSecretIssuance.create!(
      client: actor, origin: "manual", origin_operation_id: SecureRandom.uuid, attempt_number: 1,
      browser_session_ref: SecureRandom.base58(21), planned_count: 1,
      expires_at: now - 1.second, presented_at: now - 3.seconds, confirmed_at: now - 2.seconds,
      discard_at: now - 1.second, purge_eligible_at: now - 1.second,
    )
    omitted = ClientSecretIssuance.create!(
      client: actor, origin: "passkey_registration", origin_operation_id: SecureRandom.uuid, attempt_number: 1,
      browser_session_ref: SecureRandom.base58(21), planned_count: 0,
      discard_at: now - 1.second, purge_eligible_at: now - 1.second,
    )
    [confirmed, omitted].each do |issuance|
      assert_equal :pending, ClientSecretIssuancePurger.call!(issuance: issuance, executor_job_id: "preserve-proof")
      assert ClientSecretIssuance.exists?(issuance.id)
      assert_not ClientSecretAuditOutbox.exists?(
        operation_ref: issuance.origin_operation_id, event_name: "secret.issuance_purged",
      )
    end
  end

  test "expired unconfirmed candidates require delivered terminal audit before physical purge" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    now = Client.database_now
    issuance = ClientSecretIssuance.create!(
      client: actor, origin: "manual", origin_operation_id: SecureRandom.uuid, attempt_number: 1,
      browser_session_ref: SecureRandom.base58(21), planned_count: 1,
      expires_at: now - 1.second, created_at: now - 1.minute,
    )
    raw = SecureRandom.base58(32)
    candidate = ClientSecretCredential.create!(
      client: actor, issuance: issuance, name: "Pending", password: raw,
      created_at: now - 2.seconds,
    )
    ClientSecretIssuanceExpiryInvalidator.call!(
      issuance: issuance, executor_job_id: "expiry-test",
      purge_after: 0.000001.seconds,
    )

    assert_nil ClientSecretLookupQuery.call(client: actor, secret: raw)
    assert_equal :dependent, ClientSecretIssuancePurger.call!(issuance: issuance, executor_job_id: "pending-candidate")
    assert_equal :undelivered, ClientSecretCredentialPurger.call!(credential: candidate, executor_job_id: "purge-test")
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 60)

    terminal = ClientSecretAuditOutbox.find_by!(
      operation_ref: issuance.origin_operation_id, event_name: "secret.discarded", credential_ref: nil,
    )
    durable = Chronicle.find_by!(event_uuid: terminal.event_id)
    metadata = durable.metadata
    begin
      # Corrupt the durable target while retaining its UUID and success result.
      durable.update_columns(metadata: {})

      assert_equal :undelivered,
                   ClientSecretCredentialPurger.call!(credential: candidate, executor_job_id: "conflicting-audit")
      assert ClientSecretCredential.exists?(candidate.id)
      assert_not ClientSecretAuditOutbox.exists?(credential_ref: candidate.public_id, event_name: "secret.purged")
    ensure
      durable.update_columns(metadata: metadata)
    end

    assert_equal :purged, ClientSecretCredentialPurger.call!(credential: candidate, executor_job_id: "purge-test")
    assert_not ClientSecretCredential.exists?(candidate.id)
    assert_equal :purged, ClientSecretIssuancePurger.call!(issuance: issuance, executor_job_id: "issuance-purge")
    assert_not ClientSecretIssuance.exists?(issuance.id)
    issuance_purged = ClientSecretAuditOutbox.find_by!(
      operation_ref: issuance.origin_operation_id, event_name: "secret.issuance_purged",
    )

    assert_nil issuance_purged.delivered_at
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 60)

    assert Chronicle.exists?(event_uuid: issuance_purged.event_id)

    assert_equal 1, Chronicle.where(
      action: "secret.purged", metadata: { "client_ref" => actor.public_id,
                                           "credential_ref" => candidate.public_id,
                                           "item_count" => 1, },
    ).count
  end

  test "an existing Chronicle UUID with different immutable facts is not accepted as delivery" do
    policy = @security_policy
    client = clients(:one)
    context = ActorValuesContext.empty.with(subject: client, actor_type: :client, tld: :app, surface: :base)
    event =
      ClientSecretAuditOutbox.transaction do
        ClientSecretAuditOutbox.record!(
          actor_context: context, client_ref: client.public_id,
          operation_ref: SecureRandom.uuid, occurred_at: Client.database_now,
          event_name: "secret.issuance_started", reason: "manual", item_count: 1,
        )
      end
    Chronicle.create!(
      event_uuid: event.event_id, action: event.event_name, result: "succeeded", reason: "flow_canceled",
      actor_type: "Client", actor_id: client.id, subject_type: "Client", subject_id: client.id,
      chronicle_retention_policy: policy, occurred_at: event.occurred_at,
      erasable_at: ChronicleRecordPolicy.erasable_at_for(policy: policy, occurred_at: event.occurred_at),
      request_id: event.operation_ref, metadata: {
        "client_ref" => client.public_id, "actor_public_ref" => client.public_id, "item_count" => 1,
      }, changeset: {},
    )
    assert_raises(ArgumentError) do
      ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 60)
    end
    assert_nil event.reload.delivered_at
    assert_equal 1, Chronicle.where(event_uuid: event.event_id).count
  end

  test "Chronicle commit survives failed source acknowledgment and rescan deduplicates the event" do
    client = clients(:one)
    context = ActorValuesContext.empty.with(subject: client, actor_type: :client, tld: :app, surface: :base)
    event =
      ClientSecretAuditOutbox.transaction do
        ClientSecretAuditOutbox.record!(
          actor_context: context, client_ref: client.public_id,
          operation_ref: SecureRandom.uuid, occurred_at: Client.database_now, event_name: "secret.issuance_started",
          reason: "manual", item_count: 1,
        )
      end
    # Roll back only the Source acknowledgement; Chronicle uses its own connection.
    ClientSecretAuditOutbox.transaction(requires_new: true) do
      ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 60)

      assert event.reload.delivered_at
      assert_equal 1, Chronicle.where(event_uuid: event.event_id).count
      raise ActiveRecord::Rollback
    end

    assert_nil event.reload.delivered_at
    assert_equal 1, Chronicle.where(event_uuid: event.event_id).count
    assert_no_difference("Chronicle.count") do
      ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 60)
    end
    assert event.reload.delivered_at
    assert_equal 1, Chronicle.where(event_uuid: event.event_id).count
  end

  test "real lifecycle delivery precedes credential deletion and preserves its purged event for retry" do
    config_keys = %w(
      APP_SECRET_PURGE_DELAY_SECONDS APP_SECRET_OUTBOX_RETENTION_SECONDS APP_SECRET_PROOF_RETENTION_SECONDS
    )
    original_config = ENV.to_h.slice(*config_keys)
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "60"
    ENV["APP_SECRET_OUTBOX_RETENTION_SECONDS"] = "3600"
    ENV["APP_SECRET_PROOF_RETENTION_SECONDS"] = "1"
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    actor.client_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "public-key", uv_verified_at: Client.database_now,
    )
    token = ClientToken.create!(user: actor)
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
    ClientSecretStorageConfirmationCommitter.call!(actor_context: context, token: token, issuance: issuance)
    credential = ClientSecretLookupQuery.call(client: actor, secret: raw)
    reference = credential.public_id
    ClientSecretRevocationCommitter.call!(
      actor_context: context, token: token, credential: credential, purge_after: 0.000001.seconds,
    )

    assert_nil ClientSecretLookupQuery.call(client: actor, secret: raw)
    assert_equal :undelivered,
                 ClientSecretCredentialPurger.call!(credential: credential, executor_job_id: "before-delivery")
    assert ClientSecretCredential.exists?(credential.id)
    assert_no_difference -> { ClientSecretAuditOutbox.where(event_name: "secret.purged").count } do
      assert_equal :undelivered, ClientSecretCredentialPurger.call!(credential: credential, executor_job_id: "retry")
    end
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 3600)
    ClientSecretCredential.transaction(requires_new: true) do
      assert_equal :purged,
                   ClientSecretCredentialPurger.call!(credential: credential, executor_job_id: "rollback")
      assert_not ClientSecretCredential.exists?(credential.id)
      assert ClientSecretAuditOutbox.exists?(credential_ref: reference, event_name: "secret.purged")
      raise ActiveRecord::Rollback
    end

    assert ClientSecretCredential.exists?(credential.id)
    assert_not ClientSecretAuditOutbox.exists?(credential_ref: reference, event_name: "secret.purged")
    ClientSecretLifecycleJob.perform_now(batch_size: 500)

    assert_not ClientSecretCredential.exists?(credential.id)
    terminal = ClientSecretAuditOutbox.find_by!(credential_ref: reference, event_name: "secret.discarded")

    assert terminal.delivered_at
    assert Chronicle.exists?(event_uuid: terminal.event_id)
    purged = ClientSecretAuditOutbox.find_by!(credential_ref: reference, event_name: "secret.purged")

    assert_nil purged.delivered_at
    assert_not Chronicle.exists?(event_uuid: purged.event_id)
    assert_nil ClientSecretLookupQuery.call(client: actor, secret: raw)
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 3600)

    assert purged.reload.delivered_at
    assert Chronicle.exists?(event_uuid: purged.event_id)
    assert_no_difference("Chronicle.count") do
      ClientSecretLifecycleJob.perform_now(batch_size: 500)
    end
  ensure
    config_keys.each { |key| ENV[key] = original_config[key] }
  end

  test "source events reach Chronicle once and can be rescanned without queue enqueue" do
    # Source outboxes outlive fixture replacement; deliver earlier durable work first.
    while ClientSecretAuditOutbox.exists?(delivered_at: nil)
      ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 60)
    end
    client = clients(:one)
    context = ActorValuesContext.empty.with(subject: client, actor_type: :client, tld: :app, surface: :base)
    event = nil
    ClientSecretAuditOutbox.transaction do
      event = ClientSecretAuditOutbox.record!(
        actor_context: context, client_ref: client.public_id, credential_ref: client_secret_credentials(:one).public_id,
        operation_ref: SecureRandom.uuid, occurred_at: Client.database_now, event_name: "secret.renamed",
      )
    end
    assert_difference("Chronicle.count", 1) do
      ClientSecretAuditDeliveryJob.perform_now(batch_size: 1, retention_seconds: 60)
    end
    assert event.reload.delivered_at
    persisted = Chronicle.find_by!(event_uuid: event.event_id)

    assert_equal "secret.renamed", persisted.action
    assert_equal event.client_ref, persisted.metadata.fetch("client_ref")
    assert_equal event.credential_ref, persisted.metadata.fetch("credential_ref")
    assert_equal event.operation_ref, persisted.request_id
    assert_no_difference("Chronicle.count") {
      ClientSecretAuditDeliveryJob.perform_now(batch_size: 1, retention_seconds: 60)
    }
    assert_nil persisted.metadata["name"]
    assert_nil persisted.metadata["password_digest"]
  end
end
