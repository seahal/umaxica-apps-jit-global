# frozen_string_literal: true

class OperatorStepUpContextTransition < OpBaseOrgRecord
  belongs_to :owner, class_name: "OperatorStepUpContext", inverse_of: :transitions
  belongs_to :from_state, class_name: "OperatorStepUpContextState", inverse_of: :from_transitions
  belongs_to :to_state, class_name: "OperatorStepUpContextState", inverse_of: :to_transitions

  validates :occurred_at, presence: true
  validates :reason_code, inclusion: { in: StepUpAuditCodesRegistry::REASON_CODES }
  validates :reason_code, length: { maximum: 64 }
end
