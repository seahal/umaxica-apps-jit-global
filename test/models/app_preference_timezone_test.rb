# frozen_string_literal: true
# typed: false
# == Schema Information
#
# Table name: app_preference_timezones
# Database name: app_setting
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  option_id     :bigint           not null
#  preference_id :bigint           not null
#
# Indexes
#
#  index_app_preference_timezones_on_option_id      (option_id)
#  index_app_preference_timezones_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_app_preference_timezones_on_option_id  (option_id => app_preference_timezone_options.id)
#  fk_rails_...                              (preference_id => app_preferences.id)
#


require "test_helper"

class AppPreferenceTimezoneTest < ActiveSupport::TestCase
  setup do
    AppPreferenceStatus.ensure_defaults!
    @preference = AppPreference.create!(status_id: AppPreferenceStatus::NOTHING)
  end

  test "belongs to preference" do
    timezone = AppPreferenceTimezone.new

    assert_not timezone.valid?
    assert_not_empty timezone.errors[:preference]
  end

  test "can be created with preference and option" do
    option = app_preference_timezone_options(:asia_tokyo)
    timezone = AppPreferenceTimezone.create!(preference: @preference, option: option)

    assert_not_nil timezone.id
    assert_equal @preference, timezone.preference
    assert_equal option, timezone.option
  end

  test "sets default option_id on create" do
    timezone = AppPreferenceTimezone.create!(preference: @preference)

    assert_equal AppPreferenceTimezoneOption::ASIA_TOKYO, timezone.option_id
  end

  test "validates uniqueness of preference" do
    option = app_preference_timezone_options(:asia_tokyo)
    AppPreferenceTimezone.create!(preference: @preference, option: option)
    duplicate_timezone = AppPreferenceTimezone.new(preference: @preference, option: option)

    assert_not duplicate_timezone.valid?
    assert_not_empty duplicate_timezone.errors[:preference_id]
  end

  test "AppPreferenceTimezoneOption accepts numeric ids" do
    option = AppPreferenceTimezoneOption.create!(id: 99)

    assert_predicate option, :persisted?
    timezone = AppPreferenceTimezone.create!(preference: @preference, option_id: 99)

    assert_equal option, timezone.option
  end
end
