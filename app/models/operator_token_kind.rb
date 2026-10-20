# frozen_string_literal: true
# typed: false

# == Schema Information
#
# Table name: operator_token_kinds
# Database name: op_base_org
#
#  id :bigint           not null, primary key
#

class OperatorTokenKind < OpBaseOrgRecord
  include ReferenceRecord

  self.record_timestamps = false

  BROWSER_WEB = 1
  CLIENT_IOS = 2
  CLIENT_ANDROID = 3

  DEFAULTS = [BROWSER_WEB, CLIENT_IOS, CLIENT_ANDROID].freeze

  # The token table retains its staff_* keys across the principal rename.
  has_many :staff_tokens,
           class_name: "OperatorToken",
           foreign_key: :staff_token_kind_id,
           dependent: :restrict_with_error,
           inverse_of: :staff_token_kind
end
