# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_preference_time_format_options
# Database name: app_setting
#
#  id :bigint           not null, primary key
#
class AppPreferenceTimeFormatOption < AppSettingRecord
  include ReferenceRecord

  NOTHING = 0
  HOUR_24 = 1
  HOUR_12 = 2

  DEFAULTS = [NOTHING, HOUR_24, HOUR_12].freeze

  has_many :app_preference_time_formats,
           class_name: "AppPreferenceTimeFormat",
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end

  def name
    case id
    when 1 then "24"
    when 2 then "12"
    end
  end
end
