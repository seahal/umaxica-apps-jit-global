# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_token_statuses
# Database name: op_base_com
#
#  id :bigint           not null, primary key
#
class VisitorTokenStatus < OpBaseComRecord
  include ReferenceRecord

  NOTHING = 0
  ACTIVE = 1
  EXPIRED = 102
  RESTRICTED = 103
  REVOKED = 104
  DEFAULTS = [NOTHING, ACTIVE, EXPIRED, RESTRICTED, REVOKED].freeze

  has_many :visitor_tokens, dependent: :restrict_with_error
end
