# frozen_string_literal: true

class RpBaseOrgStepUpStateStatus < RpBaseOrgRecord
  self.table_name = "rp_step_up_state_statuses"

  include ReferenceRecord

  PENDING = 10
  DISPATCHING = 15
  INSTALLED = 20
  CANCELLED = 90
  EXPIRED = 91
  REFUSED = 92
  INDETERMINATE = 93
  DEFAULTS = [PENDING, DISPATCHING, INSTALLED, CANCELLED, EXPIRED, REFUSED, INDETERMINATE].freeze

  has_many :step_up_states,
           class_name: "RpBaseOrgStepUpState",
           foreign_key: :state_id,
           inverse_of: :state,
           dependent: :restrict_with_error
  has_many :from_transitions,
           class_name: "RpBaseOrgStepUpStateTransition",
           foreign_key: :from_state_id,
           inverse_of: :from_state,
           dependent: :restrict_with_error
  has_many :to_transitions,
           class_name: "RpBaseOrgStepUpStateTransition",
           foreign_key: :to_state_id,
           inverse_of: :to_state,
           dependent: :restrict_with_error
end
