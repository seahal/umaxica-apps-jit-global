# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

AdoptionSnapshotPreference =
  Struct.new(:language, :region, :timezone, :theme) do
    def blank? = false
  end

class AdoptionFallbackPreference
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
        discarded_at: 20.years.from_now,
        purged_at: 20.years.from_now,
      )
      @new_preference = AppPreference.create!(
        status_id: AppPreferenceStatus::NOTHING,
        binding_method_id: AppPreferenceBindingMethod::NOTHING,
        dbsc_status_id: AppPreferenceDbscStatus::NOTHING,
        discarded_at: 20.years.from_now,
        purged_at: 20.years.from_now,
      )
      @adoption = build_adoption_context(@preference)

      # Clean up any existing ClientPreference for our test user
      AppZenithRecord.connected_to(role: :writing) do
        ClientPreference.where(user_id: @user.id).delete_all
      end
    end

    # --- adoptable_preference_class? ---

    test "adoptable_preference_class? returns true for AppPreference" do
      assert @adoption.send(:adoptable_preference_class?)
    end

    test "adoptable_preference_class? returns true for ComPreference" do
      adoption = build_adoption_context(@preference, preference_class_name: "ComPreference")

      assert adoption.send(:adoptable_preference_class?)
    end

    # --- find_resource_preference ---

    test "find_resource_preference returns nil when no ClientPreference exists" do
      result = @adoption.send(:find_resource_preference, @user)

      assert_nil result
    end

    test "find_resource_preference returns ClientPreference when it exists" do
      user_pref = create_user_preference!(@user)

      # Reload to pick up association
      @user.reload
      result = @adoption.send(:find_resource_preference, @user)

      assert_equal user_pref, result
    end

    # --- find_or_create_resource_preference! ---

    test "find_or_create_resource_preference! creates ClientPreference when none exists" do
      assert_difference "ClientPreference.count", 1 do
        @adoption.send(:find_or_create_resource_preference!, @user)
      end
    end

    test "find_or_create_resource_preference! keeps ClientPreference generated public_id" do
      user_pref = @adoption.send(:find_or_create_resource_preference!, @user)

      assert_predicate user_pref.public_id, :present?
      assert_not_equal @preference.public_id, user_pref.public_id
    end

    test "sync_preferences! does not copy resource public_id to shared preference" do
      app_preference = AppPreference.create!(
        status_id: AppPreferenceStatus::NOTHING,
        binding_method_id: AppPreferenceBindingMethod::NOTHING,
        dbsc_status_id: AppPreferenceDbscStatus::NOTHING,
        discarded_at: 20.years.from_now,
        purged_at: 20.years.from_now,
      )
      user_pref = create_user_preference!(@user)
      adoption = build_adoption_context(app_preference)
      original_public_id = app_preference.public_id

      adoption.send(:sync_preferences!, user_pref)

      assert_equal original_public_id, app_preference.reload.public_id
    end

    test "adopt_preference_for! does not poison app preference public_id after collision" do
      existing_app_preference = AppPreference.create!(
        status_id: AppPreferenceStatus::NOTHING,
        binding_method_id: AppPreferenceBindingMethod::NOTHING,
        dbsc_status_id: AppPreferenceDbscStatus::NOTHING,
        discarded_at: 20.years.from_now,
        purged_at: 20.years.from_now,
      )
      user_pref = create_user_preference!(@user)
      user_pref.update!(public_id: existing_app_preference.public_id)
      @user.reload

      assert_nothing_raised do
        @adoption.send(:adopt_preference_for!, @user)
        @preference.update!(jti: JitSecurityJwtJtiGenerator.generate)
      end

      assert_not_equal existing_app_preference.public_id, @preference.reload.public_id
    end

    test "find_or_create_resource_preference! returns existing ClientPreference" do
      user_pref = create_user_preference!(@user)
      @user.reload

      assert_no_difference "ClientPreference.count" do
        result = @adoption.send(:find_or_create_resource_preference!, @user)

        assert_equal user_pref, result
      end
    end

    # --- copy_preference_values! ---

    test "copy_preference_values! copies child record option_ids from source to target" do
      create_child_record!(@preference, :language, AppPreferenceLanguageOption::EN)
      user_pref = create_user_preference!(@user)
      target_lang = user_pref.user_preference_language

      @adoption.send(:copy_preference_values!, @preference, user_pref, "Client")

      target_lang.reload

      assert_equal ClientPreferenceLanguageOption::EN, target_lang.option_id
    end

    test "copy_preference_values! does not raise when source has no child records" do
      user_pref = create_user_preference!(@user)

      assert_nothing_raised do
        @adoption.send(:copy_preference_values!, @preference, user_pref, "Client")
      end
    end

    # --- adopt_preference_for! (integration) ---

    test "adopt_preference_for! creates ClientPreference on first login" do
      assert_difference "ClientPreference.count", 1 do
        @adoption.send(:adopt_preference_for!, @user)
      end
    end

    test "adopt_preference_for! syncs an explicitly-set browser value to a non-explicit principal default" do
      create_child_record!(@preference, :language, AppPreferenceLanguageOption::EN)
      @preference.mark_field_explicit!(:language)

      # Simulate first login and create ClientPreference (its language stays
      # at the auto-seeded default, never marked explicit).
      user_pref = create_user_preference!(@user)
      @user.reload

      # Whole-record `updated_at` must no longer decide the winner: make the
      # principal side newer and confirm the browser's explicit choice still
      # wins because it, not the timestamp, is the merge authority now.
      ComSettingRecord.connected_to(role: :writing) { user_pref.touch }

      adoption = build_adoption_context(@preference)
      adoption.send(:adopt_preference_for!, @user)

      user_pref.user_preference_language.reload
      user_pref.reload

      assert_equal ClientPreferenceLanguageOption::EN, user_pref.user_preference_language.option_id
      assert user_pref.explicit_field?(:language),
             "principal side must inherit the explicit flag along with the value"
    end

    test "sync_preferences! per-key: neither side explicit favors the principal, independent of updated_at" do
      create_child_record!(@preference, :language, AppPreferenceLanguageOption::EN)
      create_child_record!(@preference, :region, AppPreferenceRegionOption::US)
      user_pref = create_user_preference!(@user)
      @user.reload

      travel_to Time.current.change(usec: 0) do
        @preference.update!(updated_at: 2.minutes.ago)
        user_pref.update!(updated_at: 1.minute.ago)

        @adoption.send(:sync_preferences!, user_pref)
      end

      @preference.app_preference_language.reload
      @preference.app_preference_region.reload

      assert_equal AppPreferenceLanguageOption::JA, @preference.app_preference_language.option_id
      assert_equal AppPreferenceRegionOption::JP, @preference.app_preference_region.option_id
    end

    test "sync_preferences! per-key: an unrelated explicit principal key is not clobbered by a browser-wins key" do
      create_child_record!(@preference, :language, AppPreferenceLanguageOption::EN)
      @preference.mark_field_explicit!(:language)
      user_pref = create_user_preference!(@user)
      @user.reload
      user_pref.user_preference_timezone.update!(option_id: ClientPreferenceTimezoneOption::ASIA_TOKYO)
      user_pref.mark_field_explicit!(:timezone)

      @adoption.send(:sync_preferences!, user_pref)

      user_pref.user_preference_language.reload
      user_pref.user_preference_timezone.reload

      assert_equal ClientPreferenceLanguageOption::EN, user_pref.user_preference_language.option_id
      assert_equal ClientPreferenceTimezoneOption::ASIA_TOKYO, user_pref.user_preference_timezone.option_id
    end

    # --- legacy (explicit_fields IS NULL) principal compatibility ---

    test "sync_preferences! never overwrites a legacy (pre-migration) principal value even when browser is explicit" do
      create_child_record!(@preference, :language, AppPreferenceLanguageOption::EN)
      @preference.mark_field_explicit!(:language)

      user_pref = create_user_preference!(@user)
      # Simulate a row that existed before the explicit_fields column was
      # added: AppZenithRecord.connected_to since this write bypasses the
      # ordinary writing-role guard used elsewhere in this file.
      AppZenithRecord.connected_to(role: :writing) { user_pref.update_column(:explicit_fields, nil) }
      user_pref.reload
      @user.reload

      assert_predicate user_pref, :legacy_unknown_explicit_state?

      @adoption.send(:sync_preferences!, user_pref)

      user_pref.user_preference_language.reload
      user_pref.reload

      assert_equal ClientPreferenceLanguageOption::JA, user_pref.user_preference_language.option_id,
                   "a legacy principal value must never be overwritten merely because the browser has an " \
                   "explicit marker"
      assert_predicate user_pref, :legacy_unknown_explicit_state?,
                       "sync must not write to the principal side while it stays legacy, so the row stays legacy"
    end

    test "sync_preferences! leaves a legacy principal untouched even when the browser side is non-explicit too" do
      user_pref = create_user_preference!(@user)
      AppZenithRecord.connected_to(role: :writing) { user_pref.update_column(:explicit_fields, nil) }
      user_pref.reload
      @user.reload

      @adoption.send(:sync_preferences!, user_pref)

      user_pref.user_preference_language.reload

      assert_equal ClientPreferenceLanguageOption::JA, user_pref.user_preference_language.option_id
      assert_predicate user_pref.reload, :legacy_unknown_explicit_state?
    end

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

    test "sync_preferences! forces r18 stopper through canonical age calculation for underage resource" do
      @user.update!(birthdate: "2012-02-29")
      user_pref = create_user_preference!(@user)

      travel_to Time.zone.local(2030, 2, 27, 12, 0, 0) do
        @adoption.send(:sync_preferences!, user_pref)
      end

      assert_equal "deny", @preference.reload.adult_content_gate
      assert_equal "deny", user_pref.reload.adult_content_gate
    end

    test "adoption helpers handle theme codes, snapshot source detection, and prefixes" do
      assert_equal "li", @adoption.send(:preference_theme_short_code, "light")
      assert_equal "dr", @adoption.send(:preference_theme_short_code, "DR")
      assert_equal "sy", @adoption.send(:preference_theme_short_code, "system")
      assert_nil @adoption.send(:preference_theme_short_code, nil)

      direct = AdoptionSnapshotPreference.new("en", "us", "Etc/UTC", "dr")
      associated = Object.new

      assert @adoption.send(:local_preference_snapshot_source?, direct)
      assert_not @adoption.send(:local_preference_snapshot_source?, associated)

      client_pref = ClientPreference.new
      operator_pref = OperatorPreference.new
      visitor_pref = VisitorPreference.new

      assert_equal "user_preference", @adoption.send(:preference_child_association_prefix, client_pref)
      assert_equal "staff_preference", @adoption.send(:preference_child_association_prefix, operator_pref)
      assert_equal "visitor_preference", @adoption.send(:preference_child_association_prefix, visitor_pref)
      assert_equal "adoption_fallback_preference",
                   @adoption.send(:preference_child_association_prefix, AdoptionFallbackPreference.new)
      assert_equal "Client", @adoption.send(:resource_pref_prefix)
      assert_equal [ClientPreference, :user_id], @adoption.send(:resource_preference_mapping)

      org_adoption = build_adoption_context(@preference, preference_class_name: "OrgPreference")

      assert_equal "Operator", org_adoption.send(:resource_pref_prefix)
      assert_equal [OperatorPreference, :staff_id], org_adoption.send(:resource_preference_mapping)

      com_adoption = build_adoption_context(@preference, preference_class_name: "ComPreference")

      assert_equal "Visitor", com_adoption.send(:resource_pref_prefix)
      assert_equal [VisitorPreference, :visitor_id], com_adoption.send(:resource_preference_mapping)

      yielded = false
      result =
        @adoption.send(:with_preference_writing_connection, nil) do
          yielded = true
          :ok
        end

      assert_equal :ok, result
      assert yielded
    end

    test "adopt_preference_for! does not raise on error and logs event" do
      adoption = build_adoption_context(@preference)
      adoption.define_singleton_method(:adoptable_preference_class?) { raise StandardError, "boom" }

      logged = []

      Rails.logger.stub(:info, ->(message) { logged << JSON.parse(message, symbolize_names: true) }) do
        assert_nothing_raised do
          adoption.send(:adopt_preference_for!, @user)
        end
      end

      assert_equal 1, logged.size, "Expected adoption error event to be logged"
      assert_equal "preference.adoption.error", logged.first[:event]
      assert_equal "StandardError", logged.first[:data][:error]
    end

    test "adopt_preference_for! is no-op when resource is blank" do
      assert_no_difference "ClientPreference.count" do
        @adoption.send(:adopt_preference_for!, nil)
      end
    end

    # --- adopt_rotated_preference! ---

    test "adopt_rotated_preference! syncs values to existing ClientPreference" do
      user_pref = create_user_preference!(@user)
      @user.reload

      create_child_record!(@new_preference, :language, AppPreferenceLanguageOption::EN)

      @adoption.send(:adopt_rotated_preference!, @user, @new_preference)

      user_pref.user_preference_language.reload

      assert_equal ClientPreferenceLanguageOption::EN, user_pref.user_preference_language.option_id
    end

    test "adopt_rotated_preference! does not raise on error and logs event" do
      adoption = build_adoption_context(@preference)
      adoption.define_singleton_method(:adoptable_preference_class?) { raise StandardError, "boom" }

      logged = []

      Rails.logger.stub(:info, ->(message) { logged << JSON.parse(message, symbolize_names: true) }) do
        assert_nothing_raised do
          adoption.send(:adopt_rotated_preference!, @user, @new_preference)
        end
      end

      assert_equal 1, logged.size, "Expected adoption rotation error event to be logged"
      assert_equal "preference.adoption.rotation_error", logged.first[:event]
      assert_equal "StandardError", logged.first[:data][:error]
    end

    test "adopt_rotated_preference! is no-op when resource is blank" do
      assert_no_difference "ClientPreference.count" do
        @adoption.send(:adopt_rotated_preference!, nil, @new_preference)
      end
    end

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

    def create_child_record!(preference, type, option_id)
      klass = {
        language: AppPreferenceLanguage,
        timezone: AppPreferenceTimezone,
        region: AppPreferenceRegion,
        theme: AppPreferenceTheme,
      }.fetch(type)
      record = klass.find_or_initialize_by(preference_id: preference.id)
      record.update!(option_id: option_id)
      record
    end
  end
end

module Preference
  class AdoptionTest
    test "adoption guards and fallback resolvers reject incomplete collaborators" do
      assert_nothing_raised { @adoption.send(:adopt_preference_for!, nil) }
      assert_nil @adoption.send(:preference_child_for, nil, :language, "App")
      assert_nil @adoption.send(:preference_child_for, Object.new, :language, "App")
      @adoption.define_singleton_method(:preference_class) { Class.new }

      assert_nil @adoption.send(:create_resource_preference!, Object.new)
      assert_nil @adoption.send(:preference_consent_snapshot, nil)
      assert_nil @adoption.send(:preference_consent_snapshot, Object.new)
      assert_nothing_raised { @adoption.send(:sync_explicit_state!, Object.new, :language, true) }
      assert_nothing_raised { @adoption.send(:force_underage_r18_stopper!, Object.new) }
    end

    test "adoption option resolution preserves source ids when metadata is absent" do
      child = Object.new
      child.define_singleton_method(:option_id) { 42 }
      child.define_singleton_method(:option) { nil }

      assert_equal 42, @adoption.send(:resolve_cross_db_option_id, child, Object)

      option = Object.new
      option.define_singleton_method(:name) { nil }
      child.define_singleton_method(:option) { option }

      assert_equal 42, @adoption.send(:resolve_cross_db_option_id, child, Object)

      target = Object.new
      assert_nothing_raised { @adoption.send(:copy_flat_preference_values!, Object.new, target) }
      assert_nothing_raised { @adoption.send(:apply_consent_snapshot!, target, {}) }
    end

    test "adoption reconciliation handles a blank consent snapshot" do
      @adoption.define_singleton_method(:preference_consent_snapshot) { |_preference| nil }
      assert_nothing_raised { @adoption.send(:reconcile_cookie_consent!, Object.new) }
      @adoption.define_singleton_method(:preference_resource_for) { |_preference| nil }
      assert_nothing_raised { @adoption.send(:force_underage_r18_stopper!, Object.new) }
    end
  end
end
