# typed: false
# frozen_string_literal: true

require "test_helper"

# Creating a preference writes rows that reference fixed-id lookup tables (status, audit
# level, audit event, binding method, DBSC status). When a lookup row is missing, the
# first request that creates a preference restores it instead of failing on a foreign key.
class PreferenceReferenceDefaultsRecoveryTest < ActionDispatch::IntegrationTest
  teardown do
    ApplicationRecord.clear_fixed_id_seed_cache!
  end

  test "an app preference write restores a missing audit level and records its audit entry" do
    AppPreferenceChronicle.delete_all
    AppPreferenceChronicleLevel.where(id: AppPreferenceChronicleLevel::INFO).delete_all
    ApplicationRecord.clear_fixed_id_seed_cache!

    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    patch base_app_preference_region_path(ri: "jp"),
          params: { preference_region: { option_id: AppPreferenceRegionOption::US } }

    assert_response :redirect
    assert AppPreferenceChronicleLevel.exists?(id: AppPreferenceChronicleLevel::INFO)
    assert_predicate AppPreference.order(:created_at).last, :present?
  end

  test "an org preference write restores a missing audit level on the audit writer" do
    OrgPreferenceChronicle.delete_all
    OrgPreferenceChronicleLevel.where(id: OrgPreferenceChronicleLevel::INFO).delete_all
    ApplicationRecord.clear_fixed_id_seed_cache!

    host! ENV.fetch("PRIVATE_BASE_STAFF_URL")
    patch base_org_preference_region_path(ri: "jp"),
          params: { preference_region: { option_id: OrgPreferenceRegionOption::US } }

    assert_response :redirect
    assert OrgPreferenceChronicleLevel.exists?(id: OrgPreferenceChronicleLevel::INFO)
  end
end
