# frozen_string_literal: true
# typed: false

# == Schema Information
#
# Table name: org_preference_theme_options
# Database name: org_setting
#
#  id :bigint           not null, primary key
#

require "test_helper"

class OrgPreferenceThemeOptionTest < ActiveSupport::TestCase
  setup do
    OrgPreferenceStatus.find_or_create_by!(id: OrgPreferenceStatus::NOTHING)
  end

  test "can be created" do
    option = OrgPreferenceThemeOption.create!(id: 99)

    assert_not_nil option.id
  end

  test "has many org_preference_themes" do
    option = OrgPreferenceThemeOption.create!(id: 99)
    preference = OrgPreference.create!
    theme = OrgPreferenceTheme.create!(preference: preference, option: option)

    assert_includes option.org_preference_themes, theme
  end

  test "restricts deletion when associated records exist" do
    option = OrgPreferenceThemeOption.create!(id: 99)
    preference = OrgPreference.create!
    OrgPreferenceTheme.create!(preference: preference, option: option)

    assert_raises(ActiveRecord::RecordNotDestroyed) do
      option.destroy!
    end
  end

  test "name returns nil for unknown id" do
    option = OrgPreferenceThemeOption.new(id: 99)

    assert_nil option.name
  end

  test "name returns light for LIGHT id" do
    option = OrgPreferenceThemeOption.new(id: OrgPreferenceThemeOption::LIGHT)

    assert_equal "light", option.name
  end

  test "name returns dark for DARK id" do
    option = OrgPreferenceThemeOption.new(id: OrgPreferenceThemeOption::DARK)

    assert_equal "dark", option.name
  end

  test "name returns system for SYSTEM id" do
    option = OrgPreferenceThemeOption.new(id: OrgPreferenceThemeOption::SYSTEM)

    assert_equal "system", option.name
  end
end
