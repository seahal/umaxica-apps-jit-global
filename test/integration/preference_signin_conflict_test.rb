# typed: false
# frozen_string_literal: true

require "test_helper"

# A public, JS-readable display cookie must never win over the canonical
# preference carried by the verified Preference JWT: it is a
# guest-safe fallback for when no valid token is present, not a truth source
# a client can override once a real (DB-backed) preference exists.
class PreferenceSigninConflictTest < ActionDispatch::IntegrationTest
  setup do
    https!
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
  end

  test "theme read prefers the verified Preference JWT over a conflicting public display cookie" do
    get edit_base_app_preference_theme_url(ri: "jp")

    assert_response :success

    patch base_app_preference_theme_url(ri: "jp"),
          params: { preference_theme: { option_id: "dr" } }

    assert_response :redirect

    # The display mirror is not a source of truth when a verified JWT exists.
    token = cookies[PreferenceCookieName.anonymous_jwt]
    conflicting_cookies = [
      "#{PreferenceCookieName.anonymous_jwt}=#{Rack::Utils.escape(token)}",
      "#{PreferenceCookieName.anonymous_experience}=#{Rack::Utils.escape('{"theme":"system"}')}",
    ].join("; ")

    get base_app_api_v0_preferences_theme_url(ri: "jp"),
        headers: { "Cookie" => conflicting_cookies, "HTTP_COOKIE" => conflicting_cookies }

    assert_response :success
    body = response.parsed_body

    assert_equal "dr", body["theme"],
                 "the verified Preference JWT must win over a conflicting display mirror"
    raw_repaired_experience = set_cookie_entries(PreferenceCookieName.anonymous_experience).sole.fetch(:value)
    repaired = JSON.parse(Rack::Utils.unescape(raw_repaired_experience))

    assert_equal "dark", repaired.fetch("theme")
  end

  test "cookie consent read prefers the verified Preference JWT's recorded consent over a conflicting display cookie" do
    get edit_base_app_preference_cookie_url(ri: "jp")

    assert_response :success

    patch base_app_preference_cookie_url(ri: "jp"),
          params: { preference_cookie: { consented: "1", functional: "1", performant: "0", targetable: "0" } }

    assert_response :redirect

    token = cookies[PreferenceCookieName.anonymous_jwt]
    binding = cookies[PreferenceBrowserBinding::COOKIE_NAME]
    conflicting_cookies = [
      "#{PreferenceCookieName.anonymous_jwt}=#{Rack::Utils.escape(token)}",
      "#{PreferenceCookieName.anonymous_experience}=#{Rack::Utils.escape("{}")}",
      "#{PreferenceBrowserBinding::COOKIE_NAME}=#{Rack::Utils.escape(binding)}",
    ].join("; ")

    get base_app_api_v0_preferences_cookie_url(ri: "jp"),
        headers: { "Cookie" => conflicting_cookies, "HTTP_COOKIE" => conflicting_cookies }

    assert_response :success
    body = response.parsed_body

    assert_not body["show_banner"],
               "the stored consent decision must not come from a display mirror"
  end
end
