# frozen_string_literal: true

require "test_helper"

class Edit::Org::RootsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    host! ENV.fetch("PUBLIC_EDIT_STAFF_URL")
  end

  test "anonymous landing provides publishing sign in and base registration entry with region" do
    get edit_org_root_path(ri: "jp")

    assert_response :success
    assert_select "main#main h1", text: "UMAXICA Edit"
    assert_select "nav[aria-label='Authentication'] a[href=?]", edit_org_dashboard_path(ri: "jp"), text: "Sign in"
    assert_select "nav[aria-label='Authentication'] a[href=?]",
                  base_org_root_url(host: ENV.fetch("PUBLIC_BASE_STAFF_URL"), ri: "jp"), text: "Sign up"
    assert_select "html[lang='ja']"
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end

  test "landing settings link uses the base org authority" do
    get edit_org_root_path(ri: "jp")

    assert_response :success
    assert_select "footer a[href=?]",
                  base_org_preference_url(host: ENV.fetch("PUBLIC_BASE_STAFF_URL"), ri: "jp")
  end

  test "signed in operator sees the publishing dashboard entry without registration" do
    host = ENV.fetch("PUBLIC_EDIT_STAFF_URL")
    get edit_org_root_path(ri: "jp"), headers: as_staff_headers(operators(:one), host: host)

    assert_response :success
    assert_select "nav[aria-label='Authentication'] a[href=?]", edit_org_dashboard_path(ri: "jp"), text: "Publishing"
    assert_select "nav[aria-label='Authentication'] a", count: 1
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end
end
