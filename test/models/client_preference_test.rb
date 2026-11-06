# typed: false
# frozen_string_literal: true

require "test_helper"

class ClientPreferenceTest < ActiveSupport::TestCase
  test "belongs to the owning client and retains one child for each display field" do
    preference = client_preferences(:one)

    assert_equal clients(:one), preference.client
    assert_predicate preference.client_preference_language, :present?
    assert_predicate preference.client_preference_timezone, :present?
    assert_predicate preference.client_preference_region, :present?
    assert_predicate preference.client_preference_theme, :present?
  end

  test "new actor preference has active status and explicit metadata starts empty" do
    preference = ClientPreference.create!(client: clients(:sample_user))

    assert_equal ClientPreferenceStatus::ACTIVE, preference.status_id
    assert_empty preference.explicit_fields
    assert_equal 21, preference.public_id.length
  end

  test "active actor preference uniqueness permits a retired historical row" do
    client = clients(:one)
    active = client_preferences(:one)
    retired = ClientPreference.create!(
      client:, status_id: ClientPreferenceStatus::RETIRED, explicit_fields: [],
    )

    assert_equal client.id, retired.client_id
    assert_raises(ActiveRecord::RecordNotUnique) do
      ClientPreference.transaction(requires_new: true) do
        ClientPreference.create!(client:, status_id: ClientPreferenceStatus::ACTIVE, explicit_fields: [])
      end
    end
    assert_equal ClientPreferenceStatus::ACTIVE, active.reload.status_id
  end

  test "explicit display snapshot reads marked child values and excludes region itself" do
    preference = client_preferences(:one)
    preference.update!(explicit_fields: %w(language theme region))
    preference.client_preference_language.update!(option_id: ClientPreferenceLanguageOption::EN)
    preference.client_preference_theme.update!(option_id: ClientPreferenceThemeOption::DARK)

    assert_equal({ "language" => "en", "theme" => "dark" }, preference.explicit_values)
    assert_equal %w(language theme region), preference.reload.explicit_fields
  end

  test "explicit display snapshot fails when a marked child is missing" do
    preference = client_preferences(:one)
    preference.update!(explicit_fields: ["language"])
    preference.client_preference_language.destroy!
    preference.reload

    assert_raises(ActiveRecord::RecordNotFound) { preference.explicit_values }
  end

  test "client exposes its current actor preference" do
    client = clients(:one)

    assert_equal client_preferences(:one), client.client_preference
  end

  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::ClientPreference)
  end
end
