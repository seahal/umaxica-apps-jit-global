# typed: false
# frozen_string_literal: true

class ProcessorErasureNotificationJob < ApplicationJob
  queue_as :retention

  # A missing adapter is a permanent local configuration failure, not evidence that a processor
  # accepted the request. It therefore records a terminal failure which can only be reopened by
  # the authorized manual-recovery operation after the adapter contract is available.
  UNCONFIGURED_RETRY_POLICY = ProcessorErasureRetryPolicy.new(max_attempts: 1, retry_delay_seconds: 0)

  def perform(surface:, public_id:)
    notification = notification_class_for(surface).find_by!(public_id: public_id)
    adapter = ProcessorErasureNotificationAdapterRegistry.fetch(notification.processor_key)
    retry_policy = adapter ? adapter.retry_policy : UNCONFIGURED_RETRY_POLICY
    attempt = notification.begin_attempt!(retry_policy: retry_policy)
    return unless attempt

    subject = subject_for(notification)
    WithdrawalOccurrenceRecording.record!(
      subject: subject,
      event_type: "processor_erasure.notification_requested",
      context: occurrence_context(notification, attempt: attempt),
    )

    if adapter.nil?
      finalize_permanent_failure(
        subject: subject,
        notification: notification,
        attempt: attempt,
        code: "processor_unavailable",
        message: "Processor integration is not configured",
      )
      return
    end

    result = adapter.dispatch(notification: notification, attempt: attempt)
    unless result.is_a?(ProcessorErasureDispatchResult)
      raise ProcessorErasureNotificationReceiptError, "processor adapter returned an invalid result"
    end

    process_result(
      surface: surface,
      result: result,
      subject: subject,
      notification: notification,
      attempt: attempt,
      retry_policy: retry_policy,
    )
  end

  private

  def process_result(surface:, result:, subject:, notification:, attempt:, retry_policy:)
    case result.outcome
    when :received
      notification.apply_verified_receipt!(receipt: result.receipt)
      record_occurrence(subject, notification, attempt, "processor_erasure.notified")
    when :accepted_pending
      notification.mark_accepted_pending!(attempt: attempt)
      schedule_retry(surface, notification)
    when :retryable_failure
      notification.mark_retryable_failure!(
        attempt: attempt,
        policy: retry_policy,
        code: result.error_code,
        message: result.error_message,
      )
      record_failure(subject, notification, attempt, result.error_code)
      schedule_retry(surface, notification)
    when :permanent_failure
      finalize_permanent_failure(
        subject: subject,
        notification: notification,
        attempt: attempt,
        code: result.error_code,
        message: result.error_message,
      )
    else
      raise ProcessorErasureNotificationReceiptError, "unsupported processor dispatch outcome"
    end
  end

  def finalize_permanent_failure(subject:, notification:, attempt:, code:, message:)
    notification.mark_permanent_failure!(attempt: attempt, code: code, message: message)
    record_failure(subject, notification, attempt, code)
  end

  def record_occurrence(subject, notification, attempt, event_type)
    WithdrawalOccurrenceRecording.record!(
      subject: subject,
      event_type: event_type,
      context: occurrence_context(notification, attempt: attempt),
    )
  end

  def schedule_retry(surface, notification)
    return unless (notification.pending? || notification.retryable_failure?) && notification.next_retry_at.present?

    self.class.set(wait_until: notification.next_retry_at).perform_later(
      surface: surface.to_s,
      public_id: notification.public_id,
    )
  end

  def notification_class_for(surface)
    case surface.to_s
    when "app" then ClientProcessorErasureNotification
    when "com" then VisitorProcessorErasureNotification
    else
      raise ArgumentError, "unsupported processor erasure surface: #{surface.inspect}"
    end
  end

  def subject_for(notification)
    case notification
    when ClientProcessorErasureNotification then notification.client_privacy_request.client
    when VisitorProcessorErasureNotification then notification.visitor_privacy_request.visitor
    else
      raise ArgumentError, "unsupported processor notification: #{notification.class.name}"
    end
  end

  def privacy_request_for(notification)
    case notification
    when ClientProcessorErasureNotification then notification.client_privacy_request
    when VisitorProcessorErasureNotification then notification.visitor_privacy_request
    else
      raise ArgumentError, "unsupported processor notification: #{notification.class.name}"
    end
  end

  def record_failure(subject, notification, attempt, reason_code)
    WithdrawalOccurrenceRecording.record!(
      subject: subject,
      event_type: "processor_erasure.failed",
      context: occurrence_context(notification, attempt: attempt).merge(reason_code: reason_code.to_s),
    )
  end

  def occurrence_context(notification, attempt:)
    {
      processor_key: notification.processor_key,
      processor_notification_public_id: notification.public_id,
      privacy_request_public_id: privacy_request_for(notification).public_id,
      delivery_generation: notification.delivery_generation,
      delivery_attempt_number: attempt.attempt_number,
    }
  end
end
