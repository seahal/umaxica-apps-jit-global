# typed: false
# frozen_string_literal: true

require "test_helper"

# The auth surfaces' browser preference JSON endpoints. Each surface owns its
# own theme and cookie controller over the shared PreferencesBaseController, so
# the read and the authorized write are asserted per surface.
class AuthApiV0PreferenceEndpointsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "app theme endpoint answers the current theme over TLS" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    https!
    host! host

    get auth_app_api_v0_preferences_theme_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :success
    assert_predicate response.parsed_body["theme"], :present?
  end

  test "com theme endpoint answers the current theme over TLS" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    https!
    host! host

    get auth_com_api_v0_preferences_theme_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :success
    assert_predicate response.parsed_body["theme"], :present?
  end

  test "org theme endpoint answers the current theme over TLS" do
    host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    https!
    host! host

    get auth_org_api_v0_preferences_theme_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :success
    assert_predicate response.parsed_body["theme"], :present?
  end

  test "app cookie endpoint answers whether the consent banner is still due" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    https!
    host! host

    get auth_app_api_v0_preferences_cookie_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :success
    assert_includes response.parsed_body.keys, "show_banner"
  end

  test "app theme write records the new theme for the browser session" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    https!
    host! host

    patch auth_app_api_v0_preferences_theme_url(ri: "jp", host: host), as: :json,
                                                                       params: { theme: "dr" },
                                                                       headers: { "Host" => host }

    assert_response :success

    get auth_app_api_v0_preferences_theme_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_equal "dr", response.parsed_body["theme"]
  end
end
