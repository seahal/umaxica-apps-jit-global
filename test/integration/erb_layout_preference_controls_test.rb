# frozen_string_literal: true

require "test_helper"

# The ERB application layouts of Base and Auth render the Stimulus theme and cookie controls. Like
# the Inertia chrome, they take the endpoint from PreferenceBrowserControlsRegistry and pass it to
# the controllers as a data value, so the browser never chooses the path.
class ErbLayoutPreferenceControlsTest < ActiveSupport::TestCase
  LAYOUTS = [
    { family: "base", surface: "app", controller: Base::App::ApplicationController, host: "PUBLIC_BASE_SERVICE_URL" },
    { family: "base", surface: "com", controller: Base::Com::ApplicationController, host: "PUBLIC_BASE_CORPORATE_URL" },
    { family: "base", surface: "org", controller: Base::Org::ApplicationController, host: "PUBLIC_BASE_STAFF_URL" },
    { family: "auth", surface: "app", controller: Auth::App::ApplicationController, host: "PUBLIC_AUTH_SERVICE_URL" },
    { family: "auth", surface: "com", controller: Auth::Com::ApplicationController, host: "PUBLIC_AUTH_CORPORATE_URL" },
    { family: "auth", surface: "org", controller: Auth::Org::ApplicationController, host: "PUBLIC_AUTH_STAFF_URL" },
  ].freeze

  test "each layout declares its family endpoints on the theme and cookie-banner controllers" do
    LAYOUTS.each do |layout|
      family = layout.fetch(:family)
      surface = layout.fetch(:surface)
      expected = PreferenceBrowserControlsRegistry.fetch(family: family, surface: surface)
      html = layout.fetch(:controller).renderer.new("HTTP_HOST" => ENV.fetch(layout.fetch(:host)))
        .render(inline: "", layout: "#{family}/#{surface}/application")
      document = Nokogiri::HTML(html)

      theme = document.at_css("[data-controller='theme']")
      banner = document.at_css("[data-controller='cookie-banner']")

      assert_equal expected.theme_endpoint_path, theme["data-theme-endpoint-url-value"], "#{family}/#{surface}"
      assert_equal expected.cookie_endpoint_path, banner["data-cookie-banner-endpoint-url-value"],
                   "#{family}/#{surface}"
    end
  end
end
