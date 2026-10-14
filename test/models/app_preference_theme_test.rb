# frozen_string_literal: true
# typed: false
# == Schema Information
#
# Table name: app_preference_themes
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
#  index_app_preference_themes_on_option_id      (option_id)
#  index_app_preference_themes_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_app_preference_themes_on_option_id  (option_id => app_preference_theme_options.id)
#  fk_rails_...                           (preference_id => app_preferences.id)
#


require "test_helper"

class AppPreferenceThemeTest < ActiveSupport::TestCase
  setup do
    AppPreferenceStatus.ensure_defaults!
    @preference = AppPreference.create!(status_id: AppPreferenceStatus::NOTHING)
  end

  test "belongs to preference" do
    theme = AppPreferenceTheme.new

    assert_not theme.valid?
    assert_not_empty theme.errors[:preference]
  end

  test "can be created with preference and option" do
    option = app_preference_theme_options(:light)
    theme = AppPreferenceTheme.create!(preference: @preference, option: option)

    assert_not_nil theme.id
    assert_equal @preference, theme.preference
    assert_equal option, theme.option
  end

  test "sets default option_id on create" do
    theme = AppPreferenceTheme.create!(preference: @preference)

    assert_equal AppPreferenceThemeOption::SYSTEM, theme.option_id
  end

  test "validates uniqueness of preference" do
    option = app_preference_theme_options(:light)
    AppPreferenceTheme.create!(preference: @preference, option: option)
    duplicate_theme = AppPreferenceTheme.new(preference: @preference, option: option)

    assert_not duplicate_theme.valid?
    assert_not_empty duplicate_theme.errors[:preference_id]
  end

  test "AppPreferenceThemeOption accepts numeric ids" do
    option = AppPreferenceThemeOption.create!(id: 99)

    assert_predicate option, :persisted?
    theme = AppPreferenceTheme.create!(preference: @preference, option_id: 99)

    assert_equal option, theme.option
  end
end
