# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Preference
  class ClassRegistryTest < ActiveSupport::TestCase
    self.fixture_table_names = []

    test "resolves preference class from controller path" do
      assert_equal AppPreference, PreferenceClassRegistry.for_controller_path("core/app/edge/v0/preferences")
      assert_equal ComPreference, PreferenceClassRegistry.for_controller_path("core/com/edge/v0/preferences")
      assert_equal OrgPreference, PreferenceClassRegistry.for_controller_path("core/org/edge/v0/preferences")
    end

    test "resolves option classes by prefix and type" do
      assert_equal AppPreferenceLanguageOption, PreferenceClassRegistry.option_class("App", :language)
      assert_equal ComPreferenceRegionOption, PreferenceClassRegistry.option_class("Com", "Region")
      assert_equal OrgPreferenceTimezoneOption, PreferenceClassRegistry.option_class("Org", :timezone)
      assert_equal VisitorPreferenceThemeOption, PreferenceClassRegistry.option_class("Visitor", :theme)
    end

    test "resolves status and audit classes from preference class" do
      assert_equal AppPreferenceStatus, PreferenceClassRegistry.status_class_for(AppPreference)
      assert_equal ComPreferenceChronicle, PreferenceClassRegistry.audit_class_for(ComPreference)
      assert_equal OrgPreferenceChronicleEvent, PreferenceClassRegistry.audit_event_class_for(OrgPreference)
    end

    test "resolves a named preference audit event to its fixed id" do
      assert_equal AppPreferenceChronicleEvent::UPDATE_PREFERENCE_LANGUAGE,
                   PreferenceClassRegistry.audit_event_id_for(
                     AppPreferenceChronicleEvent,
                     "UPDATE_PREFERENCE_LANGUAGE",
                   )
    end

    test "rejects an unknown preference audit event name instead of writing event id 0" do
      error =
        assert_raises(ArgumentError) do
          PreferenceClassRegistry.audit_event_id_for(
            AppPreferenceChronicleEvent,
            "PREFERENCE_LANGUAGE_UPDATED",
          )
        end

      assert_match(/unknown preference audit event/, error.message)
    end
  end
end
