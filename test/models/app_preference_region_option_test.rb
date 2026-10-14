# frozen_string_literal: true
# typed: false
# == Schema Information
#
# Table name: app_preference_region_options
# Database name: app_setting
#
#  id :bigint           not null, primary key
#


require "test_helper"

class AppPreferenceRegionOptionTest < ActiveSupport::TestCase
  setup do
    AppPreferenceStatus.ensure_defaults!
  end

  test "can be created" do
    option = AppPreferenceRegionOption.create!(id: 99)

    assert_not_nil option.id
  end

  test "has many app_preference_regions" do
    option = AppPreferenceRegionOption.create!(id: 99)
    preference = AppPreference.create!
    region = AppPreferenceRegion.create!(preference: preference, option: option)

    assert_includes option.app_preference_regions, region
  end

  test "restricts deletion when associated records exist" do
    option = AppPreferenceRegionOption.create!(id: 99)
    preference = AppPreference.create!
    AppPreferenceRegion.create!(preference: preference, option: option)

    assert_raises(ActiveRecord::RecordNotDestroyed) do
      option.destroy!
    end
  end

  test "name returns US for US id" do
    option = AppPreferenceRegionOption.find_or_create_by!(id: AppPreferenceRegionOption::US)

    assert_equal "US", option.name
  end

  test "name returns JP for JP id" do
    option = AppPreferenceRegionOption.find_or_create_by!(id: AppPreferenceRegionOption::JP)

    assert_equal "JP", option.name
  end

  test "name returns nil for NOTHING id" do
    option = AppPreferenceRegionOption.find_or_create_by!(id: AppPreferenceRegionOption::NOTHING)

    assert_nil option.name
  end
end
