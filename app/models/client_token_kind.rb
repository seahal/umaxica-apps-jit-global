# frozen_string_literal: true
# typed: false
# == Schema Information
#
# Table name: client_token_kinds
# Database name: app_ticket
#
#  id :bigint           not null, primary key
#

class ClientTokenKind < AppTicketRecord
  include ReferenceRecord

  self.primary_key = :id
  self.record_timestamps = false

  BROWSER_WEB = 11
  CLIENT_IOS = 12
  CLIENT_ANDROID = 13

  DEFAULTS = [BROWSER_WEB, CLIENT_IOS, CLIENT_ANDROID].freeze

  has_many :client_tokens, dependent: :restrict_with_error
end
