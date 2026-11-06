# frozen_string_literal: true

class RpBaseOrgStepUpStateTransition < RpBaseOrgRecord
  self.table_name = "rp_step_up_state_transitions"

  belongs_to :owner, class_name: "RpBaseOrgStepUpState", inverse_of: :transitions
  belongs_to :from_state, class_name: "RpBaseOrgStepUpStateStatus", inverse_of: :from_transitions
  belongs_to :to_state, class_name: "RpBaseOrgStepUpStateStatus", inverse_of: :to_transitions

  validates :occurred_at, presence: true
  validates :reason_code, inclusion: { in: StepUpAuditCodesRegistry::REASON_CODES }
  validates :reason_code, length: { maximum: 64 }
end
