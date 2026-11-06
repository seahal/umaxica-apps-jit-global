# frozen_string_literal: true

class OperatorSensitiveAdmissionAuditAttempt < OpBaseOrgRecord
  attr_readonly :outbox_id, :attempt_number, :attempted_at, :outcome, :failure_code
  belongs_to :outbox, class_name: "OperatorSensitiveAdmissionAuditOutbox", inverse_of: :attempts
  validates :attempted_at, presence: true
  validates :attempt_number, numericality: { only_integer: true, greater_than: 0 }
  validates :outcome, inclusion: { in: %w(delivered failed) }
  validates :failure_code, inclusion: { in: StepUpAuditCodesRegistry::DELIVERY_FAILURE_CODES }
  validates :outcome, length: { maximum: 16 }
  validates :failure_code, length: { maximum: 64 }
end
