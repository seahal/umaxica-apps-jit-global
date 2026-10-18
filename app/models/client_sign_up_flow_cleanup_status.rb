# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_sign_up_flow_cleanup_statuses
# Database name: op_base_app
#
#  id :bigint           not null, primary key
#
class ClientSignUpFlowCleanupStatus < OpBaseAppRecord
  include ReferenceRecord

  NOTHING = 0
  IDLE = 10
  PENDING = 20
  COMPLETED = 30
  FAILED = 40
  DEFAULTS = [NOTHING, IDLE, PENDING, COMPLETED, FAILED].freeze

  ACTIVE = [PENDING, FAILED].freeze

  has_many :client_sign_up_flows,
           foreign_key: :cleanup_status_id,
           dependent: :restrict_with_error,
           inverse_of: :cleanup_status
end
