# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
# require "helpers/root_theme_cookie_helper"

class Auth::Org::RootsControllerTest < ActionDispatch::IntegrationTest
  BRAND = ENV.fetch("BRAND_NAME").upcase

  fixtures :operators, :operator_statuses

  # include RootThemeCookieHelper

  setup do
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
  end

  test "renders the ceremony-service root for the jp region" do
    get auth_org_root_url(ri: "jp")

    assert_response :success
    assert_equal "auth/org/roots/index", inertia_component
    assert_equal "Sign Org", inertia_props.fetch("heading")
    assert_equal base_sign_entry_url(ri: "jp"), inertia_props.fetch("sign_in").fetch("href")
  end

  test "renders the ceremony-service root for the us region" do
    get auth_org_root_url(ri: "us")

    assert_response :success
    assert_equal "auth/org/roots/index", inertia_component
    assert_equal base_sign_entry_url(ri: "us"), inertia_props.fetch("sign_in").fetch("href")
  end

  test "an unrecognized region falls through to the shared region normalization" do
    get auth_org_root_url(ri: "xx")

    assert_response :found
    assert_equal auth_org_root_url(ri: "jp"), response.location
  end

  test "the ceremony-service root terminates the redirect chain for both regions" do
    %w(jp us).each do |region|
      get auth_org_root_url(ri: region)

      assert_response :success, "the #{region} ceremony-service root must not redirect again"
    end
  end

  test "an auth ceremony cookie does not turn Root into a dashboard" do
    staff = operators(:one)

    get auth_org_root_url(ri: "jp"),
        headers: as_staff_headers(staff, host: ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost"))

    assert_response :success
    assert_equal "auth/org/roots/index", inertia_component
  end
  private

  # The landing link leaves Auth for the Base neutral GET /sign entry; Auth's own /sign/in refuses a
  # request that carries no Base-issued admission.
  def base_sign_entry_url(ri:)
    base_org_sign_show_url(
      ri: ri, host: Rails.configuration.x.boot_config.fetch(:hosts).base_staff.host, protocol: "https",
    )
  end

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = "test_csrf_token"
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "X-CSRF-Token" => csrf_token,
    }

    if respond_to?(:cookies, true)
      cookies["csrf_token"] = csrf_token
    else
      headers["Cookie"] = "csrf_token=#{csrf_token}"
    end

    headers
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "AUTH")
    surface =
      if service == "AUTH"
        case resource_type
        when "operator" then "ORG"
        when "visitor" then "COM"
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      elsif normalized.include?(".com") || normalized.include?("com.")
        "COM"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
  end

  private

  def stub_cookie(theme)
    cookies[:root_theme] = theme
  end

  def assert_theme_cookie_for(theme, path:, expected: theme)
    stub_cookie(theme)

    get(path)

    assert_response :success
    assert_equal expected, cookies[PreferenceBase::THEME_COOKIE_KEY]
  end
end

# DAMP auth header helpers for this test class.
class Auth::Org::RootsControllerTest
  private
end
