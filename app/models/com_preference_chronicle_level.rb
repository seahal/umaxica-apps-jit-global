# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_preference_chronicle_levels
# Database name: chronicle
#
#  id :bigint           not null, primary key
#
class ComPreferenceChronicleLevel < ChronicleRecord
  include ReferenceRecord

  # Fixed IDs - unified across App/Org/Com (aligned to App pattern)
  NOTHING = 0
  INFO = 1

  DEFAULTS = [NOTHING, INFO].freeze

  has_many :com_preference_chronicles, dependent: :restrict_with_error, inverse_of: :com_preference_chronicle_level

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
