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

  # The protected page is not a second Sign entry: it points the browser at the passive GET /sign and
  # starts no OIDC flow itself (plans/active/sign-fqdn-integrated-plan.md section 5).
  test "an unauthenticated HTML request is sent to the passive sign entry without starting a flow" do
    get edit_org_dashboard_path(ri: "jp")

    assert_response :redirect
    location = URI.parse(response.location)

    assert_equal @host, location.host
    assert_equal edit_org_sign_show_path, location.path
    assert_equal edit_org_dashboard_path(ri: "jp"), Rack::Utils.parse_nested_query(location.query).fetch("pt")
    assert_nil session["oidc_pending_flows"]
  end

  test "an unauthenticated JSON request keeps the 401 without a redirect" do
    get edit_org_dashboard_path(ri: "jp", format: :json)

    assert_response :unauthorized
    assert_nil response.location
    assert_nil session["oidc_pending_flows"]
  end
end
