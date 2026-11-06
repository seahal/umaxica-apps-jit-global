# typed: false
# frozen_string_literal: true

require "test_helper"

class OperatorPreferenceTest < ActiveSupport::TestCase
  test "belongs to the owning operator and retains one child for each display field" do
    preference = operator_preferences(:one)

    assert_equal operators(:one), preference.operator
    assert_predicate preference.operator_preference_language, :present?
    assert_predicate preference.operator_preference_timezone, :present?
    assert_predicate preference.operator_preference_region, :present?
    assert_predicate preference.operator_preference_theme, :present?
  end

  test "new actor preference has active status and explicit metadata starts empty" do
    preference = OperatorPreference.create!(operator: operators(:sample_staff))

    assert_equal OperatorPreferenceStatus::ACTIVE, preference.status_id
    assert_empty preference.explicit_fields
    assert_equal 21, preference.public_id.length
  end

  test "active actor preference uniqueness permits a retired historical row" do
    operator = operators(:one)
    active = operator_preferences(:one)
    retired = OperatorPreference.create!(
      operator:, status_id: OperatorPreferenceStatus::RETIRED, explicit_fields: [],
    )

    assert_equal operator.id, retired.operator_id
    assert_raises(ActiveRecord::RecordNotUnique) do
      OperatorPreference.transaction(requires_new: true) do
        OperatorPreference.create!(operator:, status_id: OperatorPreferenceStatus::ACTIVE, explicit_fields: [])
      end
    end
    assert_equal OperatorPreferenceStatus::ACTIVE, active.reload.status_id
  end

  test "explicit display snapshot reads marked child values and excludes region itself" do
    preference = operator_preferences(:one)
    preference.update!(explicit_fields: %w(language theme region))
    preference.operator_preference_language.update!(option_id: OperatorPreferenceLanguageOption::EN)
    preference.operator_preference_theme.update!(option_id: OperatorPreferenceThemeOption::DARK)

    assert_equal({ "language" => "en", "theme" => "dark" }, preference.explicit_values)
    assert_equal %w(language theme region), preference.reload.explicit_fields
  end

  test "operator exposes its current actor preference" do
    operator = operators(:one)

    assert_equal operator_preferences(:one), operator.operator_preference
  end

  test "dormant adult content gate remains model-only" do
    assert_nil OperatorPreference.new.operator_preference_adult_content_gate
  end

  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::OperatorPreference)
  end
end
