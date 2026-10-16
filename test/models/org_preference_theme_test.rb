# frozen_string_literal: true
# typed: false

# == Schema Information
#
# Table name: org_preference_themes
# Database name: org_setting
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  option_id     :bigint           not null
#  preference_id :bigint           not null
#
# Indexes
#
#  index_org_preference_themes_on_option_id      (option_id)
#  index_org_preference_themes_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_org_preference_themes_on_option_id  (option_id => org_preference_theme_options.id)
#  fk_rails_...                           (preference_id => org_preferences.id)
#

require "test_helper"

class OrgPreferenceThemeTest < ActiveSupport::TestCase
  setup do
    OrgPreferenceStatus.find_or_create_by!(id: OrgPreferenceStatus::NOTHING)
    @preference = OrgPreference.create!(status_id: OrgPreferenceStatus::NOTHING)
  end

  test "belongs to preference" do
    theme = OrgPreferenceTheme.new

    assert_not theme.valid?
    assert_includes theme.errors[:preference], "を入力してください"
  end

  test "can be created with preference and option" do
    option = org_preference_theme_options(:light)
    theme = OrgPreferenceTheme.create!(preference: @preference, option: option)

    assert_not_nil theme.id
    assert_equal @preference, theme.preference
    assert_equal option, theme.option
  end

  test "sets default option_id on create" do
    theme = OrgPreferenceTheme.create!(preference: @preference)

    assert_equal OrgPreferenceThemeOption::SYSTEM, theme.option_id
  end
end
