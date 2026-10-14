# frozen_string_literal: true
# typed: false
# == Schema Information
#
# Table name: app_preference_timezone_options
# Database name: app_setting
#
#  id :bigint           not null, primary key
#


require "test_helper"

class AppPreferenceTimezoneOptionTest < ActiveSupport::TestCase
  setup do
    AppPreferenceStatus.ensure_defaults!
  end

  test "can be created" do
    option = AppPreferenceTimezoneOption.create!(id: 99)

    assert_not_nil option.id
  end

  test "has many app_preference_timezones" do
    option = AppPreferenceTimezoneOption.create!(id: 99)
    preference = AppPreference.create!
    timezone = AppPreferenceTimezone.create!(preference: preference, option: option)

    assert_includes option.app_preference_timezones, timezone
  end

  test "restricts deletion when associated records exist" do
    option = AppPreferenceTimezoneOption.create!(id: 99)
    preference = AppPreference.create!
    AppPreferenceTimezone.create!(preference: preference, option: option)

    assert_raises(ActiveRecord::RecordNotDestroyed) do
      option.destroy!
    end
  end

  test "name returns nil for unknown id" do
    option = AppPreferenceTimezoneOption.new(id: 99)

    assert_nil option.name
  end

  test "name returns Etc/UTC for ETC_UTC id" do
    option = AppPreferenceTimezoneOption.new(id: AppPreferenceTimezoneOption::ETC_UTC)

    assert_equal "Etc/UTC", option.name
  end

  test "name returns Asia/Tokyo for ASIA_TOKYO id" do
    option = AppPreferenceTimezoneOption.new(id: AppPreferenceTimezoneOption::ASIA_TOKYO)

    assert_equal "Asia/Tokyo", option.name
  end

  test "name returns United States timezones" do
    expectations = {
      AppPreferenceTimezoneOption::AMERICA_NEW_YORK => "America/New_York",
      AppPreferenceTimezoneOption::AMERICA_CHICAGO => "America/Chicago",
      AppPreferenceTimezoneOption::AMERICA_DENVER => "America/Denver",
      AppPreferenceTimezoneOption::AMERICA_LOS_ANGELES => "America/Los_Angeles",
      AppPreferenceTimezoneOption::AMERICA_ANCHORAGE => "America/Anchorage",
      AppPreferenceTimezoneOption::PACIFIC_HONOLULU => "Pacific/Honolulu",
    }

    expectations.each do |id, timezone|
      assert_equal timezone, AppPreferenceTimezoneOption.new(id: id).name
    end
  end

  test "name returns nil for NOTHING id" do
    option = AppPreferenceTimezoneOption.new(id: AppPreferenceTimezoneOption::NOTHING)

    assert_nil option.name
  end
end
