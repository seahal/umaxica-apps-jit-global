# frozen_string_literal: true
# typed: false

# == Schema Information
#
# Table name: org_preference_language_options
# Database name: org_setting
#
#  id :bigint           not null, primary key
#

require "test_helper"

class OrgPreferenceLanguageOptionTest < ActiveSupport::TestCase
  setup do
    OrgPreferenceStatus.find_or_create_by!(id: OrgPreferenceStatus::NOTHING)
  end

  test "can be created" do
    option = OrgPreferenceLanguageOption.create!(id: 99)

    assert_not_nil option.id
  end

  test "has many org_preference_languages" do
    option = OrgPreferenceLanguageOption.create!(id: 99)
    preference = OrgPreference.create!
    language = OrgPreferenceLanguage.create!(preference: preference, option: option)

    assert_includes option.org_preference_languages, language
  end

  test "ensure_defaults! creates missing default records" do
    OrgPreferenceLanguageOption.where(id: OrgPreferenceLanguageOption::DEFAULTS).delete_all

    assert_empty OrgPreferenceLanguageOption.where(id: OrgPreferenceLanguageOption::DEFAULTS)

    OrgPreferenceLanguageOption.ensure_defaults!

    assert_equal OrgPreferenceLanguageOption::DEFAULTS.sort,
                 OrgPreferenceLanguageOption.where(id: OrgPreferenceLanguageOption::DEFAULTS).pluck(:id).sort
  end

  test "ensure_defaults! does nothing when all defaults exist" do
    OrgPreferenceLanguageOption.ensure_defaults!

    assert_no_difference("OrgPreferenceLanguageOption.count") do
      OrgPreferenceLanguageOption.ensure_defaults!
    end
  end

  test "restricts deletion when associated records exist" do
    option = OrgPreferenceLanguageOption.create!(id: 99)
    preference = OrgPreference.create!
    OrgPreferenceLanguage.create!(preference: preference, option: option)

    assert_raises(ActiveRecord::RecordNotDestroyed) do
      option.destroy!
    end
  end

  test "name returns ja for JA id" do
    option = OrgPreferenceLanguageOption.find_or_create_by!(id: OrgPreferenceLanguageOption::JA)

    assert_equal "ja", option.name
  end

  test "name returns en for EN id" do
    option = OrgPreferenceLanguageOption.find_or_create_by!(id: OrgPreferenceLanguageOption::EN)

    assert_equal "en", option.name
  end

  test "name returns nil for unknown id" do
    option = OrgPreferenceLanguageOption.find_or_create_by!(id: 999)

    assert_nil option.name
  end
end
