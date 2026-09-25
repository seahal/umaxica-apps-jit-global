# typed: false
# frozen_string_literal: true

require "test_helper"

# A signed-in principal's preference change is written to the browser preference and mirrored to
# the principal's own account preference in the same operation, so the choice follows the
# principal to the next device. Anonymous browsers only change the browser preference.
class PreferenceSignedInDualWriteTest < ActionDispatch::IntegrationTest
  fixtures :clients, :operators, :visitors

  test "a signed-in client's region change is mirrored to the account preference with its regional defaults" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    client = clients(:one)
    headers = as_user_headers(client, host: host)
    get base_app_preference_path(ri: "jp"), headers: headers

    assert_response :success

    patch base_app_preference_region_path(ri: "jp"),
          params: { preference_region: { option_id: "US" } }, headers: headers

    assert_response :redirect
    account = ClientPreference.find_by!(user_id: client.id)

    assert_equal ClientPreferenceRegionOption::US, account.user_preference_region.option_id
    assert_equal ClientPreferenceLanguageOption::EN, account.user_preference_language.option_id
  end

  test "an anonymous region change leaves no account preference behind" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    get base_app_preference_path(ri: "jp")

    assert_response :success

    assert_no_difference("ClientPreference.count") do
      patch base_app_preference_region_path(ri: "jp"), params: { preference_region: { option_id: "US" } }
    end

    assert_equal AppPreferenceRegionOption::US,
                 AppPreference.order(:created_at).last.app_preference_region.option_id
  end

  test "a signed-in operator's and visitor's region changes are mirrored to their own account preferences" do
    [
      [ENV.fetch("PUBLIC_BASE_STAFF_URL"), operators(:one), :as_staff_headers, :base_org_preference_path,
       :base_org_preference_region_path, OperatorPreference, :staff_id, :staff_preference_region,
       OperatorPreferenceRegionOption::US,],
      [ENV.fetch("PUBLIC_BASE_CORPORATE_URL"), visitors(:reserved_visitor), :as_visitor_headers,
       :base_com_preference_path, :base_com_preference_region_path, VisitorPreference, :visitor_id,
       :visitor_preference_region,
       VisitorPreferenceRegionOption::US,],
    ].each do |host, actor, headers_method, page, region_path, account_class, fk, region_assoc, us|
      host! host
      headers = public_send(headers_method, actor, host: host)
      get public_send(page, ri: "jp"), headers: headers

      assert_response :success, account_class.name

      patch public_send(region_path, ri: "jp"), params: { preference_region: { option_id: "US" } }, headers: headers

      assert_response :redirect, account_class.name
      account_class.connection_class_for_self.connected_to(role: :writing) do
        account = account_class.find_by!(fk => actor.id)

        assert_equal us, account.public_send(region_assoc).option_id, account_class.name
      end
    end
  end
end
