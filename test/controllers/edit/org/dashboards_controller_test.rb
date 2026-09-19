# frozen_string_literal: true

require "test_helper"

class Edit::Org::DashboardsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("PUBLIC_EDIT_STAFF_URL", "edit.org.localhost")
    host! @host
    @staff = operators(:one)
    @staff_headers = as_staff_headers(@staff, host: @host)
  end

  test "shows a link to each publishing cell for a signed-in operator" do
    get edit_org_dashboard_path(ri: "jp"), headers: @staff_headers

    assert_response :success
    assert_select "a[href=?]", edit_org_publishing_docs_app_entries_path(ri: "jp")
    assert_select "a[href=?]", edit_org_publishing_help_org_entries_path(ri: "jp")
    assert_select "a[href=?]", edit_org_publishing_info_com_entries_path(ri: "jp")
    assert_select "a[href=?]", edit_org_publishing_news_app_entries_path(ri: "jp")
  end

  test "an unauthenticated request cannot reach the dashboard" do
    get edit_org_dashboard_path

    assert_response :redirect
  end
end
