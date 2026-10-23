# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_preference_language_options
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OperatorPreferenceLanguageOptionTest < ActiveSupport::TestCase
  def setup
    Prosopite.pause do
      OperatorPreferenceLanguageOption::DEFAULTS.each do |id|
        OperatorPreferenceLanguageOption.find_or_create_by!(id: id)
      end
    end
  end

  test "NOTHING constant is defined" do
    assert_equal 0, OperatorPreferenceLanguageOption::NOTHING
  end

  test "JA constant is defined" do
    assert_equal 1, OperatorPreferenceLanguageOption::JA
  end

  test "EN constant is defined" do
    assert_equal 2, OperatorPreferenceLanguageOption::EN
  end

  test "DEFAULTS constant contains JA and EN" do
    assert_equal [1, 2], OperatorPreferenceLanguageOption::DEFAULTS
  end

  test "name returns ja for JA id" do
    option = OperatorPreferenceLanguageOption.find_or_create_by!(id: OperatorPreferenceLanguageOption::JA)

    assert_equal "ja", option.name
  end

  test "name returns en for EN id" do
    option = OperatorPreferenceLanguageOption.find_or_create_by!(id: OperatorPreferenceLanguageOption::EN)

    assert_equal "en", option.name
  end

  test "name returns nil for NOTHING id" do
    option = OperatorPreferenceLanguageOption.create!(id: OperatorPreferenceLanguageOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = OperatorPreferenceLanguageOption.create!(id: 999)

    assert_nil option.name
  end

  test "has_many operator_preference_languages association" do
    assert_respond_to OperatorPreferenceLanguageOption.new, :operator_preference_languages
  end

  test "ensure_defaults! creates missing option records" do
    OperatorPreferenceLanguage.where(option_id: OperatorPreferenceLanguageOption::EN).delete_all
    OperatorPreferenceLanguageOption.where(id: OperatorPreferenceLanguageOption::EN).delete_all

    assert_difference("OperatorPreferenceLanguageOption.count", 1) do
      OperatorPreferenceLanguageOption.ensure_defaults!
    end

    assert OperatorPreferenceLanguageOption.exists?(id: OperatorPreferenceLanguageOption::EN)
  end

  test "ensure_defaults! skips existing records" do
    assert_no_difference("OperatorPreferenceLanguageOption.count") do
      OperatorPreferenceLanguageOption.ensure_defaults!
    end
  end

  test "primary_key is id" do
    assert_equal "id", OperatorPreferenceLanguageOption.primary_key
  end

  test "operator_preference_languages association works with dependent restrict" do
    option = OperatorPreferenceLanguageOption.find(OperatorPreferenceLanguageOption::JA)
    staff = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)

    pref = OperatorPreference.create!(staff: staff)
    language = OperatorPreferenceLanguage.create!(
      preference: pref,
      option_id: option.id,
    )

    assert_includes option.operator_preference_languages, language

    # Test restrict_with_error
    assert_not option.destroy
    assert_predicate option.errors[:base], :present?
  end
end
