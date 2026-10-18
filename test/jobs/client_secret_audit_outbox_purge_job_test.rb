# frozen_string_literal: true

require "test_helper"

class ClientSecretAuditOutboxPurgeJobTest < ActiveJob::TestCase
  test "batch size rejects zero and five hundred one while accepting the adjacent boundaries" do
    [0, 501, nil, "1"].each do |value|
      assert_raises(ArgumentError) { ClientSecretAuditOutboxPurgeJob.perform_now(batch_size: value) }
    end
    [1, 500].each do |value|
      assert_no_enqueued_jobs do
        ClientSecretAuditOutboxPurgeJob.perform_now(batch_size: value, after_id: 0, through_id: 0)
      end
    end
  end

  test "cursor inputs reject negative missing noninteger and reversed bounds" do
    [-1, nil, "0"].each do |value|
      assert_raises(ArgumentError) { ClientSecretAuditOutboxPurgeJob.perform_now(after_id: value) }
    end
    [-1, "1", 0.5].each do |value|
      assert_raises(ArgumentError) { ClientSecretAuditOutboxPurgeJob.perform_now(through_id: value) }
    end
    assert_raises(ArgumentError) { ClientSecretAuditOutboxPurgeJob.perform_now(after_id: 1, through_id: 0) }
    assert_no_enqueued_jobs do
      ClientSecretAuditOutboxPurgeJob.perform_now(after_id: 1, through_id: 1)
    end
  end

  test "a dependent first row retains its evidence while a queued bounded continuation collects later rows" do
    actor = clients(:one)
    ChronicleRetentionPolicy.find_by(code: "security") ||
      ChronicleRetentionPolicy.create!(code: "security", name: "Security", duration_days: 365, permanent: false)
    events =
      ClientSecretAuditOutbox.transaction do
        [ClientSecretAuditOutbox.record!(
          actor_context: ActorValuesContext.empty, client_ref: actor.public_id,
          credential_ref: client_secret_credentials(:one).public_id,
          operation_ref: SecureRandom.uuid, occurred_at: Client.database_now, event_name: "secret.discarded",
        ), ClientSecretAuditOutbox.record!(
          actor_context: ActorValuesContext.empty, client_ref: actor.public_id,
          operation_ref: SecureRandom.uuid, occurred_at: Client.database_now, event_name: "secret.purged",
        ),]
      end
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 1)
    Timeout.timeout(3) do
      sleep 0.01 while Client.database_now < events.map { |event| event.reload.purge_eligible_at }.max
    end
    assert_enqueued_jobs 1, only: ClientSecretAuditOutboxPurgeJob do
      ClientSecretAuditOutboxPurgeJob.perform_now(batch_size: 1)
    end
    assert events.all? { |event| ClientSecretAuditOutbox.exists?(event.id) }
    # Each invocation processes one bounded batch; flush the complete durable cursor chain.
    while enqueued_jobs.any? { |entry| entry.fetch(:job) == ClientSecretAuditOutboxPurgeJob }
      perform_enqueued_jobs(only: ClientSecretAuditOutboxPurgeJob)
    end

    assert ClientSecretAuditOutbox.exists?(events.first.id)
    assert_not ClientSecretAuditOutbox.uncached { ClientSecretAuditOutbox.exists?(events.last.id) }
    assert Chronicle.exists?(event_uuid: events.last.event_id)
  end
end
