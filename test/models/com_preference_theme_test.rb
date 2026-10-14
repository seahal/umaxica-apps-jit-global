# frozen_string_literal: true
# typed: false
# == Schema Information
#
# Table name: com_preference_themes
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
#  index_com_preference_themes_on_option_id      (option_id)
#  index_com_preference_themes_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_com_preference_themes_on_option_id  (option_id => com_preference_theme_options.id)
#  fk_rails_...                           (preference_id => com_preferences.id)
#


require "test_helper"

class ComPreferenceThemeTest < ActiveSupport::TestCase
  setup do
    ComPreferenceStatus.find_or_create_by!(id: ComPreferenceStatus::NOTHING)
    @preference = ComPreference.create!(status_id: ComPreferenceStatus::NOTHING)
  end

  test "belongs to preference" do
    theme = ComPreferenceTheme.new

    assert_not theme.valid?
    assert_predicate theme.errors[:preference], :any?, "Expected preference error to be present"
  end

  test "can be created with preference and option" do
    option = com_preference_theme_options(:light)
    theme = ComPreferenceTheme.create!(preference: @preference, option: option)

    assert_not_nil theme.id
    assert_equal @preference, theme.preference
    assert_equal option, theme.option
  end

  test "sets default option_id on create" do
    theme = ComPreferenceTheme.create!(preference: @preference)

    assert_equal ComPreferenceThemeOption::SYSTEM, theme.option_id
  end
end
