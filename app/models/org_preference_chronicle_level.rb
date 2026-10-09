# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_preference_chronicle_levels
# Database name: chronicle
#
#  id :bigint           not null, primary key
#
class OrgPreferenceChronicleLevel < ChronicleRecord
  include ReferenceRecord

  # Fixed IDs - unified across App/Org/Com (aligned to App pattern)
  NOTHING = 0
  INFO = 1

  DEFAULTS = [NOTHING, INFO].freeze

  has_many :org_preference_chronicles, dependent: :restrict_with_error, inverse_of: :org_preference_chronicle_level

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
