# typed: false
# frozen_string_literal: true

require "test_helper"

class Warp::Com::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_WARP_CORPORATE_URL")
  end

  test "show renders the surface's own settings page" do
    host! @host

    get warp_com_settings_path(ri: "jp")

    assert_response :success
    assert_equal "warp/com/settings/show", inertia_component
    assert_equal "Settings", inertia_props.fetch("heading")
    assert_equal I18n.t("ui_presentation.display_preferences_description"), inertia_props.fetch("description")
  end

  test "offers only the root and the Base com preference entry" do
    host! @host

    get warp_com_settings_path(ri: "jp")

    links = inertia_props.fetch("links")

    assert_equal ["Root", I18n.t("ui_presentation.navigation.preferences")], links.pluck("label")
    assert_equal warp_com_root_path(ri: "jp"), links.first.fetch("href")

    preference = URI.parse(links.last.fetch("href"))

    assert_equal ENV.fetch("PUBLIC_BASE_CORPORATE_URL"), preference.host
    assert_equal "/preference", preference.path
    assert_equal({ "ri" => "jp" }, Rack::Utils.parse_nested_query(preference.query))
  end

  test "describes display preferences in the selected language" do
    host! @host
    %w(en ja).each do |locale|
      get warp_com_settings_path(ri: "jp", lx: locale)

      assert_response :success
      assert_equal I18n.t("ui_presentation.display_preferences_description", locale: locale),
                   inertia_props.fetch("description")
    end
  end

  # The page is reachable from the anonymous landing, so it must not require a session.
  test "show renders for an anonymous visitor" do
    host! @host

    get warp_com_settings_path(ri: "jp")

    assert_response :success
  end

  test "show ignores credentials and offers no sign-out destination" do
    host! @host

    get warp_com_settings_url(ri: "jp"), headers: {
      "Cookie" => "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=injected-access-token",
    }

    assert_response :success
    assert_not_includes inertia_props.fetch("links").pluck("label"), "Sign out"
  end
end
