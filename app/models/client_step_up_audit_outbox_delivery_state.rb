# frozen_string_literal: true

class ClientStepUpAuditOutboxDeliveryState < OpBaseAppRecord
  include ReferenceRecord

  PENDING = 10
  DELIVERED = 20
  DEFAULTS = [PENDING, DELIVERED].freeze

  has_many :outboxes,
           class_name: "ClientStepUpAuditOutbox",
           foreign_key: :delivery_state_id,
           inverse_of: :delivery_state,
           dependent: :restrict_with_error
end
