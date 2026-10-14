# frozen_string_literal: true
# typed: false
# == Schema Information
#
# Table name: operator_token_kinds
# Database name: org_ticket
#
#  id :bigint           not null, primary key
#

class OperatorTokenKind < OrgTicketRecord
  include ReferenceRecord

  self.record_timestamps = false

  BROWSER_WEB = 1
  CLIENT_IOS = 2
  CLIENT_ANDROID = 3

  DEFAULTS = [BROWSER_WEB, CLIENT_IOS, CLIENT_ANDROID].freeze

  has_many :staff_tokens, class_name: "OperatorToken", dependent: :restrict_with_error
end
