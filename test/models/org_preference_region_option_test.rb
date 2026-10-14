# frozen_string_literal: true
# typed: false
# == Schema Information
#
# Table name: org_preference_region_options
# Database name: org_setting
#
#  id :bigint           not null, primary key
#


require "test_helper"

class OrgPreferenceRegionOptionTest < ActiveSupport::TestCase
  setup do
    OrgPreferenceStatus.find_or_create_by!(id: OrgPreferenceStatus::NOTHING)
  end

  test "can be created" do
    option = OrgPreferenceRegionOption.create!(id: 99)

    assert_not_nil option.id
  end

  test "has many org_preference_regions" do
    option = OrgPreferenceRegionOption.create!(id: 99)
    preference = OrgPreference.create!
    region = OrgPreferenceRegion.create!(preference: preference, option: option)

    assert_includes option.org_preference_regions, region
  end

  test "restricts deletion when associated records exist" do
    option = OrgPreferenceRegionOption.create!(id: 99)
    preference = OrgPreference.create!
    OrgPreferenceRegion.create!(preference: preference, option: option)

    assert_raises(ActiveRecord::RecordNotDestroyed) do
      option.destroy!
    end
  end

  test "name returns US for US id" do
    option = OrgPreferenceRegionOption.find_or_create_by!(id: OrgPreferenceRegionOption::US)

    assert_equal "US", option.name
  end

  test "name returns JP for JP id" do
    option = OrgPreferenceRegionOption.find_or_create_by!(id: OrgPreferenceRegionOption::JP)

    assert_equal "JP", option.name
  end

  test "name returns nil for unknown id" do
    option = OrgPreferenceRegionOption.new(id: 99)

    assert_nil option.name
  end
end
