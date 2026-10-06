# typed: false
# frozen_string_literal: true

class VisitorSignInFlowState < ComTicketRecord
  include ReferenceRecord

  PRIMARY_PENDING = 10
  MFA_PENDING = 20
  SESSION_LIMIT_PENDING = 30
  GUARDRAIL_PENDING = 40
  SESSION_ISSUANCE_PENDING = 50
  CHECKPOINT_PENDING = 60
  SELECTOR_PENDING = 65
  DASHBOARD_PENDING = 70
  RETURN_PENDING = 80
  COMPLETED = 100
  FAILED = 900
  EXPIRED = 910
  CANCELLED = 920
  HALTED = 930
  DEFAULTS = [
    PRIMARY_PENDING,
    MFA_PENDING,
    SESSION_LIMIT_PENDING,
    GUARDRAIL_PENDING,
    SESSION_ISSUANCE_PENDING,
    CHECKPOINT_PENDING,
    SELECTOR_PENDING,
    DASHBOARD_PENDING,
    RETURN_PENDING,
    COMPLETED,
    FAILED,
    EXPIRED,
    CANCELLED,
    HALTED,
  ].freeze

  has_many :visitor_sign_in_flows,
           foreign_key: :state_id,
           dependent: :restrict_with_error,
           inverse_of: :state
end
