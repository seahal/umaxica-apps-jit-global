# typed: false
# frozen_string_literal: true

require "test_helper"

# The Auth surfaces expose read-only browser Preference JSON endpoints. Base is the sole
# interactive browser writer; these routes continue to serve verified display state and refuse
# mutations.
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

  test "app theme mutation is refused without creating Preference state" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    https!
    host! host
    preference_count = AppPreference.count

    patch auth_app_api_v0_preferences_theme_url(ri: "jp", host: host), as: :json,
                                                                       params: { theme: "dr" },
                                                                       headers: { "Host" => host }

    assert_response :forbidden
    assert_equal preference_count, AppPreference.count
    assert_nil response.headers["Set-Cookie"]
  end
end
