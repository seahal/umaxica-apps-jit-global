# frozen_string_literal: true

class OperatorStepUpContextState < OpBaseOrgRecord
  include ReferenceRecord

  PENDING = 10
  COMMITTED = 20
  CANCELLED = 90
  EXPIRED = 91
  FAILED = 92
  DEFAULTS = [PENDING, COMMITTED, CANCELLED, EXPIRED, FAILED].freeze

  has_many :contexts,
           class_name: "OperatorStepUpContext",
           foreign_key: :state_id,
           inverse_of: :state,
           dependent: :restrict_with_error
  has_many :from_transitions,
           class_name: "OperatorStepUpContextTransition",
           foreign_key: :from_state_id,
           inverse_of: :from_state,
           dependent: :restrict_with_error
  has_many :to_transitions,
           class_name: "OperatorStepUpContextTransition",
           foreign_key: :to_state_id,
           inverse_of: :to_state,
           dependent: :restrict_with_error
end
