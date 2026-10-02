# typed: false
# frozen_string_literal: true

require "test_helper"

# A public, JS-readable display cookie must never win over the canonical
# preference carried by the verified preference access token: it is a
# guest-safe fallback for when no valid token is present, not a truth source
# a client can override once a real (DB-backed) preference exists.
class PreferenceSigninConflictTest < ActionDispatch::IntegrationTest
  setup do
    https!
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
  end

  THEME_COOKIE_KEY = -> { PreferenceBase::THEME_COOKIE_KEY }

  test "theme read prefers the verified access token over a conflicting public display cookie" do
    get edit_base_app_preference_theme_url(ri: "jp")

    assert_response :success

    patch base_app_preference_theme_url(ri: "jp"),
          params: { preference_theme: { option_id: "dr" } }

    assert_response :redirect

    # Simulate a tampered/self-reported public cookie disagreeing with the
    # canonical (token-backed) preference that was just persisted as "dr".
    cookies[THEME_COOKIE_KEY.call] = "sy"

    get base_app_api_v0_preferences_theme_url(ri: "jp")

    assert_response :success
    body = response.parsed_body

    assert_equal "dr", body["theme"],
                 "the verified preference access token must win over a conflicting public cookie"
  end

  test "cookie consent read prefers the verified access token's recorded consent over a stale buffer cookie" do
    get edit_base_app_preference_cookie_url(ri: "jp")

    assert_response :success

    patch base_app_preference_cookie_url(ri: "jp"),
          params: { preference_cookie: { consented: "1", functional: "1", performant: "0", targetable: "0" } }

    assert_response :redirect

    cookies[PreferenceIoKeys::Cookies::CONSENTED] = "0"

    get base_app_api_v0_preferences_cookie_url(ri: "jp")

    assert_response :success
    body = response.parsed_body

    assert_not body["show_banner"],
               "the verified preference access token's consent state must win over the stale buffer cookie"
  end
end
