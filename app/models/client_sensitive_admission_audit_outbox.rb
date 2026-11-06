# frozen_string_literal: true

class ClientSensitiveAdmissionAuditOutbox < OpBaseAppRecord
  attr_readonly :event_uuid, :event_type, :realm, :client_id, :subject_ref, :context_ref, :reason_code, :payload,
                :occurred_at
  belongs_to :delivery_state, class_name: "ClientStepUpAuditOutboxDeliveryState"
  has_many :attempts, class_name: "ClientSensitiveAdmissionAuditAttempt", foreign_key: :outbox_id,
                      inverse_of: :outbox, dependent: :restrict_with_error
  validates :event_uuid, :client_id, :subject_ref, :context_ref, :payload, :occurred_at, presence: true
  validates :event_type, inclusion: { in: ["sensitive_admission.closed"] }
  validates :realm, inclusion: { in: ["APP"] }
  validates :reason_code, inclusion: { in: %w(completed expired user_cancelled) }
  validates :event_type, :reason_code, length: { maximum: 64 }
  validates :realm, length: { maximum: 3 }
  validates :client_id, length: { maximum: 64 }
  validates :subject_ref, length: { maximum: 255 }
  validates :context_ref, length: { maximum: 21 }
end
