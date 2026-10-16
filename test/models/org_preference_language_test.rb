# frozen_string_literal: true
# typed: false

# == Schema Information
#
# Table name: org_preference_languages
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
#  index_org_preference_languages_on_option_id      (option_id)
#  index_org_preference_languages_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_org_preference_languages_on_option_id  (option_id => org_preference_language_options.id)
#  fk_rails_...                              (preference_id => org_preferences.id)
#

require "test_helper"

class OrgPreferenceLanguageTest < ActiveSupport::TestCase
  setup do
    OrgPreferenceStatus.find_or_create_by!(id: OrgPreferenceStatus::NOTHING)
    @preference = OrgPreference.create!(status_id: OrgPreferenceStatus::NOTHING)
  end

  test "belongs to preference" do
    language = OrgPreferenceLanguage.new

    assert_not language.valid?
    assert_predicate language.errors[:preference], :any?
  end

  test "can be created with preference and option" do
    option = org_preference_language_options(:ja)
    language = OrgPreferenceLanguage.create!(preference: @preference, option: option)

    assert_not_nil language.id
    assert_equal @preference, language.preference
    assert_equal option, language.option
  end

  test "sets default option_id on create" do
    language = OrgPreferenceLanguage.create!(preference: @preference)

    assert_equal OrgPreferenceLanguageOption::JA, language.option_id
  end
end
