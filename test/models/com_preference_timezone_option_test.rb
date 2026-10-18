# frozen_string_literal: true
# typed: false

# == Schema Information
#
# Table name: com_preference_timezone_options
# Database name: com_setting
#
#  id :bigint           not null, primary key
#

require "test_helper"

class ComPreferenceTimezoneOptionTest < ActiveSupport::TestCase
  setup do
    ComPreferenceStatus.find_or_create_by!(id: ComPreferenceStatus::NOTHING)
  end

  test "ensure_defaults! creates default timezone options" do
    ComPreferenceTimezoneOption.where(id: ComPreferenceTimezoneOption::DEFAULTS).delete_all

    assert_empty ComPreferenceTimezoneOption.where(id: ComPreferenceTimezoneOption::DEFAULTS)

    ComPreferenceTimezoneOption.ensure_defaults!

    assert_equal ComPreferenceTimezoneOption::DEFAULTS.sort, ComPreferenceTimezoneOption.where(id: ComPreferenceTimezoneOption::DEFAULTS).pluck(:id).sort
  end

  test "can be created" do
    option = ComPreferenceTimezoneOption.create!(id: 99)

    assert_not_nil option.id
  end

  test "has many com_preference_timezones" do
    option = ComPreferenceTimezoneOption.create!(id: 99)
    preference = ComPreference.create!
    timezone = ComPreferenceTimezone.create!(preference: preference, option: option)

    assert_includes option.com_preference_timezones, timezone
  end

  test "restricts deletion when associated records exist" do
    option = ComPreferenceTimezoneOption.create!(id: 99)
    preference = ComPreference.create!
    ComPreferenceTimezone.create!(preference: preference, option: option)

    assert_raises(ActiveRecord::RecordNotDestroyed) do
      option.destroy!
    end
  end

  test "name returns nil for unknown id" do
    option = ComPreferenceTimezoneOption.new(id: 99)

    assert_nil option.name
  end

  test "name returns Etc/UTC for ETC_UTC id" do
    option = ComPreferenceTimezoneOption.new(id: ComPreferenceTimezoneOption::ETC_UTC)

    assert_equal "Etc/UTC", option.name
  end

  test "name returns Asia/Tokyo for ASIA_TOKYO id" do
    option = ComPreferenceTimezoneOption.new(id: ComPreferenceTimezoneOption::ASIA_TOKYO)

    assert_equal "Asia/Tokyo", option.name
  end

  test "name returns United States timezones" do
    expectations = {
      ComPreferenceTimezoneOption::AMERICA_NEW_YORK => "America/New_York",
      ComPreferenceTimezoneOption::AMERICA_CHICAGO => "America/Chicago",
      ComPreferenceTimezoneOption::AMERICA_DENVER => "America/Denver",
      ComPreferenceTimezoneOption::AMERICA_LOS_ANGELES => "America/Los_Angeles",
      ComPreferenceTimezoneOption::AMERICA_ANCHORAGE => "America/Anchorage",
      ComPreferenceTimezoneOption::PACIFIC_HONOLULU => "Pacific/Honolulu",
    }

    expectations.each do |id, timezone|
      assert_equal timezone, ComPreferenceTimezoneOption.new(id: id).name
    end
  end
end
