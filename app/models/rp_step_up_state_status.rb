# frozen_string_literal: true

class RpStepUpStateStatus < RpBaseAppRecord
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
           class_name: "RpStepUpState",
           foreign_key: :state_id,
           inverse_of: :state,
           dependent: :restrict_with_error
  has_many :from_transitions,
           class_name: "RpStepUpStateTransition",
           foreign_key: :from_state_id,
           inverse_of: :from_state,
           dependent: :restrict_with_error
  has_many :to_transitions,
           class_name: "RpStepUpStateTransition",
           foreign_key: :to_state_id,
           inverse_of: :to_state,
           dependent: :restrict_with_error
end
