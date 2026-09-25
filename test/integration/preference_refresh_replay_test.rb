# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceRefreshReplayTest < ActionDispatch::IntegrationTest
  test "a consumed refresh token is rejected immediately and GET does not change either row" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    access_name = PreferenceCookieName.access(production: false, surface: :app)
    refresh_name = PreferenceCookieName.refresh(production: false, surface: :app)

    patch base_app_preference_region_path(ri: "jp"),
          params: { preference_region: { option_id: AppPreferenceRegionOption::US } }

    assert_response :redirect
    refresh_token = cookies[refresh_name]
    public_id, verifier = AppPreference.parse_refresh_token(refresh_token)
    preference = AppPreference.find_by!(public_id: public_id)
    replacement = AppPreference.rotate!(presented_digest: AppPreference.digest_refresh_token(verifier))

    assert_predicate replacement, :present?
    before = preference.reload.attributes
    replacement_before = replacement.reload.attributes

    cookies.delete(access_name)
    get base_app_preference_path(ri: "jp")

    assert_response :unauthorized
    assert_equal before, preference.reload.attributes
    assert_equal replacement_before, replacement.reload.attributes
    assert_equal refresh_token, cookies[refresh_name]
  end

  test "a valid refresh cookie renders read-only without rotation when its access cookie is absent" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    access_name = PreferenceCookieName.access(production: false, surface: :app)
    refresh_name = PreferenceCookieName.refresh(production: false, surface: :app)

    patch base_app_preference_region_path(ri: "jp"),
          params: { preference_region: { option_id: AppPreferenceRegionOption::US } }

    assert_response :redirect
    refresh_token = cookies[refresh_name]
    public_id, = AppPreference.parse_refresh_token(refresh_token)
    preference = AppPreference.find_by!(public_id: public_id)
    before = preference.reload.attributes
    preference_count = AppPreference.count
    cookies.delete(access_name)

    get base_app_preference_path(ri: "jp")

    assert_response :success
    assert_equal before, preference.reload.attributes
    assert_equal preference_count, AppPreference.count
    assert_equal refresh_token, cookies[refresh_name]
  end

  test "a DBSC-bound preference rejects missing or mismatched binding without mutating GET state" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    access_name = PreferenceCookieName.access(production: false, surface: :app)
    refresh_name = PreferenceCookieName.refresh(production: false, surface: :app)
    dbsc_name = PreferenceCookieName.dbsc(production: false, surface: :app)

    patch base_app_preference_region_path(ri: "jp"),
          params: { preference_region: { option_id: AppPreferenceRegionOption::US } }

    assert_response :redirect
    refresh_token = cookies[refresh_name]
    public_id, = AppPreference.parse_refresh_token(refresh_token)
    preference = AppPreference.find_by!(public_id: public_id)
    preference.update_columns(
      binding_method_id: AppPreferenceBindingMethod::DBSC,
      dbsc_status_id: AppPreferenceDbscStatus::ACTIVE,
      dbsc_session_id: "bound-preference-session",
    )
    before = preference.reload.attributes
    cookies.delete(access_name)

    get base_app_preference_path(ri: "jp")

    assert_response :unauthorized
    assert_equal before, preference.reload.attributes
    assert_equal refresh_token, cookies[refresh_name]

    cookies[dbsc_name] = "another-session"
    get base_app_preference_path(ri: "jp")

    assert_response :unauthorized
    assert_equal before, preference.reload.attributes
    assert_equal refresh_token, cookies[refresh_name]
  end

  test "a DBSC-bound preference with an inactive binding is rejected without mutation on GET" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    access_name = PreferenceCookieName.access(production: false, surface: :app)
    refresh_name = PreferenceCookieName.refresh(production: false, surface: :app)
    dbsc_name = PreferenceCookieName.dbsc(production: false, surface: :app)

    patch base_app_preference_region_path(ri: "jp"),
          params: { preference_region: { option_id: AppPreferenceRegionOption::US } }

    assert_response :redirect
    refresh_token = cookies[refresh_name]
    public_id, = AppPreference.parse_refresh_token(refresh_token)
    preference = AppPreference.find_by!(public_id: public_id)
    preference.update_columns(
      binding_method_id: AppPreferenceBindingMethod::DBSC,
      dbsc_status_id: AppPreferenceDbscStatus::FAILED,
      dbsc_session_id: "bound-preference-session",
    )
    before = preference.reload.attributes
    cookies.delete(access_name)
    cookies[dbsc_name] = "bound-preference-session"

    get base_app_preference_path(ri: "jp")

    assert_response :unauthorized
    assert_equal before, preference.reload.attributes
    assert_equal refresh_token, cookies[refresh_name]
  end

  test "a valid DBSC binding reads without rotating the refresh token on GET" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    access_name = PreferenceCookieName.access(production: false, surface: :app)
    refresh_name = PreferenceCookieName.refresh(production: false, surface: :app)
    dbsc_name = PreferenceCookieName.dbsc(production: false, surface: :app)

    patch base_app_preference_region_path(ri: "jp"),
          params: { preference_region: { option_id: AppPreferenceRegionOption::US } }

    assert_response :redirect
    refresh_token = cookies[refresh_name]
    public_id, = AppPreference.parse_refresh_token(refresh_token)
    preference = AppPreference.find_by!(public_id: public_id)
    preference.update_columns(
      binding_method_id: AppPreferenceBindingMethod::DBSC,
      dbsc_status_id: AppPreferenceDbscStatus::ACTIVE,
      dbsc_session_id: "bound-preference-session",
    )
    before = preference.reload.attributes
    cookies.delete(access_name)
    cookies[dbsc_name] = "bound-preference-session"

    get base_app_preference_path(ri: "jp")

    assert_response :success
    assert_equal before, preference.reload.attributes
    assert_equal refresh_token, cookies[refresh_name]
  end
end
