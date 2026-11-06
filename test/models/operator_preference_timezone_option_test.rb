# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_preference_timezone_options
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OperatorPreferenceTimezoneOptionTest < ActiveSupport::TestCase
  fixtures :operator_preference_timezone_options

  test "returns Etc/UTC for ETC_UTC id" do
    option = operator_preference_timezone_options(:etc_utc)

    assert_equal "Etc/UTC", option.name
  end

  test "returns Asia/Tokyo for ASIA_TOKYO id" do
    option = operator_preference_timezone_options(:asia_tokyo)

    assert_equal "Asia/Tokyo", option.name
  end

  test "returns United States timezone names" do
    expectations = {
      america_new_york: "America/New_York",
      america_chicago: "America/Chicago",
      america_denver: "America/Denver",
      america_los_angeles: "America/Los_Angeles",
      america_anchorage: "America/Anchorage",
      pacific_honolulu: "Pacific/Honolulu",
    }

    expectations.each do |fixture_name, timezone|
      assert_equal timezone, operator_preference_timezone_options(fixture_name).name
    end
  end

  test "returns nil for unknown id" do
    option = OperatorPreferenceTimezoneOption.new(id: 999)

    assert_nil option.name
  end

  test "ensure_defaults! creates missing default records" do
    Prosopite.pause do
      OperatorPreferenceTimezone.where(option_id: OperatorPreferenceTimezoneOption::DEFAULTS).delete_all
      OperatorPreferenceTimezoneOption.where(id: OperatorPreferenceTimezoneOption::DEFAULTS).destroy_all
    end

    OperatorPreferenceTimezoneOption.ensure_defaults!

    assert OperatorPreferenceTimezoneOption.exists?(id: OperatorPreferenceTimezoneOption::ETC_UTC)
    assert OperatorPreferenceTimezoneOption.exists?(id: OperatorPreferenceTimezoneOption::ASIA_TOKYO)
  end

  test "ensure_defaults! does nothing when all defaults exist" do
    OperatorPreferenceTimezoneOption.ensure_defaults!
    initial_count = OperatorPreferenceTimezoneOption.count

    OperatorPreferenceTimezoneOption.ensure_defaults!

    assert_equal initial_count, OperatorPreferenceTimezoneOption.count
  end

  test "ensure_defaults! uses Prosopite.pause when defined" do
    Prosopite.pause do
      OperatorPreferenceTimezone.where(option_id: OperatorPreferenceTimezoneOption::DEFAULTS).delete_all
      OperatorPreferenceTimezoneOption.where(id: OperatorPreferenceTimezoneOption::DEFAULTS).destroy_all
    end
    pause_called = false

    Prosopite.stub(
      :pause,
      ->(&block) {
        pause_called = true
        block.call
      },
    ) do
      OperatorPreferenceTimezoneOption.ensure_defaults!
    end

    assert pause_called
    assert OperatorPreferenceTimezoneOption.exists?(id: OperatorPreferenceTimezoneOption::ETC_UTC)
    assert OperatorPreferenceTimezoneOption.exists?(id: OperatorPreferenceTimezoneOption::ASIA_TOKYO)
  end

  test "DEFAULTS constant exists" do
    assert_equal [1, 2, 3, 4, 5, 6, 7, 8], OperatorPreferenceTimezoneOption::DEFAULTS
  end

  test "has_many operator_preference_timezones association" do
    option = operator_preference_timezone_options(:etc_utc)

    assert_respond_to option, :operator_preference_timezones
  end
end
