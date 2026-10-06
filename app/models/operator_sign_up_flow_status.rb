# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_sign_up_flow_statuses
# Database name: org_ticket
#
#  id :bigint           not null, primary key
#
class OperatorSignUpFlowStatus < OrgTicketRecord
  include ReferenceRecord

  STARTED = 10
  CONTACT_PENDING = 20
  CREDENTIAL_PENDING = 30
  CHECKPOINT_PENDING = 40
  COMPLETED = 100
  FAILED = 900
  EXPIRED = 910
  CANCELLED = 920
  HALTED = 930
  DEFAULTS = [
    STARTED, CONTACT_PENDING, CREDENTIAL_PENDING, CHECKPOINT_PENDING, COMPLETED,
    FAILED, EXPIRED, CANCELLED, HALTED,
  ].freeze

  has_many :operator_sign_up_flows,
           foreign_key: :status_id,
           dependent: :restrict_with_error,
           inverse_of: :status
end
