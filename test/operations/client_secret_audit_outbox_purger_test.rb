# frozen_string_literal: true

require "test_helper"

class ClientSecretAuditOutboxPurgerTest < ActiveSupport::TestCase
  test "delivered event without source dependencies can be collected while Chronicle remains" do
    actor = clients(:one)
    ChronicleRetentionPolicy.find_by(code: "security") ||
      ChronicleRetentionPolicy.create!(code: "security", name: "Security", duration_days: 365, permanent: false)
    event =
      ClientSecretAuditOutbox.transaction do
        ClientSecretAuditOutbox.record!(
          actor_context: ActorValuesContext.empty, client_ref: actor.public_id,
          operation_ref: SecureRandom.uuid, occurred_at: Client.database_now,
          event_name: "secret.purged", credential_ref: SecureRandom.base58(21), item_count: 1,
        )
      end

    assert_equal :undelivered, ClientSecretAuditOutboxPurger.call!(event: event)
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 1)

    assert_equal :pending, ClientSecretAuditOutboxPurger.call!(event: event)
    # Observe a real configured retention deadline, not a concurrency ordering.
    Timeout.timeout(3) do
      sleep 0.01 while Client.database_now < event.reload.purge_eligible_at
    end

    assert_equal :purged, ClientSecretAuditOutboxPurger.call!(event: event)
    assert_not ClientSecretAuditOutbox.exists?(event.id)
    assert Chronicle.exists?(event_uuid: event.event_id, action: "secret.purged")
  end
  test "delivered source dependencies and collected-operation replay barriers survive retention" do
    actor = clients(:one)
    credential = client_secret_credentials(:one)
    ChronicleRetentionPolicy.find_by(code: "security") ||
      ChronicleRetentionPolicy.create!(code: "security", name: "Security", duration_days: 365, permanent: false)
    events =
      ClientSecretAuditOutbox.transaction do
        [
          ClientSecretAuditOutbox.record!(
            actor_context: ActorValuesContext.empty, client_ref: actor.public_id,
            operation_ref: SecureRandom.uuid, occurred_at: Client.database_now,
            event_name: "secret.discarded", credential_ref: credential.public_id,
          ),
          ClientSecretAuditOutbox.record!(
            actor_context: ActorValuesContext.empty, client_ref: actor.public_id,
            operation_ref: SecureRandom.uuid, occurred_at: Client.database_now,
            event_name: "secret.issuance_purged", item_count: 1,
          ),
        ]
      end
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 1)
    Timeout.timeout(3) do
      sleep 0.01 while Client.database_now < events.map { |event| event.reload.purge_eligible_at }.max
    end

    assert_equal :dependent, ClientSecretAuditOutboxPurger.call!(event: events.first)
    assert_equal :replay_barrier, ClientSecretAuditOutboxPurger.call!(event: events.last)
    assert events.all? { |event| ClientSecretAuditOutbox.exists?(event.id) }
    assert ClientSecretCredential.exists?(credential.id)
  end
  test "a retained replay barrier does not starve later collectible outbox rows in a bounded scan" do
    previous_delay = ENV["APP_SECRET_PURGE_DELAY_SECONDS"]
    previous_retention = ENV["APP_SECRET_OUTBOX_RETENTION_SECONDS"]
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "86400"
    ENV["APP_SECRET_OUTBOX_RETENTION_SECONDS"] = "3600"
    actor = clients(:one)
    ChronicleRetentionPolicy.find_by(code: "security") ||
      ChronicleRetentionPolicy.create!(code: "security", name: "Security", duration_days: 365, permanent: false)
    events = ClientSecretAuditOutbox.transaction do
      %w(secret.issuance_purged secret.purged).map do |name|
        ClientSecretAuditOutbox.record!(
          actor_context: ActorValuesContext.empty, client_ref: actor.public_id,
          operation_ref: SecureRandom.uuid, occurred_at: Client.database_now, event_name: name,
        )
      end
    end
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 1)
    Timeout.timeout(3) do
      sleep 0.01 while Client.database_now < events.map { |event| event.reload.purge_eligible_at }.max
    end
    ClientSecretLifecycleJob.perform_now(batch_size: 1)

    assert ClientSecretAuditOutbox.exists?(events.first.id)
    assert_not ClientSecretAuditOutbox.exists?(events.last.id)
    assert Chronicle.exists?(event_uuid: events.last.event_id)
  ensure
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = previous_delay
    ENV["APP_SECRET_OUTBOX_RETENTION_SECONDS"] = previous_retention
  end

end
