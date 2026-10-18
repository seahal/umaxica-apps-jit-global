# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_chronicle_levels
# Database name: chronicle
#
#  id :bigint           not null, primary key
#
class ClientChronicleLevel < ChronicleRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  DEBUG = 1
  ERROR = 2
  INFO = 3
  NOTHING = 4
  WARN = 5

  DEFAULTS = [DEBUG, ERROR, INFO, NOTHING, WARN].freeze

  has_many :client_chronicles,
           foreign_key: :level_id,
           dependent: :restrict_with_error,
           inverse_of: :user_chronicle_level

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
