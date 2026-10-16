# frozen_string_literal: true
# typed: false

# == Schema Information
#
# Table name: org_preference_timezone_options
# Database name: org_setting
#
#  id :bigint           not null, primary key
#

require "test_helper"

class OrgPreferenceTimezoneOptionTest < ActiveSupport::TestCase
  setup do
    OrgPreferenceStatus.find_or_create_by!(id: OrgPreferenceStatus::NOTHING)
  end

  test "ensure_defaults! creates default timezone options" do
    OrgPreferenceTimezoneOption.where(id: OrgPreferenceTimezoneOption::DEFAULTS).delete_all

    assert_empty OrgPreferenceTimezoneOption.where(id: OrgPreferenceTimezoneOption::DEFAULTS)

    OrgPreferenceTimezoneOption.ensure_defaults!

    assert_equal OrgPreferenceTimezoneOption::DEFAULTS.sort, OrgPreferenceTimezoneOption.where(id: OrgPreferenceTimezoneOption::DEFAULTS).pluck(:id).sort
  end

  test "can be created" do
    option = OrgPreferenceTimezoneOption.create!(id: 99)

    assert_not_nil option.id
  end

  test "has many org_preference_timezones" do
    option = OrgPreferenceTimezoneOption.create!(id: 99)
    preference = OrgPreference.create!
    timezone = OrgPreferenceTimezone.create!(preference: preference, option: option)

    assert_includes option.org_preference_timezones, timezone
  end

  test "restricts deletion when associated records exist" do
    option = OrgPreferenceTimezoneOption.create!(id: 99)
    preference = OrgPreference.create!
    OrgPreferenceTimezone.create!(preference: preference, option: option)

    assert_raises(ActiveRecord::RecordNotDestroyed) do
      option.destroy!
    end
  end

  test "name returns nil for unknown id" do
    option = OrgPreferenceTimezoneOption.new(id: 99)

    assert_nil option.name
  end

  test "name returns Etc/UTC for ETC_UTC id" do
    option = OrgPreferenceTimezoneOption.new(id: OrgPreferenceTimezoneOption::ETC_UTC)

    assert_equal "Etc/UTC", option.name
  end

  test "name returns Asia/Tokyo for ASIA_TOKYO id" do
    option = OrgPreferenceTimezoneOption.new(id: OrgPreferenceTimezoneOption::ASIA_TOKYO)

    assert_equal "Asia/Tokyo", option.name
  end

  test "name returns United States timezones" do
    expectations = {
      OrgPreferenceTimezoneOption::AMERICA_NEW_YORK => "America/New_York",
      OrgPreferenceTimezoneOption::AMERICA_CHICAGO => "America/Chicago",
      OrgPreferenceTimezoneOption::AMERICA_DENVER => "America/Denver",
      OrgPreferenceTimezoneOption::AMERICA_LOS_ANGELES => "America/Los_Angeles",
      OrgPreferenceTimezoneOption::AMERICA_ANCHORAGE => "America/Anchorage",
      OrgPreferenceTimezoneOption::PACIFIC_HONOLULU => "Pacific/Honolulu",
    }

    expectations.each do |id, timezone|
      assert_equal timezone, OrgPreferenceTimezoneOption.new(id: id).name
    end
  end
end
