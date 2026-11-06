# typed: false
# frozen_string_literal: true

require "test_helper"

# Every Preference child requires its parent. A writer that passes only the foreign key makes each
# child's validation select the same parent row again. These requests run under an explicit scan
# because the suite does not scan ordinary requests.
class PreferenceRealmWriteNPlusOneTest < ActionDispatch::IntegrationTest
  test "the first app region write creates its children without an N+1 on the parent" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")

    assert_difference -> { AppPreference.count }, 1 do
      scanned_patch(base_app_preference_region_path(ri: "jp"), :preference_region, AppPreferenceRegionOption::US)
    end
  end

  test "a later app region write updates its children without an N+1 on the parent" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    https!
    patch base_app_preference_region_path(ri: "jp"),
          params: { preference_region: { option_id: AppPreferenceRegionOption::US } }

    assert_no_difference -> { AppPreference.count } do
      scanned_patch(base_app_preference_region_path(ri: "jp"), :preference_region, AppPreferenceRegionOption::JP)
    end
  end

  test "the first org region write creates its children without an N+1 on the parent" do
    host! ENV.fetch("PRIVATE_BASE_STAFF_URL")

    assert_difference -> { OrgPreference.count }, 1 do
      scanned_patch(base_org_preference_region_path(ri: "jp"), :preference_region, OrgPreferenceRegionOption::US)
    end
  end

  test "a later org region write updates its children without an N+1 on the parent" do
    host! ENV.fetch("PRIVATE_BASE_STAFF_URL")
    https!
    patch base_org_preference_region_path(ri: "jp"),
          params: { preference_region: { option_id: OrgPreferenceRegionOption::US } }

    assert_no_difference -> { OrgPreference.count } do
      scanned_patch(base_org_preference_region_path(ri: "jp"), :preference_region, OrgPreferenceRegionOption::JP)
    end
  end

  private

  def scanned_patch(path, scope, option_id)
    Prosopite.pause do
      assert_nothing_raised do
        Prosopite.scan do
          patch(path, params: { scope => { option_id: option_id } })
        end
      end
    end

    assert_response :redirect
  ensure
    Prosopite.pause do
      Prosopite.tc[:prosopite_query_counter] = Hash.new(0)
      Prosopite.tc[:prosopite_query_holder] = Hash.new { |holder, key| holder[key] = [] }
      Prosopite.tc[:prosopite_query_caller] = {}
    end
  end
end
