# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "sha3"

# Regression tests for security-sensitive paths around
# www.umaxica.{app,com,org}/preference (the acme preference authority).
#
# These tests pin the security invariants surfaced during the May 2026
# review: preference refresh tokens must stay in HttpOnly cookies, timezone
# updates must reject non-IANA strings, and pt= redirect parameters must
# never be allowed to escape the current host.
class PreferenceSecurityTest < ActionDispatch::IntegrationTest
  setup do
    https!
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
  end

  COOKIE_NAME = -> { PreferenceCookieName.refresh(production: false, surface: :app) }

  test "refresh_token URL parameter cannot replace the HttpOnly cookie" do
    # The explicit preference write establishes a refresh cookie; a read-only GET
    # must ignore a token supplied only as a query parameter.
    patch base_app_preference_region_url(ri: "jp"),
          params: { preference_region: { option_id: "JP" } }

    assert_response :redirect
    legitimate_token = cookies[COOKIE_NAME.call]

    assert_not_nil legitimate_token

    # Switch session and try to ride a stolen refresh token through ?refresh_token=.
    reset!
    https!
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    preference_count = AppPreference.count
    get edit_base_app_preference_region_url(ri: "jp", refresh_token: legitimate_token)

    assert_response :success
    assert_equal preference_count, AppPreference.count
    assert_nil cookies[COOKIE_NAME.call], "a URL token must not be adopted as an HttpOnly cookie"
  end

  test "timezone update rejects unknown raw strings even with a slash" do
    get edit_base_app_preference_timezone_url(ri: "jp")

    assert_response :success

    patch base_app_preference_timezone_url(ri: "jp"),
          params: { preference_timezone: { option_id: "../etc/passwd" } }

    # Invalid input is routed through PreferenceOperationError and redirects
    # back without writing to session/cookie or using Rails flash.
    assert_redirected_to edit_base_app_preference_timezone_url(ri: "jp")
    assert_empty flash.to_hash

    follow_redirect!

    timezone_cookie = cookies[PreferenceBase::TIMEZONE_COOKIE_KEY]

    assert_not_equal "../etc/passwd", timezone_cookie
  end

  test "theme update pt redirect refuses absolute URLs and protocol-relative paths" do
    get edit_base_app_preference_theme_url(ri: "jp")

    assert_response :success

    [
      "https://evil.example/pwn",
      "//evil.example/pwn",
      "/\\evil.example/pwn",
    ].each do |hostile_pt|
      patch base_app_preference_theme_url(ri: "jp", pt: hostile_pt),
            params: { preference_theme: { option_id: "dr" } }

      assert_response :redirect,
                      "theme update should still redirect for pt=#{hostile_pt.inspect}"
      location = response.headers["Location"].to_s

      assert_no_match(
        /evil\.example/, location,
        "theme update must not redirect to external host (pt=#{hostile_pt.inspect})",
      )
    end
  end

  test "internal pt path is preserved when safe" do
    get edit_base_app_preference_theme_url(ri: "jp")

    assert_response :success

    patch base_app_preference_theme_url(ri: "jp", pt: "/preference?ri=jp"),
          params: { preference_theme: { option_id: "dr" } }

    assert_response :redirect
    assert_includes response.headers["Location"], "/preference"
  end

  test "a preference refresh cookie issued on app is inert on the com host" do
    patch base_app_preference_region_url(ri: "jp"),
          params: { preference_region: { option_id: "JP" } }

    assert_response :redirect

    app_refresh_token = cookies[COOKIE_NAME.call]

    assert_not_nil app_refresh_token

    com_count_before = ComPreference.count

    reset!
    https!
    host! ENV.fetch("PRIVATE_BASE_CORPORATE_URL", "base.com.localhost")
    cookies[PreferenceCookieName.refresh(production: false, surface: :com)] = app_refresh_token

    get edit_base_com_preference_theme_url(ri: "jp")

    # The cross-surface credential is detached and cannot resolve to a Com row.
    assert_response :success
    assert_equal com_count_before, ComPreference.count,
                 "an app-issued refresh cookie must not resolve to any Com preference; com bootstraps its own"
  end

  test "a preference refresh cookie issued on app is inert on the org host" do
    patch base_app_preference_region_url(ri: "jp"),
          params: { preference_region: { option_id: "JP" } }

    assert_response :redirect

    app_refresh_token = cookies[COOKIE_NAME.call]

    assert_not_nil app_refresh_token

    org_count_before = OrgPreference.count

    reset!
    https!
    host! ENV.fetch("PRIVATE_BASE_STAFF_URL", "base.org.localhost")
    cookies[PreferenceCookieName.refresh(production: false, surface: :org)] = app_refresh_token

    get edit_base_org_preference_theme_url(ri: "jp")

    assert_response :success
    assert_equal org_count_before, OrgPreference.count,
                 "an app-issued refresh cookie must not resolve to any Org preference; org bootstraps its own"
  end
end
