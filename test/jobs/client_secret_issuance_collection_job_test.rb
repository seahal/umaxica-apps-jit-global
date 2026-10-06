# frozen_string_literal: true

require "test_helper"

class ClientSecretIssuanceCollectionJobTest < ActiveJob::TestCase
  test "continuation retires expired plaintext after a preceding live allocation without waiting for deletion" do
    previous = ENV["APP_SECRET_PURGE_DELAY_SECONDS"]
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "86400"
    actor = clients(:one)
    now = Client.database_now
    live = ClientSecretIssuance.create!(
      client: actor, origin_operation_id: SecureRandom.uuid, origin: "manual", attempt_number: 1,
      browser_session_ref: "live-browser", planned_count: 1, expires_at: now + 1.minute,
    )
    expired = ClientSecretIssuance.create!(
      client: actor, origin_operation_id: SecureRandom.uuid, origin: "manual", attempt_number: 1,
      browser_session_ref: "expired-browser", planned_count: 1, expires_at: now - 1.second,
      created_at: now - 1.minute, encrypted_payload: "opaque-expired-payload",
    )
    raw = SecureRandom.base58(32)
    candidate = ClientSecretCredential.create!(
      client: actor, issuance: expired, name: "Unconfirmed candidate", password: raw,
    )
    ClientSecretIssuanceCollectionJob.perform_now(batch_size: 1, after_id: live.id - 1)

    assert_equal "opaque-expired-payload", expired.reload.encrypted_payload
    while enqueued_jobs.any? { |entry| entry.fetch(:job) == ClientSecretIssuanceCollectionJob }
      perform_enqueued_jobs(only: ClientSecretIssuanceCollectionJob)
    end

    assert_nil expired.reload.encrypted_payload
    assert_equal expired.discard_at, candidate.reload.discard_at
    assert_equal 1.day, expired.purge_eligible_at - expired.discard_at
    assert_nil ClientSecretLookupQuery.call(client: actor, secret: raw)
    assert_equal Float::INFINITY, live.reload.discard_at
    assert ClientSecretIssuance.exists?(expired.id)
    assert ClientSecretAuditOutbox.exists?(
      operation_ref: expired.origin_operation_id, credential_ref: nil,
      event_name: "secret.discarded", reason: "flow_expired",
    )
    snapshot = expired.attributes
    assert_no_difference("ClientSecretAuditOutbox.count") do
      ClientSecretIssuanceCollectionJob.perform_now(batch_size: 1, after_id: expired.id - 1, through_id: expired.id)
    end
    assert_equal snapshot, expired.reload.attributes
  ensure
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = previous
  end

  test "batch rejects zero and five hundred one and accepts adjacent valid boundaries" do
    [0, 501, nil, "1", 0.5].each do |value|
      assert_raises(ArgumentError) { ClientSecretIssuanceCollectionJob.perform_now(batch_size: value) }
    end
    [1, 2, 499, 500].each do |value|
      assert_no_enqueued_jobs do
        ClientSecretIssuanceCollectionJob.perform_now(batch_size: value, after_id: 0, through_id: 0)
      end
    end
  end

  test "cursor rejects negative noninteger and reversed bounds and accepts equality and its upper neighbor" do
    [-1, nil, "0", 0.5].each do |value|
      assert_raises(ArgumentError) { ClientSecretIssuanceCollectionJob.perform_now(after_id: value) }
    end
    [-1, "1", 0.5].each do |value|
      assert_raises(ArgumentError) { ClientSecretIssuanceCollectionJob.perform_now(through_id: value) }
    end
    assert_raises(ArgumentError) { ClientSecretIssuanceCollectionJob.perform_now(after_id: 1, through_id: 0) }
    [0, 1].each do |value|
      assert_no_enqueued_jobs do
        ClientSecretIssuanceCollectionJob.perform_now(after_id: 0, through_id: value)
      end
    end
  end

  test "bounded continuation advances past retained authority and preserves its original scan horizon" do
    previous = ENV["APP_SECRET_PROOF_RETENTION_SECONDS"]
    ENV["APP_SECRET_PROOF_RETENTION_SECONDS"] = "1"
    actor = clients(:one)
    token = ClientToken.create!(user: actor)
    token.schedule_retention!(discard_at: Float::INFINITY, purge_eligible_at: Float::INFINITY)
    expired = ClientToken.create!(user: actor, discard_at: ClientToken.database_now - 2.seconds)
    ChronicleRetentionPolicy.find_by(code: "security") ||
      ChronicleRetentionPolicy.create!(code: "security", name: "Security", duration_days: 365, permanent: false)
    allocations =
      ClientSecretIssuance.transaction do
        [token, expired].map do |binding|
          at = Client.database_now - 3.seconds
          row = ClientSecretIssuance.create!(
            client: actor, origin: "passkey_registration", origin_operation_id: SecureRandom.uuid,
            attempt_number: 1, browser_session_ref: binding.public_id, planned_count: 0,
            created_at: at, updated_at: at,
          )
          ClientSecretAuditOutbox.record!(
            actor_context: ActorValuesContext.empty, client_ref: actor.public_id,
            operation_ref: row.origin_operation_id, occurred_at: at,
            event_name: "secret.issuance_omitted", reason: "capacity_full", item_count: 0,
          )
          row
        end
      end
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 3600)

    assert_enqueued_jobs 1, only: ClientSecretIssuanceCollectionJob do
      ClientSecretIssuanceCollectionJob.perform_now(batch_size: 1, after_id: allocations.first.id - 1)
    end
    assert allocations.all? { |row| ClientSecretIssuance.exists?(row.id) }
    later =
      ClientSecretIssuance.transaction do
        at = Client.database_now - 3.seconds
        row = ClientSecretIssuance.create!(
          client: actor, origin: "passkey_registration", origin_operation_id: SecureRandom.uuid,
          attempt_number: 1, browser_session_ref: expired.public_id, planned_count: 0,
          created_at: at, updated_at: at,
        )
        ClientSecretAuditOutbox.record!(
          actor_context: ActorValuesContext.empty, client_ref: actor.public_id,
          operation_ref: row.origin_operation_id, occurred_at: at,
          event_name: "secret.issuance_omitted", reason: "capacity_full", item_count: 0,
        )
        row
      end
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 3600)
    while enqueued_jobs.any? { |entry| entry.fetch(:job) == ClientSecretIssuanceCollectionJob }
      perform_enqueued_jobs(only: ClientSecretIssuanceCollectionJob)
    end

    assert ClientSecretIssuance.exists?(allocations.first.id)
    assert_not ClientSecretIssuance.exists?(allocations.last.id)
    assert ClientSecretIssuance.exists?(later.id)
    assert ClientToken.exists?(expired.id)
    assert ClientSecretAuditOutbox.exists?(
      operation_ref: allocations.last.origin_operation_id, event_name: "secret.issuance_purged", item_count: 0,
    )
    ClientSecretIssuanceCollectionJob.perform_now(batch_size: 500)

    assert_not ClientSecretIssuance.exists?(later.id)
    assert ClientSecretIssuance.exists?(allocations.first.id)
  ensure
    ENV["APP_SECRET_PROOF_RETENTION_SECONDS"] = previous
  end
end
