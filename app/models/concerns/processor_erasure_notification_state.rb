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

  included do
    include PublicId
    include Retainable

    before_validation :assign_processor_notification_defaults, on: :create

    validates :processor_key, inclusion: { in: PROCESSOR_KEYS }
    validates :status_id, inclusion: { in: ->(record) { record.class::STATUS_IDS } }
    validates :requested_at, presence: true
    validates :retry_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    scope :pending_for_processing,
          lambda { |now = Time.current|
            where(status_id: status_id_for("PENDING"))
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

  def pending?
    status_id == self.class.status_id_for("PENDING")
  end

  def terminal?
    [self.class.status_id_for("NOTIFIED"), self.class.status_id_for("SKIPPED")].include?(status_id)
  end

  def mark_notified!(now: Time.current)
    # The job-level terminal check is only advisory; re-check under the row lock so a
    # concurrent retry cannot overwrite a terminal notification.
    with_lock do
      return self if terminal?

      update!(
        status_id: self.class.status_id_for("NOTIFIED"), notified_at: now, last_error_code: "",
        last_error_message: "",
      )
    end
  end

  def mark_failed!(code:, message:, now: Time.current)
    with_lock do
      return self if terminal?

      update!(
        status_id: self.class.status_id_for("FAILED"),
        failed_at: now,
        retry_count: retry_count + 1,
        next_retry_at: now + 15.minutes,
        last_error_code: code.to_s,
        last_error_message: message.to_s.truncate(255),
      )
    end
  end

  private

  def assign_processor_notification_defaults
    self.class::STATUS_MODEL.ensure_defaults!
    self.status_id ||= self.class.status_id_for("PENDING")
    self.requested_at ||= Time.current
  end
end
