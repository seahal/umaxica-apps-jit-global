# frozen_string_literal: true

require "test_helper"

# The chrome decides Preference controls by family and surface, never by surface alone. Base owns
# browser writes; Auth, Core, and Warp remain display readers without interactive control routes.
class SurfaceChromePreferenceControlsTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_preferences, :client_token_kinds

  PAGES = [
    { family: "core", surface: "app", host: ENV.fetch("PUBLIC_CORE_SERVICE_URL"), path: "/" },
    { family: "core", surface: "org", host: ENV.fetch("PUBLIC_CORE_STAFF_URL"), path: "/" },
    { family: "warp", surface: "app", host: ENV.fetch("PUBLIC_WARP_SERVICE_URL"), path: "/" },
    { family: "warp", surface: "org", host: ENV.fetch("PUBLIC_WARP_STAFF_URL"), path: "/" },
    { family: "base", surface: "app", host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"), path: "/preference" },
    { family: "base", surface: "com", host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL"), path: "/preference" },
    { family: "base", surface: "org", host: ENV.fetch("PUBLIC_BASE_STAFF_URL"), path: "/preference" },
    { family: "auth", surface: "app", host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), path: "/sign/up/email/new" },
  ].freeze

  test "page chrome exposes browser write endpoints only to Base" do
    PAGES.each do |page|
      expected = PreferenceBrowserControlsRegistry.fetch(family: page.fetch(:family), surface: page.fetch(:surface))
      host! page.fetch(:host)

      if page.fetch(:family) == "auth"
        begin
          admission_browser = self
          admission_surface = page.fetch(:surface)
          admission_intent = "sign_up"
          admission_host = {
            "app" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
            "com" => ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
            "org" => ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
          }.fetch(admission_surface)
          admission_browser.host!(admission_host)
          admission_issuance = OidcTestEntry.issue!(
            surface: admission_surface, intent: admission_intent,
            base_browser_nonce: SecureRandom.hex(32), base_token: nil,
          )
          admission_path = "/sign/#{(admission_intent == "sign_up") ? "up" : "in"}"
          admission_browser.get(
            admission_path,
            params: { entry_ref: admission_issuance.reference, ri: "jp" },
          )
          admission_csrf = admission_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
          admission_browser.post(
            "/ceremony_bindings",
            params: { entry_ref: admission_issuance.reference, authenticity_token: admission_csrf, ri: "jp" },
          )

          assert_equal 303, admission_browser.response.status
          admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
            surface: admission_surface, reference: admission_issuance.reference,
          )
          admission_binding.reload.confirm_base!(
            base_token: nil,
            browser_digest: admission_binding.base_browser_digest,
          )
          admission_browser.get(
            admission_path,
            params: { entry_ref: admission_issuance.reference, ri: "jp" },
          )
          admission_csrf = admission_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
          admission_browser.post(
            admission_path,
            params: { entry_ref: admission_issuance.reference, authenticity_token: admission_csrf, ri: "jp" },
          )

          assert_equal 303, admission_browser.response.status
        end
      end
      get page.fetch(:path), params: { ri: "jp" }

      label = "#{page.fetch(:family)}/#{page.fetch(:surface)}"

      assert_response :success, label
      chrome = inertia_props.fetch("chrome")

      assert_equal expected.theme_endpoint_path, chrome.dig("theme_controls", "endpoint_url"), label
      assert_equal expected.cookie_endpoint_path, chrome.dig("cookie_controls", "endpoint_url"), label
      if expected.theme_endpoint_path
        assert_match %r{\A/(?!/)}, chrome.dig("theme_controls", "endpoint_url"), label
        assert_match %r{\A/(?!/)}, chrome.dig("cookie_controls", "endpoint_url"), label
      end
    end
  end

  test "core receives no interactive Preference controls" do
    host! ENV.fetch("PUBLIC_CORE_SERVICE_URL")

    get "/", params: { ri: "jp" }

    assert_response :success
    chrome = inertia_props.fetch("chrome")

    assert_nil chrome.dig("theme_controls", "endpoint_url")
    assert_nil chrome.dig("cookie_controls", "endpoint_url")
  end

  # Warp com lost its browser preference endpoints with the rest of its credential surface. The
  # page chrome must say so explicitly rather than pointing at routes the host does not serve.
  test "warp com renders a read-only link to Base cookie settings" do
    host! ENV.fetch("PUBLIC_WARP_CORPORATE_URL")
    https!

    get "/", params: { ri: "jp" }

    assert_response :success
    chrome = inertia_props.fetch("chrome")

    assert_equal "com", chrome.fetch("surface")
    assert_nil chrome.fetch("theme_controls")
    cookie_controls = chrome.fetch("cookie_controls")

    assert_nil cookie_controls.fetch("endpoint_url")
    settings = URI.parse(cookie_controls.fetch("settings_url"))

    assert_equal ENV.fetch("PUBLIC_BASE_CORPORATE_URL"), settings.host
    assert_equal "/preference/cookie/edit", settings.path
    assert_equal "https", settings.scheme
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
