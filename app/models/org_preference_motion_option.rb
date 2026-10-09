# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_preference_motion_options
# Database name: org_setting
#
#  id :bigint           not null, primary key
#
class OrgPreferenceMotionOption < OrgSettingRecord
  include ReferenceRecord

  NOTHING = 0
  STANDARD = 1
  REDUCED = 2

  DEFAULTS = [NOTHING, STANDARD, REDUCED].freeze

  has_many :org_preference_motions,
           class_name: "OrgPreferenceMotion",
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end

  def name
    case id
    when 1 then "standard"
    when 2 then "reduced"
    end
  end
end
