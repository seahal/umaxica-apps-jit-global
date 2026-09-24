# typed: false
# frozen_string_literal: true

require "test_helper"

# A single connection or transactional fixture cannot prove that the notification row lock
# serializes claims and receipt application. These tests require committed rows and independent
# PostgreSQL connections.
# rubocop:disable ThreadSafety/NewThread
class ProcessorErasureNotificationConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)

    @client = Client.create!(
      status_id: ClientStatus::NOTHING,
      visibility_id: ClientVisibility::USER,
      mfa_level_id: ClientMfaLevel::NOTHING,
      mfa_status_id: ClientMfaStatus::UNCONFIGURED,
    )
    @privacy_request = ClientPrivacyRequest.create!(client: @client)
    @notification = ClientProcessorErasureNotification.create!(
      client_privacy_request: @privacy_request,
      processor_key: "email_delivery",
    )
  end

  teardown do
    next unless @notification

    ClientProcessorErasureNotificationAttempt.where(
      client_processor_erasure_notification_id: @notification.id,
    ).delete_all
    ClientProcessorErasureNotification.where(id: @notification.id).delete_all
    ClientPrivacyRequest.where(id: @privacy_request.id).delete_all if @privacy_request
    ClientAuthorityLock.where(client_id: @client.id).delete_all if @client
    Client.where(id: @client.id).delete_all if @client
  end

  test "concurrent workers claim at most one in-flight attempt" do
    policy = ProcessorErasureRetryPolicy.new(max_attempts: 2, retry_delay_seconds: 0)
    ActiveRecord::Base.connection_handler.clear_active_connections!

    outcomes =
      concurrently(2) do
        ClientProcessorErasureNotification.find(@notification.id).begin_attempt!(retry_policy: policy)&.id
      end

    errors = outcomes.grep(Exception)

    assert_empty errors, errors.map { |error| "#{error.class}: #{error.message}" }.join("\n")
    assert_equal 1, outcomes.compact.size, outcomes.inspect
    assert_equal 1, @notification.reload.attempts.count
    assert_equal "IN_FLIGHT", @notification.attempts.first.outcome
  end

  test "concurrent application of one verified receipt is idempotent" do
    policy = ProcessorErasureRetryPolicy.new(max_attempts: 2, retry_delay_seconds: 0)
    attempt = @notification.begin_attempt!(retry_policy: policy)
    receipt = ProcessorErasureVerifiedReceipt.new(
      processor_key: @notification.processor_key,
      notification_public_id: @notification.public_id,
      generation: attempt.delivery_generation,
      idempotency_key_digest: attempt.idempotency_key_digest,
      receipt_id: "concurrent-receipt",
      verified_at: Time.current,
    )
    ActiveRecord::Base.connection_handler.clear_active_connections!

    outcomes =
      concurrently(2) do
        ClientProcessorErasureNotification.find(@notification.id).apply_verified_receipt!(receipt: receipt)
        :applied
      end

    errors = outcomes.grep(Exception)

    assert_empty errors, errors.map { |error| "#{error.class}: #{error.message}" }.join("\n")

    assert_equal %i(applied applied), outcomes.sort
    assert_equal "NOTIFIED", @notification.reload.status_name
    assert_equal 1, @notification.attempts.where(outcome: "SUCCEEDED").count
  end

  private

  def concurrently(count)
    ready = Queue.new
    release = Queue.new
    threads =
      Array.new(count) do
        Thread.new do # rubocop:disable ThreadSafety/NewThread
          AppZenithRecord.connection_pool.with_connection do
            ready << true
            release.pop
            yield
          end
        rescue StandardError => e
          e
        end
      end

    count.times { ready.pop }
    count.times { release << true }
    threads.map(&:value).tap { threads.each(&:join) }
  end
end
# rubocop:enable ThreadSafety/NewThread
