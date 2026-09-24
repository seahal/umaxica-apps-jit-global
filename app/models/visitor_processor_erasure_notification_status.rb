# typed: false
# frozen_string_literal: true

class VisitorProcessorErasureNotificationStatus < ComPrincipalRecord
  include ReferenceRecord

  PENDING = 10
  NOTIFIED = 20
  RETRYABLE_FAILURE = 30
  SKIPPED = 40
  PERMANENT_FAILURE = 50
  DEFAULTS = [PENDING, NOTIFIED, RETRYABLE_FAILURE, SKIPPED, PERMANENT_FAILURE].freeze
end
