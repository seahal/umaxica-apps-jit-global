# frozen_string_literal: true

require "test_helper"

class ProcessorErasureNotificationRetryJobTest < ActiveJob::TestCase
  test "rejects an unbounded retry batch before querying notifications" do
    error =
      assert_raises(ArgumentError) do
        ProcessorErasureNotificationRetryJob.perform_now(batch_size: 501)
      end

    assert_equal "batch_size must be between 1 and 500", error.message
  end

  test "rejects a non-positive retry batch" do
    error =
      assert_raises(ArgumentError) do
        ProcessorErasureNotificationRetryJob.perform_now(batch_size: 0)
      end

    assert_equal "batch_size must be between 1 and 500", error.message
  end

  test "rejects a fractional retry batch before querying notifications" do
    error =
      assert_raises(ArgumentError) do
        ProcessorErasureNotificationRetryJob.perform_now(batch_size: 1.5)
      end

    assert_equal "batch_size must be between 1 and 500", error.message
  end

  test "enqueues only due app notifications within the requested batch" do
    due = build_notification
    due.update!(next_retry_at: ClientProcessorErasureNotification.database_now - 1.second)
    future = build_notification
    future.update!(next_retry_at: ClientProcessorErasureNotification.database_now + 1.hour)

    assert_enqueued_with(
      job: ProcessorErasureNotificationJob,
      args: [{ surface: "app", public_id: due.public_id }],
    ) do
      ProcessorErasureNotificationRetryJob.perform_now(batch_size: 1)
    end

    assert_not enqueued_jobs.any? { |job| job[:args].to_s.include?(future.public_id) }
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
