# frozen_string_literal: true
# typed: false

# == Schema Information
#
# Table name: app_preference_theme_options
# Database name: app_setting
#
#  id :bigint           not null, primary key
#

require "test_helper"

class AppPreferenceThemeOptionTest < ActiveSupport::TestCase
  setup do
    AppPreferenceStatus.ensure_defaults!
  end

  test "can be created" do
    option = AppPreferenceThemeOption.create!(id: 99)

    assert_not_nil option.id
  end

  test "has many app_preference_themes" do
    option = AppPreferenceThemeOption.create!(id: 99)
    preference = AppPreference.create!
    theme = AppPreferenceTheme.create!(preference: preference, option: option)

    assert_includes option.app_preference_themes, theme
  end

  test "restricts deletion when associated records exist" do
    option = AppPreferenceThemeOption.create!(id: 99)
    preference = AppPreference.create!
    AppPreferenceTheme.create!(preference: preference, option: option)

    assert_raises(ActiveRecord::RecordNotDestroyed) do
      option.destroy!
    end
  end

  test "name returns light for LIGHT id" do
    option = AppPreferenceThemeOption.new(id: AppPreferenceThemeOption::LIGHT)

    assert_equal "light", option.name
  end

  test "name returns dark for DARK id" do
    option = AppPreferenceThemeOption.new(id: AppPreferenceThemeOption::DARK)

    assert_equal "dark", option.name
  end

  test "name returns system for SYSTEM id" do
    option = AppPreferenceThemeOption.new(id: AppPreferenceThemeOption::SYSTEM)

    assert_equal "system", option.name
  end

  test "name returns nil for NOTHING id" do
    option = AppPreferenceThemeOption.new(id: AppPreferenceThemeOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = AppPreferenceThemeOption.new(id: 999)

    assert_nil option.name
  end
end
