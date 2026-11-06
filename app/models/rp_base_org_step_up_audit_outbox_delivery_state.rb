# frozen_string_literal: true

class RpBaseOrgStepUpAuditOutboxDeliveryState < RpBaseOrgRecord
  self.table_name = "rp_step_up_audit_outbox_delivery_states"

  include ReferenceRecord

  PENDING = 10
  DELIVERED = 20
  DEFAULTS = [PENDING, DELIVERED].freeze

  has_many :outboxes,
           class_name: "RpBaseOrgStepUpAuditOutbox",
           foreign_key: :delivery_state_id,
           inverse_of: :delivery_state,
           dependent: :restrict_with_error
end
