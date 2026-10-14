# frozen_string_literal: true
# typed: false
# == Schema Information
#
# Table name: com_preference_timezones
# Database name: com_setting
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  option_id     :bigint           not null
#  preference_id :bigint           not null
#
# Indexes
#
#  index_com_preference_timezones_on_option_id      (option_id)
#  index_com_preference_timezones_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_com_preference_timezones_on_option_id  (option_id => com_preference_timezone_options.id)
#  fk_rails_...                              (preference_id => com_preferences.id)
#


require "test_helper"

class ComPreferenceTimezoneTest < ActiveSupport::TestCase
  setup do
    ComPreferenceStatus.find_or_create_by!(id: ComPreferenceStatus::NOTHING)
    @preference = ComPreference.create!(status_id: ComPreferenceStatus::NOTHING)
  end

  test "belongs to preference" do
    timezone = ComPreferenceTimezone.new

    assert_not timezone.valid?
    assert_includes timezone.errors[:preference], "を入力してください"
  end

  test "can be created with preference and option" do
    option = com_preference_timezone_options(:asia_tokyo)
    timezone = ComPreferenceTimezone.create!(preference: @preference, option: option)

    assert_not_nil timezone.id
    assert_equal @preference, timezone.preference
    assert_equal option, timezone.option
  end

  test "sets default option_id on create" do
    timezone = ComPreferenceTimezone.create!(preference: @preference)

    assert_equal ComPreferenceTimezoneOption::ASIA_TOKYO, timezone.option_id
  end
end
