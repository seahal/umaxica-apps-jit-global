# frozen_string_literal: true

require "test_helper"

class ProcessorErasureNotificationStateTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "mark_failed schedules retry from the supplied decision time" do
    notification = build_notification
    decision_time = Time.utc(2026, 9, 1, 12, 0, 0)

    notification.mark_failed!(code: "temporary", message: "retry", now: decision_time)

    assert_equal decision_time + 15.minutes, notification.reload.next_retry_at
  end

  test "terminal notifications are unchanged by later transition attempts" do
    notified_at = Time.utc(2026, 9, 1, 12, 0, 0)

    %w(NOTIFIED SKIPPED).each do |status_name|
      notification = build_notification
      stale_notification = ClientProcessorErasureNotification.find(notification.id)
      terminal_notified_at = nil
      terminal_notified_at = notified_at if status_name == "NOTIFIED"
      notification.update!(
        status_id: ClientProcessorErasureNotification.status_id_for(status_name),
        notified_at: terminal_notified_at,
        retry_count: 3,
        next_retry_at: notified_at + 15.minutes,
        last_error_code: "existing_error",
        last_error_message: "existing message",
      )
      before = notification.reload.attributes.slice(
        "status_id", "notified_at", "failed_at", "retry_count", "next_retry_at",
        "last_error_code", "last_error_message",
      )

      stale_notification.mark_failed!(code: "new_error", message: "new message", now: notified_at + 1.hour)
      stale_notification.mark_notified!(now: notified_at + 2.hours)

      assert_equal before, notification.reload.attributes.slice(
        "status_id", "notified_at", "failed_at", "retry_count", "next_retry_at",
        "last_error_code", "last_error_message",
      ), status_name
    end
  end

  private

  def build_notification
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    client = Client.create!(
      status_id: ClientStatus::NOTHING,
      visibility_id: ClientVisibility::USER,
      mfa_level_id: ClientMfaLevel::NOTHING,
      mfa_status_id: ClientMfaStatus::UNCONFIGURED,
    )
    privacy_request = ClientPrivacyRequest.create!(client: client)

    ClientProcessorErasureNotification.create!(
      client_privacy_request: privacy_request,
      processor_key: "email_delivery",
    )
  end
end
