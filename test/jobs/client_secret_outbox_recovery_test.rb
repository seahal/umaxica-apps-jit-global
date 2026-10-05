# frozen_string_literal: true

require "test_helper"

class ClientSecretOutboxRecoveryTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_statuses client_mfa_levels client_mfa_statuses client_visibilities)

  test "periodic retention rescans a surviving outbox whose Client has no Secret source rows" do
    previous_delay = ENV["APP_SECRET_PURGE_DELAY_SECONDS"]
    previous_retention = ENV["APP_SECRET_OUTBOX_RETENTION_SECONDS"]
    previous_proof = ENV["APP_SECRET_PROOF_RETENTION_SECONDS"]
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "86400"
    ENV["APP_SECRET_OUTBOX_RETENTION_SECONDS"] = "604800"
    ENV["APP_SECRET_PROOF_RETENTION_SECONDS"] = "2592000"
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    ChronicleRetentionPolicy.find_by(code: "security") ||
      ChronicleRetentionPolicy.create!(code: "security", name: "Security", duration_days: 365, permanent: false)
    # Unrelated durable rows can survive other tests; deliver their events without deleting them.
    while ClientSecretAuditOutbox.exists?(delivered_at: nil)
      ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 604_800)
    end
    # A committed source event is setup evidence for the recovery scanner.
    event =
      ClientSecretAuditOutbox.transaction do
        ClientSecretAuditOutbox.record!(
          actor_context: ActorValuesContext.empty, client_ref: actor.public_id,
          operation_ref: SecureRandom.uuid, occurred_at: Client.database_now,
          event_name: "secret.issuance_purged", item_count: 1, executor_job_id: "prior-delete",
        )
      end

    assert_equal 0, ClientSecretCredential.where(client_id: actor.id).count
    assert_equal 0, ClientSecretIssuance.where(client_id: actor.id).count
    RetentionPurgeJob.perform_now(batch_size: 10)

    assert event.reload.delivered_at
    assert Chronicle.exists?(event_uuid: event.event_id, action: "secret.issuance_purged")
    assert_no_difference("Chronicle.count") do
      RetentionPurgeJob.perform_now(batch_size: 10)
    end
  ensure
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = previous_delay
    ENV["APP_SECRET_OUTBOX_RETENTION_SECONDS"] = previous_retention
    ENV["APP_SECRET_PROOF_RETENTION_SECONDS"] = previous_proof
  end
end
