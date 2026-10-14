# frozen_string_literal: true
# typed: false
# == Schema Information
#
# Table name: com_preference_languages
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
#  index_com_preference_languages_on_option_id      (option_id)
#  index_com_preference_languages_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_com_preference_languages_on_option_id  (option_id => com_preference_language_options.id)
#  fk_rails_...                              (preference_id => com_preferences.id)
#


require "test_helper"

class ComPreferenceLanguageTest < ActiveSupport::TestCase
  setup do
    ComPreferenceStatus.find_or_create_by!(id: ComPreferenceStatus::NOTHING)
    @preference = ComPreference.create!(status_id: ComPreferenceStatus::NOTHING)
  end

  test "belongs to preference" do
    language = ComPreferenceLanguage.new

    assert_not language.valid?
    assert_includes language.errors[:preference], "を入力してください"
  end

  test "can be created with preference and option" do
    option = com_preference_language_options(:ja)
    language = ComPreferenceLanguage.create!(preference: @preference, option: option)

    assert_not_nil language.id
    assert_equal @preference, language.preference
    assert_equal option, language.option
  end

  test "sets default option_id on create" do
    language = ComPreferenceLanguage.create!(preference: @preference)

    assert_equal ComPreferenceLanguageOption::JA, language.option_id
  end
end
