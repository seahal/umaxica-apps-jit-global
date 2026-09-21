# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

AdoptionSnapshotPreference =
  Struct.new(:language, :region, :timezone, :theme) do
    def blank? = false
  end

module Preference
  class AdoptionTest < ActiveSupport::TestCase
    fixtures :clients, :client_statuses, :operators, :operator_statuses,
             :app_preferences, :app_preference_statuses,
             :app_preference_binding_methods, :app_preference_dbsc_statuses,
             :org_preferences, :org_preference_statuses,
             :org_preference_binding_methods, :org_preference_dbsc_statuses,
             :app_preference_language_options, :app_preference_timezone_options,
             :app_preference_region_options, :app_preference_theme_options,
             :client_preference_language_options, :client_preference_timezone_options,
             :client_preference_region_options, :client_preference_theme_options,
             :operator_preference_language_options, :operator_preference_timezone_options,
             :operator_preference_region_options, :operator_preference_theme_options

    setup do
      @user = clients(:none_user)
      @preference = AppPreference.create!(
        status_id: AppPreferenceStatus::NOTHING,
        binding_method_id: AppPreferenceBindingMethod::NOTHING,
        dbsc_status_id: AppPreferenceDbscStatus::NOTHING,
        discard_at: 20.years.from_now,
        purge_eligible_at: 20.years.from_now,
      )
      @new_preference = AppPreference.create!(
        status_id: AppPreferenceStatus::NOTHING,
        binding_method_id: AppPreferenceBindingMethod::NOTHING,
        dbsc_status_id: AppPreferenceDbscStatus::NOTHING,
        discard_at: 20.years.from_now,
        purge_eligible_at: 20.years.from_now,
      )
      @adoption = build_adoption_context(@preference)

      # Clean up any existing ClientPreference for our test user
      AppZenithRecord.connected_to(role: :writing) do
        ClientPreference.where(user_id: @user.id).delete_all
      end
    end

    # --- adoptable_preference_class? ---

    # --- find_resource_preference ---

    # --- find_or_create_resource_preference! ---

    # --- copy_preference_values! ---

    # --- adopt_preference_for! (integration) ---

    # --- legacy (explicit_fields IS NULL) principal compatibility ---

    test "a freshly created principal row is known-non-explicit, not legacy" do
      user_pref = create_user_preference!(@user)

      assert_not user_pref.legacy_unknown_explicit_state?
      assert_equal [], user_pref.explicit_field_names
    end

    test "an explicit user action on a legacy principal row transitions it to known" do
      user_pref = create_user_preference!(@user)
      AppZenithRecord.connected_to(role: :writing) { user_pref.update_column(:explicit_fields, nil) }
      user_pref.reload

      assert_predicate user_pref, :legacy_unknown_explicit_state?

      user_pref.mark_field_explicit!(:timezone)

      assert_not user_pref.reload.legacy_unknown_explicit_state?
      assert user_pref.explicit_field?(:timezone)
    end

    # --- adopt_rotated_preference! ---

    private

    PREFERENCE_CLASSES = {
      "AppPreference" => AppPreference,
      "ComPreference" => ComPreference,
      "OrgPreference" => OrgPreference,
    }.freeze

    def build_adoption_context(preference, preference_class_name: "AppPreference")
      pref_class = PREFERENCE_CLASSES.fetch(preference_class_name)
      ctx = Object.new
      ctx.extend(PreferenceAdoption)

      ctx.define_singleton_method(:preference_class) { pref_class }
      ctx.define_singleton_method(:preference_prefix) { |_pref = nil| pref_class.name.gsub("Preference", "") }
      ctx.define_singleton_method(:preference_option_classes) do |prefix|
        {
          language: PreferenceClassRegistry.option_class(prefix, :language),
          timezone: PreferenceClassRegistry.option_class(prefix, :timezone),
          region: PreferenceClassRegistry.option_class(prefix, :region),
          theme: PreferenceClassRegistry.option_class(prefix, :theme),
        }
      end
      ctx.instance_variable_set(:@preferences, preference)

      # Stub issue_access_token_from as no-op (JWT issuance not under test)
      ctx.define_singleton_method(:issue_access_token_from) { |_pref| nil }

      ctx
    end

    def create_user_preference!(user)
      AppZenithRecord.connected_to(role: :writing) do
        pref = ClientPreference.create!(user_id: user.id)
        ClientPreferenceLanguage.create!(preference_id: pref.id, option_id: ClientPreferenceLanguageOption::JA)
        ClientPreferenceTimezone.create!(preference_id: pref.id, option_id: ClientPreferenceTimezoneOption::ASIA_TOKYO)
        ClientPreferenceRegion.create!(preference_id: pref.id, option_id: ClientPreferenceRegionOption::JP)
        ClientPreferenceTheme.create!(preference_id: pref.id, option_id: ClientPreferenceThemeOption::SYSTEM)
        pref.reload
        pref
      end
    end
  end
end
