# typed: false
# frozen_string_literal: true

class VisitorProcessorErasureNotification < ComPrincipalRecord
  include ProcessorErasureNotificationState

  STATUS_MODEL = VisitorProcessorErasureNotificationStatus
  STATUSES = {
    "PENDING" => STATUS_MODEL::PENDING,
    "NOTIFIED" => STATUS_MODEL::NOTIFIED,
    "RETRYABLE_FAILURE" => STATUS_MODEL::RETRYABLE_FAILURE,
    "SKIPPED" => STATUS_MODEL::SKIPPED,
    "PERMANENT_FAILURE" => STATUS_MODEL::PERMANENT_FAILURE,
  }.freeze
  STATUS_NAMES = STATUSES.invert.freeze
  STATUS_IDS = STATUSES.values.freeze

  belongs_to :visitor_privacy_request, inverse_of: :visitor_processor_erasure_notifications
  belongs_to :status, class_name: "VisitorProcessorErasureNotificationStatus"
  has_many :attempts,
           class_name: "VisitorProcessorErasureNotificationAttempt",
           inverse_of: :notification,
           dependent: :delete_all
end
