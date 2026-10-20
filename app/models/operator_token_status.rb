# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_token_statuses
# Database name: op_base_org
#
#  id :bigint           not null, primary key
#

class OperatorTokenStatus < OpBaseOrgRecord
  include ReferenceRecord

  NOTHING = 0
  ACTIVE = 1
  EXPIRED = 102
  RESTRICTED = 103
  REVOKED = 104
  DEFAULTS = [NOTHING, ACTIVE, EXPIRED, RESTRICTED, REVOKED].freeze

  # The token table retains its staff_* keys across the principal rename.
  has_many :staff_tokens,
           class_name: "OperatorToken",
           foreign_key: :staff_token_status_id,
           dependent: :restrict_with_error,
           inverse_of: :staff_token_status
end
