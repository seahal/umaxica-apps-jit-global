# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_token_dbsc_statuses
# Database name: op_base_com
#
#  id :bigint           not null, primary key
#
class VisitorTokenDbscStatus < OpBaseComRecord
  include ReferenceRecord

  NOTHING = 0
  ACTIVE = 1
  PENDING = 2
  FAILED = 3
  REVOKE = 4
  DEFAULTS = [NOTHING, ACTIVE, PENDING, FAILED, REVOKE].freeze

  has_many :visitor_tokens, dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
