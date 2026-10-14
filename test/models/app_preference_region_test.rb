# frozen_string_literal: true
# typed: false
# == Schema Information
#
# Table name: app_preference_regions
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
#  index_app_preference_regions_on_option_id      (option_id)
#  index_app_preference_regions_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_app_preference_regions_on_option_id  (option_id => app_preference_region_options.id)
#  fk_rails_...                            (preference_id => app_preferences.id)
#


require "test_helper"

class AppPreferenceRegionTest < ActiveSupport::TestCase
  fixtures :app_preference_region_options

  setup do
    AppPreferenceStatus.ensure_defaults!
    @preference = AppPreference.create!(status_id: AppPreferenceStatus::NOTHING)
  end

  test "belongs to preference" do
    region = AppPreferenceRegion.new

    assert_not region.valid?
    assert_not_empty region.errors[:preference]
  end

  test "can be created with preference and option" do
    option = app_preference_region_options(:jp)
    region = AppPreferenceRegion.create!(preference: @preference, option: option)

    assert_not_nil region.id
    assert_equal @preference, region.preference
    assert_equal option, region.option
  end

  test "sets default option_id on create" do
    region = AppPreferenceRegion.create!(preference: @preference)

    assert_equal AppPreferenceRegionOption::JP, region.option_id
  end

  test "validates uniqueness of preference" do
    option = app_preference_region_options(:jp)
    AppPreferenceRegion.create!(preference: @preference, option: option)
    duplicate_region = AppPreferenceRegion.new(preference: @preference, option: option)

    assert_not duplicate_region.valid?
    assert_not_empty duplicate_region.errors[:preference_id]
  end

  test "rejects non-existent arbitrary option_id" do
    error =
      assert_raises(ActiveRecord::RecordInvalid) do
        AppPreferenceRegion.create!(preference: @preference, option_id: 9999)
      end

    assert_includes error.record.errors[:option], I18n.t("errors.messages.required")
  end

  test "AppPreferenceRegionOption accepts numeric ids" do
    option = AppPreferenceRegionOption.create!(id: 99)

    assert_predicate option, :persisted?
    region = AppPreferenceRegion.create!(preference: @preference, option_id: 99)

    assert_equal option, region.option
  end
end
