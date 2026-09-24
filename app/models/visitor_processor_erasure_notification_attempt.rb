# typed: false
# frozen_string_literal: true

class VisitorProcessorErasureNotificationAttempt < ComPrincipalRecord
  OUTCOMES = %w(IN_FLIGHT ACCEPTED_PENDING SUCCEEDED RETRYABLE_FAILURE PERMANENT_FAILURE).freeze

  belongs_to :notification,
             class_name: "VisitorProcessorErasureNotification",
             foreign_key: :visitor_processor_erasure_notification_id,
             inverse_of: :attempts

  validates :delivery_generation, numericality: { only_integer: true, greater_than: 0 }
  validates :attempt_number, numericality: { only_integer: true, greater_than: 0 }
  validates :processor_key, presence: true
  validates :idempotency_key_digest, presence: true
  validates :outcome, inclusion: { in: OUTCOMES }
  validates :started_at, presence: true
end
