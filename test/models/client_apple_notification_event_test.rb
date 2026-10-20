# frozen_string_literal: true

require "test_helper"

class ClientAppleNotificationEventTest < ActiveSupport::TestCase
  test "bounds retry attempts and moves exhausted events to dead letter" do
    event = ClientAppleNotificationEvent.create!(
      jti: "notification-#{SecureRandom.hex(8)}",
      event_type: "consent-revoked",
      received_at: Time.utc(2026, 7, 24, 12, 0, 0),
      occurred_at: Time.utc(2026, 7, 24, 12, 0, 0),
    )

    assert_equal :retrying, event.retry_or_dead_letter!(code: "processing_failure", now: event.received_at)
    assert_equal 1, event.processing_attempts
    assert_equal event.received_at + 2.minutes, event.next_retry_at

    event.update!(processing_attempts: ClientAppleNotificationEvent::MAXIMUM_ATTEMPTS - 1)

    assert_equal :dead_letter, event.retry_or_dead_letter!(code: "processing_failure", now: event.received_at)
    assert_equal "dead_letter", event.status
    assert_predicate event.dead_lettered_at, :present?
  end

  test "does not retain a raw notification payload column" do
    assert_not_includes ClientAppleNotificationEvent.column_names, "payload"
    assert_not_includes ClientAppleNotificationEvent.column_names, "raw_jws"
  end

  test "retains the minimal event while nullifying a removed legacy identity" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: PublicId.generate)
    identity = ClientAppleIdentity.create!(
      user: client,
      provider: "apple",
      uid: "notification-removal-#{SecureRandom.hex(8)}",
      token_expires_at: 0,
      status_id: ClientAppleIdentityStatus::ACTIVE,
    )
    event = ClientAppleNotificationEvent.create!(
      jti: "notification-removal-#{SecureRandom.hex(8)}",
      event_type: "consent-revoked",
      client: client,
      client_external_identity: identity,
      received_at: Time.current,
      occurred_at: Time.current,
    )

    identity.destroy!

    assert_nil event.reload.client_external_identity_id
    assert_equal client.id, event.client_id
  end

  test "complete! closes the event and terminal? reports the settled statuses" do
    event = ClientAppleNotificationEvent.create!(
      jti: "notification-#{SecureRandom.hex(8)}",
      event_type: "email-disabled",
      received_at: Time.utc(2026, 7, 24, 12, 0, 0),
      occurred_at: Time.utc(2026, 7, 24, 12, 0, 0),
    )

    assert_not_predicate event, :terminal?

    event.retry_or_dead_letter!(code: "processing_failure", now: event.received_at)

    assert_equal "retrying", event.status
    assert_not_predicate event, :terminal?

    processed_at = event.received_at + 5.minutes
    event.complete!(now: processed_at)

    assert_equal "completed", event.status
    assert_equal processed_at, event.processed_at
    assert_nil event.next_retry_at
    assert_equal "", event.failure_code
    assert_predicate event, :terminal?
  end
end
