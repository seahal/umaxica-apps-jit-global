# frozen_string_literal: true

require "test_helper"

class ProcessorErasureNotificationDeliveryContractTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  include ActiveJob::TestHelper

  class FakeAdapter
    attr_reader :receipts

    def initialize(outcome:, max_attempts: 2)
      @outcome = outcome
      @policy = ProcessorErasureRetryPolicy.new(max_attempts: max_attempts, retry_delay_seconds: 0)
      @receipts = []
    end

    def retry_policy = @policy

    def dispatch(notification:, attempt:)
      return ProcessorErasureDispatchResult.retryable(code: "temporary", message: "try again") if @outcome == :retryable
      if @outcome == :permanent
        return ProcessorErasureDispatchResult.permanent(code: "processor_rejected", message: "permanent")
      end
      return ProcessorErasureDispatchResult.accepted_without_receipt if @outcome == :pending

      receipt = ProcessorErasureVerifiedReceipt.new(
        processor_key: notification.processor_key,
        notification_public_id: notification.public_id,
        generation: attempt.delivery_generation,
        idempotency_key_digest: attempt.idempotency_key_digest,
        receipt_id: "receipt-#{attempt.id}",
        verified_at: Time.current,
      )
      @receipts << receipt
      ProcessorErasureDispatchResult.received(receipt: receipt)
    end
  end

  class ReceiptAdapter
    def initialize(receipt)
      @receipt = receipt
    end

    def verify_receipt(**)
      @receipt
    end
  end

  test "a notification without a verified receipt never becomes notified" do
    notification = build_notification
    adapter = FakeAdapter.new(outcome: :pending)

    ProcessorErasureNotificationAdapterRegistry.stub(:fetch, adapter) do
      assert_enqueued_with(
        job: ProcessorErasureNotificationJob,
        queue: "retention",
        args: [{ surface: "app", public_id: notification.public_id }],
      ) do
        ProcessorErasureNotificationJob.perform_now(surface: "app", public_id: notification.public_id)
      end
    end

    notification.reload

    assert_equal "PENDING", notification.status_name
    assert_nil notification.notified_at
    assert_equal "ACCEPTED_PENDING", notification.attempts.first.outcome
  end

  test "only a receipt bound to the current attempt can notify" do
    notification = build_notification
    adapter = FakeAdapter.new(outcome: :receipt)

    ProcessorErasureNotificationAdapterRegistry.stub(:fetch, adapter) do
      ProcessorErasureNotificationJob.perform_now(surface: "app", public_id: notification.public_id)
    end

    notification.reload

    assert_equal "NOTIFIED", notification.status_name
    assert_equal "SUCCEEDED", notification.attempts.first.outcome
    assert_predicate notification.notified_at, :present?
  end

  test "wrong notification, processor, generation, or idempotency receipt is rejected" do
    notification = build_notification
    attempt = notification.begin_attempt!(
      retry_policy: ProcessorErasureRetryPolicy.new(
        max_attempts: 2,
        retry_delay_seconds: 0,
      ),
    )

    invalid_receipts = [
      ProcessorErasureVerifiedReceipt.new(
        processor_key: notification.processor_key,
        notification_public_id: "different-notification",
        generation: attempt.delivery_generation,
        idempotency_key_digest: attempt.idempotency_key_digest,
        receipt_id: "receipt-invalid-1",
        verified_at: Time.current,
      ),
      ProcessorErasureVerifiedReceipt.new(
        processor_key: "different-processor",
        notification_public_id: notification.public_id,
        generation: attempt.delivery_generation,
        idempotency_key_digest: attempt.idempotency_key_digest,
        receipt_id: "receipt-invalid-2",
        verified_at: Time.current,
      ),
      ProcessorErasureVerifiedReceipt.new(
        processor_key: notification.processor_key,
        notification_public_id: notification.public_id,
        generation: attempt.delivery_generation + 1,
        idempotency_key_digest: attempt.idempotency_key_digest,
        receipt_id: "receipt-invalid-3",
        verified_at: Time.current,
      ),
      ProcessorErasureVerifiedReceipt.new(
        processor_key: notification.processor_key,
        notification_public_id: notification.public_id,
        generation: attempt.delivery_generation,
        idempotency_key_digest: Digest::SHA256.hexdigest("different-digest"),
        receipt_id: "receipt-invalid-4",
        verified_at: Time.current,
      ),
    ]

    invalid_receipts.each do |receipt|
      assert_raises(ProcessorErasureNotificationReceiptError) do
        notification.apply_verified_receipt!(receipt: receipt)
      end
    end

    assert_equal "PENDING", notification.reload.status_name
    assert_nil notification.notified_at
  end

  test "receipt consumer applies only an adapter-verified receipt" do
    notification = build_notification
    attempt = notification.begin_attempt!(
      retry_policy: ProcessorErasureRetryPolicy.new(max_attempts: 2, retry_delay_seconds: 0),
    )
    receipt = ProcessorErasureVerifiedReceipt.new(
      processor_key: notification.processor_key,
      notification_public_id: notification.public_id,
      generation: attempt.delivery_generation,
      idempotency_key_digest: attempt.idempotency_key_digest,
      receipt_id: "consumer-receipt",
      verified_at: Time.current,
    )

    ProcessorErasureNotificationAdapterRegistry.stub(:fetch, ReceiptAdapter.new(receipt)) do
      ProcessorErasureNotificationReceiptConsumer.call(
        surface: "app",
        public_id: notification.public_id,
        raw_receipt: "provider-payload",
      )
    end

    assert_equal "NOTIFIED", notification.reload.status_name
  end

  test "receipt consumer rejects an adapter response that is not a verified receipt" do
    notification = build_notification
    adapter = Object.new
    adapter.define_singleton_method(:verify_receipt) { |**| Object.new }

    ProcessorErasureNotificationAdapterRegistry.stub(:fetch, adapter) do
      assert_raises(ProcessorErasureNotificationReceiptError) do
        ProcessorErasureNotificationReceiptConsumer.call(
          surface: "app",
          public_id: notification.public_id,
          raw_receipt: "forged-payload",
        )
      end
    end

    assert_equal "PENDING", notification.reload.status_name
    assert_empty notification.attempts
  end

  test "a receipt cannot reopen a terminal notification" do
    notification = build_notification
    attempt = notification.begin_attempt!(
      retry_policy: ProcessorErasureRetryPolicy.new(max_attempts: 2, retry_delay_seconds: 0),
    )
    notification.update!(
      status_id: notification.class.status_id_for("PERMANENT_FAILURE"),
      permanent_failed_at: notification.class.database_now,
    )
    receipt = ProcessorErasureVerifiedReceipt.new(
      processor_key: notification.processor_key,
      notification_public_id: notification.public_id,
      generation: attempt.delivery_generation,
      idempotency_key_digest: attempt.idempotency_key_digest,
      receipt_id: "late-terminal-receipt",
      verified_at: Time.current,
    )

    assert_raises(ProcessorErasureNotificationReceiptError) do
      notification.apply_verified_receipt!(receipt: receipt)
    end

    assert_equal "PERMANENT_FAILURE", notification.reload.status_name
  end

  test "a duplicate valid receipt is idempotent and a late receipt is rejected" do
    notification = build_notification
    adapter = FakeAdapter.new(outcome: :receipt)

    ProcessorErasureNotificationAdapterRegistry.stub(:fetch, adapter) do
      ProcessorErasureNotificationJob.perform_now(surface: "app", public_id: notification.public_id)
    end

    receipt = adapter.receipts.fetch(0)
    notified_at = notification.reload.notified_at
    notification.apply_verified_receipt!(receipt: receipt)

    assert_equal notified_at, notification.reload.notified_at

    late = receipt.with(generation: receipt.generation + 1)
    assert_raises(ProcessorErasureNotificationReceiptError) do
      notification.apply_verified_receipt!(receipt: late)
    end
  end

  test "retry exhaustion becomes immutable permanent failure" do
    notification = build_notification
    adapter = FakeAdapter.new(outcome: :retryable, max_attempts: 2)

    ProcessorErasureNotificationAdapterRegistry.stub(:fetch, adapter) do
      ProcessorErasureNotificationJob.perform_now(surface: "app", public_id: notification.public_id)
      notification.update!(next_retry_at: notification.class.database_now - 1.second)
      queued_after_first_attempt = enqueued_jobs.count
      ProcessorErasureNotificationJob.perform_now(surface: "app", public_id: notification.public_id)

      assert_equal queued_after_first_attempt, enqueued_jobs.count
    end

    notification.reload

    assert_equal "PERMANENT_FAILURE", notification.status_name
    assert_predicate notification.permanent_failed_at, :present?
    attempt_attributes = notification.attempts.order(:attempt_number).pluck(:outcome, :error_code)

    assert_equal [["RETRYABLE_FAILURE", "temporary"], ["PERMANENT_FAILURE", "temporary"]], attempt_attributes

    assert_no_difference -> { notification.attempts.count } do
      ProcessorErasureNotificationJob.perform_now(surface: "app", public_id: notification.public_id)
    end
    assert_equal "PERMANENT_FAILURE", notification.reload.status_name
  end

  test "provider permanent failure becomes immutable permanent failure" do
    notification = build_notification
    adapter = FakeAdapter.new(outcome: :permanent)

    ProcessorErasureNotificationAdapterRegistry.stub(:fetch, adapter) do
      ProcessorErasureNotificationJob.perform_now(surface: "app", public_id: notification.public_id)
    end

    notification.reload

    assert_equal "PERMANENT_FAILURE", notification.status_name
    assert_predicate notification.permanent_failed_at, :present?
    assert_equal "PERMANENT_FAILURE", notification.attempts.first.outcome

    assert_no_difference -> { notification.attempts.count } do
      ProcessorErasureNotificationJob.perform_now(surface: "app", public_id: notification.public_id)
    end
    assert_equal "PERMANENT_FAILURE", notification.reload.status_name
  end

  test "retries reuse the delivery idempotency key within one generation" do
    notification = build_notification
    policy = ProcessorErasureRetryPolicy.new(max_attempts: 3, retry_delay_seconds: 0)
    first_attempt = notification.begin_attempt!(retry_policy: policy)

    notification.mark_retryable_failure!(
      attempt: first_attempt,
      policy: policy,
      code: "temporary",
      message: "try again",
    )
    notification.update!(next_retry_at: notification.class.database_now - 1.second)

    second_attempt = notification.begin_attempt!(retry_policy: policy)

    assert_equal first_attempt.idempotency_key_digest, second_attempt.idempotency_key_digest
    assert_equal notification.delivery_idempotency_key_digest, second_attempt.idempotency_key_digest
  end

  test "manual recovery creates a new generation without mutating the failed generation" do
    notification = build_notification
    ProcessorErasureNotificationAdapterRegistry.stub(:fetch, nil) do
      ProcessorErasureNotificationJob.perform_now(surface: "app", public_id: notification.public_id)
    end

    old_attempt = notification.attempts.first
    operator = Operator.new
    assert_difference(
      -> { ClientOccurrence.where(event_type: "processor_erasure.manual_recovery_requested").count },
      1,
    ) do
      ProcessorErasureNotificationRecoveryOperation.call(notification: notification, authorized_by: operator)
    end

    notification.reload
    occurrence = ClientOccurrence.where(event_type: "processor_erasure.manual_recovery_requested").order(:id).last

    assert_equal 2, notification.delivery_generation
    assert_equal "PENDING", notification.status_name
    assert_equal 0, notification.retry_count
    assert_not_equal old_attempt.idempotency_key_digest, notification.delivery_idempotency_key_digest
    assert_equal "PERMANENT_FAILURE", old_attempt.reload.outcome
    assert_equal 1, old_attempt.delivery_generation
    assert_equal "authorized_manual_recovery", occurrence.context.fetch("reason_code")
    assert_equal 1, occurrence.context.fetch("delivery_generation")
  end

  test "manual recovery rejects an unauthorized actor" do
    notification = build_notification
    notification.update!(
      status_id: notification.class.status_id_for("PERMANENT_FAILURE"),
      permanent_failed_at: notification.class.database_now,
    )

    assert_raises(ProcessorErasureNotificationRecoveryOperation::Unauthorized) do
      ProcessorErasureNotificationRecoveryOperation.call(notification: notification, authorized_by: Object.new)
    end
  end

  test "manual recovery rejects an administratively locked operator" do
    notification = build_notification
    notification.update!(
      status_id: notification.class.status_id_for("PERMANENT_FAILURE"),
      permanent_failed_at: notification.class.database_now,
    )
    operator = Operator.new(access_state: AdministrativeAccessLockable::ACCESS_STATE_ADMIN_LOCKED)

    assert_raises(ProcessorErasureNotificationRecoveryOperation::Unauthorized) do
      ProcessorErasureNotificationRecoveryOperation.call(notification: notification, authorized_by: operator)
    end
  end

  test "manual recovery cannot reopen a notified notification" do
    notification = build_notification
    notification.update!(
      status_id: notification.class.status_id_for("NOTIFIED"),
      notified_at: notification.class.database_now,
    )

    assert_raises(ProcessorErasureNotificationReceiptError) do
      ProcessorErasureNotificationRecoveryOperation.call(
        notification: notification,
        authorized_by: Operator.new,
      )
    end

    assert_equal "NOTIFIED", notification.reload.status_name
  end

  test "database contract rejects zero generation and zero attempt number" do
    notification = build_notification

    assert_raises(ActiveRecord::StatementInvalid) do
      notification.class.transaction(requires_new: true) do
        notification.update_columns(delivery_generation: 0)
      end
    end

    attempt = notification.begin_attempt!(
      retry_policy: ProcessorErasureRetryPolicy.new(
        max_attempts: 1,
        retry_delay_seconds: 0,
      ),
    )
    assert_raises(ActiveRecord::StatementInvalid) do
      attempt.update_columns(attempt_number: 0)
    end
  end

  test "retention deletion removes the subordinate attempt ledger with the notification" do
    notification = build_notification
    notification.begin_attempt!(
      retry_policy: ProcessorErasureRetryPolicy.new(
        max_attempts: 1,
        retry_delay_seconds: 0,
      ),
    )

    assert_difference -> { ClientProcessorErasureNotificationAttempt.count }, -1 do
      notification.delete
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
