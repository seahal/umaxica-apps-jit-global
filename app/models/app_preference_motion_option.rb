# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_preference_motion_options
# Database name: app_setting
#
#  id :bigint           not null, primary key
#
class AppPreferenceMotionOption < AppSettingRecord
  include ReferenceRecord

  NOTHING = 0
  STANDARD = 1
  REDUCED = 2

  DEFAULTS = [NOTHING, STANDARD, REDUCED].freeze

  has_many :app_preference_motions,
           class_name: "AppPreferenceMotion",
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
