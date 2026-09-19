# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignAppLayoutTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses

  def default_headers
    { "Host" => ENV["PRIVATE_AUTH_SERVICE_URL"] || "id.app.localhost" }
  end

  def login_headers(user)
    default_headers.merge("X-TEST-CURRENT-USER" => user.id.to_s)
  end

  test "the shared auth header exposes no sign-in or sign-up navigation" do
    get new_auth_app_sign_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success

    chrome = inertia_props.fetch("chrome")

    # Auth pages are themselves the sign-in / sign-up surface. A header link back to those flows
    # forces the shared template to detect login state just to choose between "Sign in" and "Sign
    # up", which this surface should not have to do. Links a specific ceremony genuinely needs
    # belong in that page's own body, not the shared chrome.
    assert_not chrome.key?("primary_navigation"), "the auth chrome must not carry primary navigation"

    footer_hrefs = Array(chrome["footer_navigation"]).map { |link| link.fetch("href") }

    assert_empty footer_hrefs.grep(%r{/sign/in\b}), "auth footer must not link the sign-in flow"
    assert_empty footer_hrefs.grep(%r{/sign/up\b}), "auth footer must not link the sign-up flow"
  end

  test "cookie banner settings url is the base cookie preference edit" do
    get new_auth_app_sign_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success

    settings_url = inertia_props.dig("chrome", "cookie_controls", "settings_url")
    uri = URI.parse(settings_url)
    query_keys = uri.query.to_s.split("&").map { |pair| pair.split("=", 2).first }

    assert_equal "/preference/cookie/edit", uri.path
    assert_equal "jp", Rack::Utils.parse_query(uri.query).fetch("ri")
    assert_equal query_keys.uniq, query_keys
    assert_not_equal URI.parse("http://#{default_headers.fetch("Host")}").host, uri.host
  end
end
