# frozen_string_literal: true
# typed: false

# == Schema Information
#
# Table name: client_token_kinds
# Database name: op_base_app
#
#  id :bigint           not null, primary key
#

class ClientTokenKind < OpBaseAppRecord
  include ReferenceRecord

  self.primary_key = :id
  self.record_timestamps = false

  BROWSER_WEB = 11
  CLIENT_IOS = 12
  CLIENT_ANDROID = 13

  DEFAULTS = [BROWSER_WEB, CLIENT_IOS, CLIENT_ANDROID].freeze

  # The token table retains its user_* keys across the principal rename.
  has_many :client_tokens,
           foreign_key: :user_token_kind_id,
           dependent: :restrict_with_error,
           inverse_of: :user_token_kind
end
