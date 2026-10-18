# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_token_kinds
# Database name: op_base_com
#
#  id :bigint           not null, primary key
#
class VisitorTokenKind < OpBaseComRecord
  include ReferenceRecord

  self.primary_key = :id
  self.record_timestamps = false

  BROWSER_WEB = 1
  CLIENT_IOS = 2
  CLIENT_ANDROID = 3

  DEFAULTS = [BROWSER_WEB, CLIENT_IOS, CLIENT_ANDROID].freeze

  has_many :visitor_tokens, dependent: :restrict_with_error
end
