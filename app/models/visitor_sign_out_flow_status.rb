# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_sign_out_flow_statuses
# Database name: com_ticket
#
#  id :bigint           not null, primary key
#
class VisitorSignOutFlowStatus < ComTicketRecord
  include ReferenceRecord

  NOTHING = 0
  REQUESTED = 10
  ACCESS_DISCARDED = 20
  LOGICALLY_REVOKED = 30
  AWAITING_EXPIRY = 40
  COMPLETED = 100
  FAILED = 900
  EXPIRED = 910
  CANCELLED = 920
  HALTED = 930
  DEFAULTS = [
    NOTHING,
    REQUESTED,
    ACCESS_DISCARDED,
    LOGICALLY_REVOKED,
    AWAITING_EXPIRY,
    COMPLETED,
    FAILED,
    EXPIRED,
    CANCELLED,
    HALTED,
  ].freeze

  has_many :visitor_sign_out_flows,
           foreign_key: :status_id,
           dependent: :restrict_with_error,
           inverse_of: :status
end
