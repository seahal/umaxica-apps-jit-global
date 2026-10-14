# frozen_string_literal: true
# typed: false
# == Schema Information
#
# Table name: org_preference_region_options
# Database name: org_setting
#
#  id :bigint           not null, primary key
#


class OrgPreferenceRegionOption < OrgSettingRecord
  # Fixed IDs - do not modify these values
  US = 1
  JP = 2

  DEFAULTS = [US, JP].freeze

  has_many :org_preference_regions,
           class_name: "OrgPreferenceRegion",
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
