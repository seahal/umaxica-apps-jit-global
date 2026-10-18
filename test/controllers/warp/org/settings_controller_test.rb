# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Warp::Org::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_WARP_STAFF_URL")
  end

  test "show renders the surface's own settings page" do
    host! @host

    get warp_org_settings_path(ri: "jp")

    assert_response :success
    assert_equal "warp/org/settings/show", inertia_component
    assert_equal "Settings", inertia_props.fetch("heading")
    assert_match(/Warp org control-plane settings/, inertia_props.fetch("description"))
  end

  test "show links back to the surface's own screens and to nothing else" do
    host! @host

    get warp_org_settings_path(ri: "jp")

    assert_equal(
      [
        ["Root", warp_org_dashboard_path(ri: "jp")],
        ["Sign out", new_warp_org_sign_out_path(ri: "jp")],
      ],
      inertia_props.fetch("links").map { |link| [link.fetch("label"), link.fetch("href")] },
    )
  end

  # The page is reachable from the anonymous landing, so it must not require a session.
  test "show renders for an anonymous visitor" do
    host! @host

    get warp_org_settings_path(ri: "jp")

    assert_response :success
  end
end
