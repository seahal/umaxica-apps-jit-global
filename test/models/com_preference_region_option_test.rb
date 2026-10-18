# frozen_string_literal: true
# typed: false

# == Schema Information
#
# Table name: com_preference_region_options
# Database name: com_setting
#
#  id :bigint           not null, primary key
#

require "test_helper"

class ComPreferenceRegionOptionTest < ActiveSupport::TestCase
  setup do
    ComPreferenceStatus.find_or_create_by!(id: ComPreferenceStatus::NOTHING)
  end

  test "can be created" do
    option = ComPreferenceRegionOption.create!(id: 99)

    assert_not_nil option.id
  end

  test "has many com_preference_regions" do
    option = ComPreferenceRegionOption.create!(id: 99)
    preference = ComPreference.create!
    region = ComPreferenceRegion.create!(preference: preference, option: option)

    assert_includes option.com_preference_regions, region
  end

  test "restricts deletion when associated records exist" do
    option = ComPreferenceRegionOption.create!(id: 99)
    preference = ComPreference.create!
    ComPreferenceRegion.create!(preference: preference, option: option)

    assert_raises(ActiveRecord::RecordNotDestroyed) do
      option.destroy!
    end
  end

  test "name returns US for US id" do
    option = ComPreferenceRegionOption.find_or_create_by!(id: ComPreferenceRegionOption::US)

    assert_equal "US", option.name
  end

  test "name returns JP for JP id" do
    option = ComPreferenceRegionOption.find_or_create_by!(id: ComPreferenceRegionOption::JP)

    assert_equal "JP", option.name
  end

  test "name returns nil for unknown id" do
    option = ComPreferenceRegionOption.new(id: 99)

    assert_nil option.name
  end
end
