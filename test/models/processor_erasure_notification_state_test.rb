# frozen_string_literal: true

require "test_helper"

class ProcessorErasureNotificationStateTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "retryable failure schedules retry from the supplied decision time" do
    notification = build_notification
    decision_time = Time.utc(2026, 9, 1, 12, 0, 0)
    policy = ProcessorErasureRetryPolicy.new(max_attempts: 2, retry_delay_seconds: 15.minutes.to_i)
    attempt = notification.begin_attempt!(retry_policy: policy, now: decision_time)

    notification.mark_retryable_failure!(
      attempt: attempt,
      policy: policy,
      code: "temporary",
      message: "retry",
      now: decision_time,
    )

    assert_equal decision_time + 15.minutes, notification.reload.next_retry_at
    assert_equal "RETRYABLE_FAILURE", notification.status_name
  end

  test "pending scope uses the owning writer database clock when no time is supplied" do
    notification = build_notification
    decision_time = Time.utc(2026, 9, 1, 12, 0, 0)
    notification.update!(next_retry_at: decision_time + 1.second)

    ClientProcessorErasureNotification.stub(:database_now, decision_time) do
      assert_not_predicate(
        ClientProcessorErasureNotification.pending_for_processing.where(id: notification.id),
        :exists?,
      )
    end

    ClientProcessorErasureNotification.stub(:database_now, decision_time + 1.second) do
      assert_predicate(
        ClientProcessorErasureNotification.pending_for_processing.where(id: notification.id),
        :exists?,
      )
    end
  end

  test "permanent notifications are unchanged by later worker transitions" do
    notified_at = Time.utc(2026, 9, 1, 12, 0, 0)

    %w(NOTIFIED SKIPPED PERMANENT_FAILURE).each do |status_name|
      notification = build_notification
      terminal_notified_at = nil
      terminal_notified_at = notified_at if status_name == "NOTIFIED"
      notification.update!(
        status_id: ClientProcessorErasureNotification.status_id_for(status_name),
        notified_at: terminal_notified_at,
        permanent_failed_at: (status_name == "PERMANENT_FAILURE") ? notified_at : nil,
        retry_count: 3,
        next_retry_at: nil,
        last_error_code: "existing_error",
        last_error_message: "existing message",
      )
      before = notification.reload.attributes.slice(
        "status_id", "notified_at", "failed_at", "retry_count", "next_retry_at",
        "last_error_code", "last_error_message",
      )

      assert_nil notification.begin_attempt!(
        retry_policy: ProcessorErasureRetryPolicy.new(max_attempts: 2, retry_delay_seconds: 0),
        now: notified_at + 1.hour,
      )

      assert_equal before, notification.reload.attributes.slice(
        "status_id", "notified_at", "failed_at", "retry_count", "next_retry_at",
        "last_error_code", "last_error_message",
      ), status_name
    end
  end

  test "retryable failure rejects unsafe error codes without changing the attempt" do
    notification = build_notification
    decision_time = Time.utc(2026, 9, 1, 12, 0, 0)
    policy = ProcessorErasureRetryPolicy.new(max_attempts: 2, retry_delay_seconds: 15.minutes.to_i)
    attempt = notification.begin_attempt!(retry_policy: policy, now: decision_time)

    assert_raises(ArgumentError) do
      notification.mark_retryable_failure!(
        attempt: attempt,
        policy: policy,
        code: "provider token=secret",
        message: "temporary",
        now: decision_time,
      )
    end

    assert_equal "PENDING", notification.reload.status_name
    assert_equal "IN_FLIGHT", attempt.reload.outcome
  end

  test "permanent failure rejects unsafe error codes without changing the attempt" do
    notification = build_notification
    decision_time = Time.utc(2026, 9, 1, 12, 0, 0)
    attempt = notification.begin_attempt!(
      retry_policy: ProcessorErasureRetryPolicy.new(max_attempts: 1, retry_delay_seconds: 0),
      now: decision_time,
    )

    assert_raises(ArgumentError) do
      notification.mark_permanent_failure!(
        attempt: attempt,
        code: "provider token=secret",
        message: "permanent",
        now: decision_time,
      )
    end

    assert_equal "PENDING", notification.reload.status_name
    assert_equal "IN_FLIGHT", attempt.reload.outcome
  end

  test "direct retryable failure transition sanitizes persisted error messages" do
    notification = build_notification
    decision_time = Time.utc(2026, 9, 1, 12, 0, 0)
    policy = ProcessorErasureRetryPolicy.new(max_attempts: 2, retry_delay_seconds: 15.minutes.to_i)
    attempt = notification.begin_attempt!(retry_policy: policy, now: decision_time)
    raw_token = "c" * 40

    notification.mark_retryable_failure!(
      attempt: attempt,
      policy: policy,
      code: "temporary",
      message: "provider token=#{raw_token}",
      now: decision_time,
    )

    assert_nil notification.reload.last_error_message.index(raw_token)
    assert_nil attempt.reload.error_message.index(raw_token)
    assert_includes notification.last_error_message, "[FILTERED]"
    assert_includes attempt.error_message, "[FILTERED]"
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
