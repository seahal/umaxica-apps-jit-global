# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_token_dbsc_statuses
# Database name: op_base_app
#
#  id :bigint           not null, primary key
#
class ClientTokenDbscStatus < OpBaseAppRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  NOTHING = 0
  ACTIVE = 1
  PENDING = 2
  FAILED = 3
  REVOKE = 4
  DEFAULTS = [NOTHING, ACTIVE, PENDING, FAILED, REVOKE].freeze

  has_many :client_tokens,
           foreign_key: :user_token_dbsc_status_id,
           dependent: :restrict_with_error,
           inverse_of: :user_token_dbsc_status

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
