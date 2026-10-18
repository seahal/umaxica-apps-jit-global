# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_token_statuses
# Database name: op_base_app
#
#  id :bigint           not null, primary key
#

class ClientTokenStatus < OpBaseAppRecord
  include ReferenceRecord

  NOTHING = 0
  ACTIVE = 1
  EXPIRED = 102
  RESTRICTED = 103
  REVOKED = 104
  DEFAULTS = [NOTHING, ACTIVE, EXPIRED, RESTRICTED, REVOKED].freeze

  has_many :client_tokens,
           foreign_key: :user_token_status_id,
           dependent: :restrict_with_error,
           inverse_of: :user_token_status
end
