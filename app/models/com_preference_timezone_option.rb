# typed: false
# == Schema Information
#
# Table name: com_preference_timezone_options
# Database name: com_setting
#
#  id :bigint           not null, primary key
#

# frozen_string_literal: true

class ComPreferenceTimezoneOption < ComSettingRecord
  self.primary_key = :id
  # Fixed IDs - do not modify these values
  ETC_UTC = 1
  ASIA_TOKYO = 2
  AMERICA_NEW_YORK = 3
  AMERICA_CHICAGO = 4
  AMERICA_DENVER = 5
  AMERICA_LOS_ANGELES = 6
  AMERICA_ANCHORAGE = 7
  PACIFIC_HONOLULU = 8

  DEFAULTS = [
    ETC_UTC,
    ASIA_TOKYO,
    AMERICA_NEW_YORK,
    AMERICA_CHICAGO,
    AMERICA_DENVER,
    AMERICA_LOS_ANGELES,
    AMERICA_ANCHORAGE,
    PACIFIC_HONOLULU,
  ].freeze

  has_many :com_preference_timezones,
           class_name: "ComPreferenceTimezone",
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end

  def name
    case id
    when ETC_UTC then "Etc/UTC"
    when ASIA_TOKYO then "Asia/Tokyo"
    when AMERICA_NEW_YORK then "America/New_York"
    when AMERICA_CHICAGO then "America/Chicago"
    when AMERICA_DENVER then "America/Denver"
    when AMERICA_LOS_ANGELES then "America/Los_Angeles"
    when AMERICA_ANCHORAGE then "America/Anchorage"
    when PACIFIC_HONOLULU then "Pacific/Honolulu"
    end
  end
end
