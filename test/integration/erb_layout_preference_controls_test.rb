# frozen_string_literal: true

require "test_helper"

# The ERB application layouts of Base and Auth derive Preference control endpoints from the
# registry. Read-only Auth layouts receive no write endpoint, so browser code cannot choose one.
class ErbLayoutPreferenceControlsTest < ActiveSupport::TestCase
  LAYOUTS = [
    { family: "base", surface: "app", controller: Base::App::ApplicationController, host: "PUBLIC_BASE_SERVICE_URL" },
    { family: "base", surface: "org", controller: Base::Org::ApplicationController, host: "PUBLIC_BASE_STAFF_URL" },
    { family: "auth", surface: "app", controller: Auth::App::ApplicationController, host: "PUBLIC_AUTH_SERVICE_URL" },
    { family: "auth", surface: "org", controller: Auth::Org::ApplicationController, host: "PUBLIC_AUTH_STAFF_URL" },
  ].freeze

  test "Base layouts render controls and read-only Auth layouts omit them" do
    LAYOUTS.each do |layout|
      family = layout.fetch(:family)
      surface = layout.fetch(:surface)
      expected = PreferenceBrowserControlsRegistry.fetch(family: family, surface: surface)
      html = layout.fetch(:controller).renderer.new("HTTP_HOST" => ENV.fetch(layout.fetch(:host)))
        .render(inline: "", layout: "#{family}/#{surface}/application")
      document = Nokogiri::HTML(html)

      theme = document.at_css("[data-controller='theme']")
      banner = document.at_css("[data-controller='cookie-banner']")

      if expected.theme_endpoint_path.nil? && expected.cookie_endpoint_path.nil?
        assert_nil theme, "#{family}/#{surface} theme control"
        assert_nil banner, "#{family}/#{surface} cookie control"
        next
      end

      assert_equal expected.theme_endpoint_path, theme["data-theme-endpoint-url-value"], "#{family}/#{surface}"
      assert_equal expected.cookie_endpoint_path, banner["data-cookie-banner-endpoint-url-value"],
                   "#{family}/#{surface}"
    end
  end
end
