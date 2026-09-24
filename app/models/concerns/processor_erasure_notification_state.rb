# typed: false
# frozen_string_literal: true

module ProcessorErasureNotificationState
  extend ActiveSupport::Concern

  PROCESSOR_KEYS = %w(
    email_delivery
    sms_delivery
    push_delivery
    analytics
    payment
    object_storage
    search_index
    log_pipeline
  ).freeze

  ATTEMPT_OUTCOMES = %w(IN_FLIGHT ACCEPTED_PENDING SUCCEEDED RETRYABLE_FAILURE PERMANENT_FAILURE).freeze
  DISPATCH_LEASE = 5.minutes

  included do
    include PublicId
    include Retainable

    before_validation :assign_processor_notification_defaults, on: :create

    validates :processor_key, inclusion: { in: PROCESSOR_KEYS }
    validates :status_id, inclusion: { in: ->(record) { record.class::STATUS_IDS } }
    validates :requested_at, presence: true
    validates :delivery_generation, numericality: { only_integer: true, greater_than: 0 }
    validates :delivery_idempotency_key_digest,
              format: { with: /\A[0-9a-f]{64}\z/ }
    validates :retry_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    scope :pending_for_processing,
          lambda { |now = nil|
            now ||= database_now
            where(status_id: [status_id_for("PENDING"), status_id_for("RETRYABLE_FAILURE")])
              .where(arel_table[:next_retry_at].eq(nil).or(arel_table[:next_retry_at].lteq(now)))
          }
  end

  class_methods do
    def status_id_for(status_name)
      self::STATUSES.fetch(status_name.to_s)
    end

    def status_name_for(status_id)
      self::STATUS_NAMES.fetch(status_id)
    end
  end

  public

  def status_name
    self.class.status_name_for(status_id)
  end

  def pending?
    status_id == self.class.status_id_for("PENDING")
  end

  def retryable_failure?
    status_id == self.class.status_id_for("RETRYABLE_FAILURE")
  end

  def permanent_failure?
    status_id == self.class.status_id_for("PERMANENT_FAILURE")
  end

  def terminal?
    %w(NOTIFIED SKIPPED PERMANENT_FAILURE).include?(status_name)
  end

  # Claims one attempt under the notification row lock. The external adapter is called after
  # this transaction, so a second worker sees the durable IN_FLIGHT claim instead of dispatching
  # the same logical attempt. A lease prevents a crashed worker from keeping a notification stuck
  # forever; the expired claim is recorded as a retryable or permanent outcome before another
  # generation attempt can be claimed.
  def begin_attempt!(retry_policy:, now: nil)
    validate_retry_policy!(retry_policy)

    with_lock do
      decision_time = now || self.class.database_now
      return if terminal?
      return if next_retry_at.present? && next_retry_at > decision_time

      active_attempt = attempts.lock.where(
        delivery_generation: delivery_generation,
        outcome: %w(IN_FLIGHT ACCEPTED_PENDING),
      ).order(:attempt_number).last

      if active_attempt
        return unless active_attempt.lease_expires_at.present? && active_attempt.lease_expires_at <= decision_time

        record_failure_locked!(
          attempt: active_attempt,
          policy: retry_policy,
          code: "dispatch_lease_expired",
          message: "The previous dispatch lease expired before completion",
          now: decision_time,
        )
        return if terminal? || (next_retry_at.present? && next_retry_at > decision_time)
      end

      attempt_number = retry_count + 1
      attempts.create!(
        delivery_generation: delivery_generation,
        attempt_number: attempt_number,
        processor_key: processor_key,
        idempotency_key_digest: delivery_idempotency_key_digest,
        outcome: "IN_FLIGHT",
        started_at: decision_time,
        lease_expires_at: decision_time + DISPATCH_LEASE,
      )
    end
  end

  def mark_accepted_pending!(attempt:, now: nil)
    with_lock do
      return self if terminal?

      decision_time = now || self.class.database_now
      attempt = lock_current_attempt!(attempt)
      return self if attempt.outcome == "ACCEPTED_PENDING"

      reject_attempt_transition!(attempt) unless attempt.outcome == "IN_FLIGHT"

      attempt.update!(
        outcome: "ACCEPTED_PENDING",
        finished_at: decision_time,
        lease_expires_at: decision_time + DISPATCH_LEASE,
      )
      update!(next_retry_at: decision_time + DISPATCH_LEASE)
    end
  end

  def mark_retryable_failure!(attempt:, policy:, code:, message:, now: nil)
    validate_retry_policy!(policy)
    normalized_code = ProcessorErasureDispatchResult.normalized_error_code(code)
    sanitized_message = ProcessorErasureDispatchResult.sanitized_error_message(message)

    with_lock do
      return self if terminal?

      decision_time = now || self.class.database_now
      record_failure_locked!(
        attempt: lock_current_attempt!(attempt),
        policy: policy,
        code: normalized_code,
        message: sanitized_message,
        now: decision_time,
      )
    end
  end

  def mark_permanent_failure!(attempt:, code:, message:, now: nil)
    normalized_code = ProcessorErasureDispatchResult.normalized_error_code(code)
    sanitized_message = ProcessorErasureDispatchResult.sanitized_error_message(message)

    with_lock do
      return self if terminal?

      decision_time = now || self.class.database_now
      attempt = lock_current_attempt!(attempt)
      return self if attempt.outcome == "PERMANENT_FAILURE"

      reject_attempt_transition!(attempt) unless attempt.outcome == "IN_FLIGHT"

      attempt.update!(
        outcome: "PERMANENT_FAILURE",
        finished_at: decision_time,
        lease_expires_at: nil,
        error_code: normalized_code,
        error_message: sanitized_message.truncate(255),
      )
      update_notification_failure!(
        status_name: "PERMANENT_FAILURE",
        attempt_number: attempt.attempt_number,
        code: normalized_code,
        message: sanitized_message,
        now: decision_time,
        next_retry_at: nil,
      )
    end
  end

  # Only an adapter that has already authenticated and normalized the provider response may call
  # this method. The receipt is checked again under the notification lock so a stale callback,
  # duplicate callback, or callback for another surface cannot create a success transition.
  def apply_verified_receipt!(receipt:)
    unless receipt.is_a?(ProcessorErasureVerifiedReceipt)
      raise ProcessorErasureNotificationReceiptError, "receipt was not verified by an adapter"
    end

    with_lock do
      ensure_receipt_matches_notification!(receipt)
      attempt = attempts.lock.where(
        delivery_generation: receipt.generation,
        idempotency_key_digest: receipt.idempotency_key_digest,
      ).order(attempt_number: :desc).first
      raise ProcessorErasureNotificationReceiptError, "receipt does not match an attempt" unless attempt

      receipt_digest = Digest::SHA256.hexdigest(receipt.receipt_id)
      if attempt.outcome == "SUCCEEDED"
        return self if attempt.receipt_reference_digest == receipt_digest

        raise ProcessorErasureNotificationReceiptError, "a different receipt replaced the attempt"
      end
      if terminal?
        raise ProcessorErasureNotificationReceiptError, "a terminal notification cannot be notified"
      end

      reject_attempt_transition!(attempt) unless %w(IN_FLIGHT ACCEPTED_PENDING).include?(attempt.outcome)

      decision_time = self.class.database_now
      attempt.update!(
        outcome: "SUCCEEDED",
        finished_at: decision_time,
        lease_expires_at: nil,
        receipt_reference_digest: receipt_digest,
      )
      update!(
        status_id: self.class.status_id_for("NOTIFIED"),
        notified_at: decision_time,
        failed_at: nil,
        permanent_failed_at: nil,
        retry_count: attempt.attempt_number,
        next_retry_at: nil,
        last_error_code: "",
        last_error_message: "",
      )
    end
  end

  def start_new_delivery_generation!
    with_lock do
      raise ProcessorErasureNotificationReceiptError, "only a permanent failure can recover" unless permanent_failure?

      update!(
        delivery_generation: delivery_generation + 1,
        delivery_idempotency_key_digest: new_delivery_idempotency_key_digest,
        status_id: self.class.status_id_for("PENDING"),
        retry_count: 0,
        notified_at: nil,
        failed_at: nil,
        permanent_failed_at: nil,
        next_retry_at: nil,
        last_error_code: "",
        last_error_message: "",
      )
    end
  end

  private

  def assign_processor_notification_defaults
    self.class::STATUS_MODEL.ensure_defaults!
    self.status_id ||= self.class.status_id_for("PENDING")
    self.requested_at ||= self.class.database_now
    self.delivery_generation ||= 1
    self.delivery_idempotency_key_digest ||= new_delivery_idempotency_key_digest
  end

  def validate_retry_policy!(policy)
    return if policy.is_a?(ProcessorErasureRetryPolicy)

    raise ArgumentError, "processor adapter must provide a finite retry policy"
  end

  def new_delivery_idempotency_key_digest
    Digest::SHA256.hexdigest(SecureRandom.random_bytes(32))
  end

  def lock_current_attempt!(attempt)
    candidate = attempts.lock.find_by(id: attempt.id)
    unless candidate && candidate.delivery_generation == delivery_generation &&
        candidate.processor_key == processor_key
      raise ProcessorErasureNotificationReceiptError, "attempt is not owned by this notification"
    end

    candidate
  end

  def reject_attempt_transition!(attempt)
    raise ProcessorErasureNotificationReceiptError,
          "attempt is already finalized with outcome #{attempt.outcome.inspect}"
  end

  def ensure_receipt_matches_notification!(receipt)
    return if receipt.processor_key == processor_key &&
      receipt.notification_public_id == public_id &&
      receipt.generation == delivery_generation

    raise ProcessorErasureNotificationReceiptError, "receipt is bound to another notification"
  end

  def record_failure_locked!(attempt:, policy:, code:, message:, now:)
    return self if attempt.outcome == "PERMANENT_FAILURE"

    normalized_code = ProcessorErasureDispatchResult.normalized_error_code(code)
    sanitized_message = ProcessorErasureDispatchResult.sanitized_error_message(message)

    reject_attempt_transition!(attempt) unless %w(IN_FLIGHT ACCEPTED_PENDING).include?(attempt.outcome)

    if policy.exhausted?(attempt.attempt_number)
      attempt_outcome = "PERMANENT_FAILURE"
      next_retry = nil
      status_name = "PERMANENT_FAILURE"
    else
      attempt_outcome = "RETRYABLE_FAILURE"
      next_retry = policy.retry_at(now: now, attempt_number: attempt.attempt_number)
      status_name = "RETRYABLE_FAILURE"
    end

    attempt.update!(
      outcome: attempt_outcome,
      finished_at: now,
      lease_expires_at: nil,
      error_code: normalized_code,
      error_message: sanitized_message.truncate(255),
    )
    update_notification_failure!(
      status_name: status_name,
      attempt_number: attempt.attempt_number,
      code: normalized_code,
      message: sanitized_message,
      now: now,
      next_retry_at: next_retry,
    )
  end

  def update_notification_failure!(status_name:, attempt_number:, code:, message:, now:, next_retry_at:)
    update!(
      status_id: self.class.status_id_for(status_name),
      failed_at: now,
      permanent_failed_at: (status_name == "PERMANENT_FAILURE") ? now : nil,
      retry_count: attempt_number,
      next_retry_at: next_retry_at,
      last_error_code: code.to_s,
      last_error_message: message.to_s.truncate(255),
    )
  end
end
