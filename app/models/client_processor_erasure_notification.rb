# typed: false
# frozen_string_literal: true

class ClientProcessorErasureNotification < AppPrincipalRecord
  include ProcessorErasureNotificationState

  STATUS_MODEL = ClientProcessorErasureNotificationStatus
  STATUSES = {
    "PENDING" => STATUS_MODEL::PENDING,
    "NOTIFIED" => STATUS_MODEL::NOTIFIED,
    "RETRYABLE_FAILURE" => STATUS_MODEL::RETRYABLE_FAILURE,
    "SKIPPED" => STATUS_MODEL::SKIPPED,
    "PERMANENT_FAILURE" => STATUS_MODEL::PERMANENT_FAILURE,
  }.freeze
  STATUS_NAMES = STATUSES.invert.freeze
  STATUS_IDS = STATUSES.values.freeze

  belongs_to :client_privacy_request, inverse_of: :client_processor_erasure_notifications
  belongs_to :status, class_name: "ClientProcessorErasureNotificationStatus"
  has_many :attempts,
           class_name: "ClientProcessorErasureNotificationAttempt",
           inverse_of: :notification,
           dependent: :delete_all
end
