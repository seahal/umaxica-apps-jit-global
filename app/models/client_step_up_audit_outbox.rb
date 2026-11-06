# frozen_string_literal: true

class ClientStepUpAuditOutbox < OpBaseAppRecord
  EVENT_TYPES = %w(
    step_up.requested
    step_up.committed
    step_up.installed
    step_up.cancelled
    step_up.expired
    step_up.failed
    step_up.refused
    step_up.indeterminate
    step_up.attempt_rejected
  ).freeze

  attr_readonly(
    :event_uuid, :event_type, :realm, :client_id, :subject_ref, :context_ref, :reason_code, :payload, :occurred_at,
  )

  belongs_to :delivery_state, class_name: "ClientStepUpAuditOutboxDeliveryState", inverse_of: :outboxes
  has_many :attempts,
           class_name: "ClientStepUpAuditOutboxAttempt",
           foreign_key: :outbox_id,
           inverse_of: :outbox,
           dependent: :restrict_with_error

  validates :event_uuid, :client_id, :subject_ref, :context_ref, :payload, :occurred_at, presence: true
  validates :event_type, inclusion: { in: EVENT_TYPES }
  validates :realm, inclusion: { in: ["APP"] }
  validates :reason_code, inclusion: { in: StepUpAuditCodesRegistry::REASON_CODES }
  validates :event_type, :reason_code, length: { maximum: 64 }
  validates :realm, length: { maximum: 3 }
  validates :subject_ref, length: { maximum: 255 }
  validates :context_ref, length: { maximum: 21 }
  validate do
    unless StepUpAuditCodesRegistry.valid_payload_code?(event_type: event_type, payload: payload)
      errors.add(:payload, "contains an unsupported step-up audit code")
    end
  end
end
