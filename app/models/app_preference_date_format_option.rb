# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_preference_date_format_options
# Database name: app_setting
#
#  id :bigint           not null, primary key
#
class AppPreferenceDateFormatOption < AppSettingRecord
  include ReferenceRecord

  NOTHING = 0
  ISO = 1
  UK = 2
  US = 3

  DEFAULTS = [NOTHING, ISO, UK, US].freeze

  has_many :app_preference_date_formats,
           class_name: "AppPreferenceDateFormat",
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end

  def name
    case id
    when 1 then "iso"
    when 2 then "uk"
    when 3 then "us"
    end
  end
end
