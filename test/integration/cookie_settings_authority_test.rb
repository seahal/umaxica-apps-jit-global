# frozen_string_literal: true

require "test_helper"

class CookieSettingsAuthorityTest < ActionDispatch::IntegrationTest
  test "warp cookie settings links use each surface base authority and preserve only preference queries" do
    [
      [ENV.fetch("PUBLIC_WARP_SERVICE_URL"), ENV.fetch("PUBLIC_BASE_SERVICE_URL")],
      [ENV.fetch("PUBLIC_WARP_CORPORATE_URL"), ENV.fetch("PUBLIC_BASE_CORPORATE_URL")],
      [ENV.fetch("PUBLIC_WARP_STAFF_URL"), ENV.fetch("PUBLIC_BASE_STAFF_URL")],
    ].each do |source_host, base_host|
      host! source_host
      get "/", params: { ri: "jp", lx: "ja", query: "" }

      assert_response :success
      page = response.parsed_body.at_css("script[data-page='app']")
      props = JSON.parse(page.text).fetch("props")
      uri = URI.parse(props.dig("chrome", "cookie_controls", "settings_url"))

      assert_equal base_host, uri.host
      assert_equal "/preference/cookie/edit", uri.path
      assert_equal "http", uri.scheme
      assert_equal({ "ri" => "jp", "lx" => "ja" }, Rack::Utils.parse_query(uri.query))
    end
  end
end
