# typed: false
# frozen_string_literal: true

class OperatorSessionLimitResolutionState < OrgTicketRecord
  include ReferenceRecord

  PENDING = 10
  SESSION_SELECTED = 20
  RESOLVED = 100
  EXPIRED = 910
  CANCELLED = 920
  DEFAULTS = [PENDING, SESSION_SELECTED, RESOLVED, EXPIRED, CANCELLED].freeze

  has_many :operator_session_limit_resolution_transactions, foreign_key: :state_id,
                                                            dependent: :restrict_with_error, inverse_of: :state
end
