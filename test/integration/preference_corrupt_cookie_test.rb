# typed: false
# frozen_string_literal: true

require "test_helper"

# A garbage/corrupt preference refresh cookie or access JWT must never raise
# an unhandled exception and must never be treated as authority over existing
# DB state. A malformed refresh credential is detached on GET without creating
# a replacement database row.
class PreferenceCorruptCookieTest < ActionDispatch::IntegrationTest
  setup do
    https!
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
  end

  REFRESH_COOKIE_NAME = -> { PreferenceCookieName.refresh(production: false, surface: :app) }
  ACCESS_COOKIE_NAME = -> { PreferenceCookieName.access(production: false, surface: :app) }

  test "garbage refresh cookie is cleared and a public GET continues without a database write" do
    invalid_token = "not-a-real-token.garbage"
    cookies[REFRESH_COOKIE_NAME.call] = invalid_token

    assert_no_difference -> { AppPreference.count } do
      get "/preference?ri=jp"
    end

    assert_response :success
    assert_cookie_deleted(REFRESH_COOKIE_NAME.call)
  end

  test "an explicit preference update after recovery persists on the next request" do
    cookies[REFRESH_COOKIE_NAME.call] = "not-a-real-token.garbage"

    assert_no_difference -> { AppPreference.count } do
      get "/preference?ri=jp"
    end

    assert_response :success
    assert_cookie_deleted(REFRESH_COOKIE_NAME.call)

    patch base_app_preference_region_path(ri: "jp"),
          params: { preference_region: { option_id: AppPreferenceRegionOption::US } }

    assert_response :redirect
    assert_predicate cookies[REFRESH_COOKIE_NAME.call], :present?

    get "/preference?ri=jp"

    assert_response :success
    assert_equal AppPreferenceRegionOption::US,
                 AppPreference.order(:created_at).last.app_preference_region.option_id
  end

  test "garbage refresh cookie does not overwrite an existing preference's DB state" do
    patch base_app_preference_region_path(ri: "jp"),
          params: { preference_region: { option_id: AppPreferenceRegionOption::US } }

    assert_response :redirect

    existing = AppPreference.order(:created_at).last
    existing_region_option_id = existing.app_preference_region.option_id

    reset!
    https!
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    cookies[REFRESH_COOKIE_NAME.call] = "totally-invalid-cookie-value"

    get "/preference?ri=us"

    assert_response :success

    existing.reload

    assert_equal existing_region_option_id, existing.app_preference_region.option_id,
                 "a corrupt cookie from a different session must not mutate an unrelated existing preference"
  end

  test "a valid refresh cookie renders read-only when the access cookie is absent" do
    patch base_app_preference_region_path(ri: "jp"),
          params: { preference_region: { option_id: AppPreferenceRegionOption::US } }

    assert_response :redirect

    refresh_token = cookies[REFRESH_COOKIE_NAME.call]

    assert_predicate refresh_token, :present?
    cookies.delete(ACCESS_COOKIE_NAME.call)
    preference = AppPreference.find_by!(
      token_digest: AppPreference.digest_refresh_token(
        AppPreference.parse_refresh_token(refresh_token).last,
      ),
    )
    before = preference.reload.attributes

    get "/preference?ri=jp"

    assert_response :success
    assert_equal before, preference.reload.attributes
    assert_equal refresh_token, cookies[REFRESH_COOKIE_NAME.call]
  end

  test "absent refresh cookie does not bootstrap a preference during GET" do
    assert_no_difference -> { AppPreference.count } do
      get "/preference?ri=jp"
    end

    assert_response :success
    assert_nil cookies[REFRESH_COOKIE_NAME.call]
  end

  test "garbage access token JWT does not raise and falls back to refresh-token handling" do
    cookies[ACCESS_COOKIE_NAME.call] = "garbage.jwt.value"

    get "/preference?ri=jp"

    assert_response :success
    assert_cookie_deleted(ACCESS_COOKIE_NAME.call)
  end
end
