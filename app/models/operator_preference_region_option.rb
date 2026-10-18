# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_preference_region_options
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
class OperatorPreferenceRegionOption < OrgPrincipalRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  NOTHING = 0
  US = 1
  JP = 2

  DEFAULTS = [NOTHING, US, JP].freeze

  has_many :staff_preference_regions,
           class_name: "OperatorPreferenceRegion",
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end

  def name
    case id
    when US then "US"
    when JP then "JP"
    end
  end

  self.primary_key = :id
end
