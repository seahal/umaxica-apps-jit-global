# frozen_string_literal: true

require "test_helper"

# The chrome decides theme and cookie controls by family and surface, never by surface alone, and
# hands each control the same-origin endpoint its family serves. Palm shares the app surface with
# Core but serves no preference endpoint, which is how a surface-only decision rendered controls on
# Palm that called a route Palm does not have.
class SurfaceChromePreferenceControlsTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_preferences, :client_token_kinds

  PAGES = [
    { family: "core", surface: "app", host: ENV.fetch("PUBLIC_CORE_SERVICE_URL"), path: "/" },
    { family: "core", surface: "com", host: ENV.fetch("PUBLIC_CORE_CORPORATE_URL"), path: "/" },
    { family: "core", surface: "org", host: ENV.fetch("PUBLIC_CORE_STAFF_URL"), path: "/" },
    { family: "warp", surface: "app", host: ENV.fetch("PUBLIC_WARP_SERVICE_URL"), path: "/" },
    { family: "warp", surface: "com", host: ENV.fetch("PUBLIC_WARP_CORPORATE_URL"), path: "/" },
    { family: "warp", surface: "org", host: ENV.fetch("PUBLIC_WARP_STAFF_URL"), path: "/" },
    { family: "base", surface: "app", host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"), path: "/preference" },
    { family: "base", surface: "com", host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL"), path: "/preference" },
    { family: "base", surface: "org", host: ENV.fetch("PUBLIC_BASE_STAFF_URL"), path: "/preference" },
    { family: "auth", surface: "app", host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), path: "/sign/up/email/new" },
    { family: "auth", surface: "com", host: ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"), path: "/sign/up/email/new" },
  ].freeze

  test "families with a preference endpoint hand each control its same-origin endpoint" do
    PAGES.each do |page|
      expected = PreferenceBrowserControlsRegistry.fetch(family: page.fetch(:family), surface: page.fetch(:surface))
      host! page.fetch(:host)

      get page.fetch(:path), params: { ri: "jp" }

      label = "#{page.fetch(:family)}/#{page.fetch(:surface)}"

      assert_response :success, label
      chrome = inertia_props.fetch("chrome")

      assert_equal expected.theme_endpoint_path, chrome.dig("theme_controls", "endpoint_url"), label
      assert_equal expected.cookie_endpoint_path, chrome.dig("cookie_controls", "endpoint_url"), label
      assert_match %r{\A/(?!/)}, chrome.dig("theme_controls", "endpoint_url"), label
    end
  end

  test "core controls use the canonical api preferences endpoints" do
    host! ENV.fetch("PUBLIC_CORE_SERVICE_URL")

    get "/", params: { ri: "jp" }

    assert_response :success
    chrome = inertia_props.fetch("chrome")

    assert_equal "/api/v0/preferences/theme", chrome.dig("theme_controls", "endpoint_url")
    assert_equal "/api/v0/preferences/cookie", chrome.dig("cookie_controls", "endpoint_url")
  end

  test "palm app renders no theme or cookie controls even though it is an app surface" do
    host! ENV.fetch("PUBLIC_PALM_SERVICE_URL")

    get "/", params: { ri: "jp" }

    assert_response :success
    chrome = inertia_props.fetch("chrome")

    assert_equal "app", chrome.fetch("surface")
    assert chrome.key?("theme_controls")
    assert chrome.key?("cookie_controls")
    assert_nil chrome.fetch("theme_controls")
    assert_nil chrome.fetch("cookie_controls")
    assert_not_includes response.body, "/web/v0/"
  end
end
