# frozen_string_literal: true
# typed: false

# == Schema Information
#
# Table name: app_preference_languages
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
#  index_app_preference_languages_on_option_id      (option_id)
#  index_app_preference_languages_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_app_preference_languages_on_option_id  (option_id => app_preference_language_options.id)
#  fk_rails_...                              (preference_id => app_preferences.id)
#

require "test_helper"

class AppPreferenceLanguageTest < ActiveSupport::TestCase
  setup do
    AppPreferenceStatus.ensure_defaults!
    @preference = AppPreference.create!(status_id: AppPreferenceStatus::NOTHING)
  end

  test "belongs to preference" do
    language = AppPreferenceLanguage.new

    assert_not language.valid?
    assert_includes language.errors[:preference], "を入力してください"
  end

  test "can be created with preference and option" do
    option = app_preference_language_options(:ja)
    language = AppPreferenceLanguage.create!(preference: @preference, option: option)

    assert_not_nil language.id
    assert_equal @preference, language.preference
    assert_equal option, language.option
  end

  test "sets default option_id on create" do
    language = AppPreferenceLanguage.create!(preference: @preference)

    assert_equal AppPreferenceLanguageOption::JA, language.option_id
  end

  test "validates uniqueness of preference" do
    option = app_preference_language_options(:ja)
    AppPreferenceLanguage.create!(preference: @preference, option: option)
    duplicate_language = AppPreferenceLanguage.new(preference: @preference, option: option)

    assert_not duplicate_language.valid?
    assert_includes duplicate_language.errors[:preference_id], "はすでに存在します"
  end
end
