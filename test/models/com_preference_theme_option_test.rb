# frozen_string_literal: true
# typed: false
# == Schema Information
#
# Table name: com_preference_theme_options
# Database name: com_setting
#
#  id :bigint           not null, primary key
#


require "test_helper"

class ComPreferenceThemeOptionTest < ActiveSupport::TestCase
  setup do
    ComPreferenceStatus.find_or_create_by!(id: ComPreferenceStatus::NOTHING)
  end

  test "can be created" do
    option = ComPreferenceThemeOption.create!(id: 99)

    assert_not_nil option.id
  end

  test "has many com_preference_themes" do
    option = ComPreferenceThemeOption.create!(id: 99)
    preference = ComPreference.create!
    theme = ComPreferenceTheme.create!(preference: preference, option: option)

    assert_includes option.com_preference_themes, theme
  end

  test "restricts deletion when associated records exist" do
    option = ComPreferenceThemeOption.create!(id: 99)
    preference = ComPreference.create!
    ComPreferenceTheme.create!(preference: preference, option: option)

    assert_raises(ActiveRecord::RecordNotDestroyed) do
      option.destroy!
    end
  end

  test "ensure_defaults! restores missing fixed ids" do
    com_preference_themes(:one).destroy!
    com_preference_theme_options(:system).destroy!

    assert_not ComPreferenceThemeOption.exists?(ComPreferenceThemeOption::SYSTEM)

    ComPreferenceThemeOption.ensure_defaults!

    assert_equal ComPreferenceThemeOption::DEFAULTS,
                 ComPreferenceThemeOption.order(:id).pluck(:id)
  end

  test "name returns nil for unknown id" do
    option = ComPreferenceThemeOption.new(id: 99)

    assert_nil option.name
  end

  test "name returns light for LIGHT id" do
    option = ComPreferenceThemeOption.new(id: ComPreferenceThemeOption::LIGHT)

    assert_equal "light", option.name
  end

  test "name returns dark for DARK id" do
    option = ComPreferenceThemeOption.new(id: ComPreferenceThemeOption::DARK)

    assert_equal "dark", option.name
  end

  test "name returns system for SYSTEM id" do
    option = ComPreferenceThemeOption.new(id: ComPreferenceThemeOption::SYSTEM)

    assert_equal "system", option.name
  end
end
