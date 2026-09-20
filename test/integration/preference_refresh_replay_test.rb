# typed: false
# frozen_string_literal: true

require "test_helper"

# A preference refresh token is single use. When a request rotates it, the old token stays valid
# only for a sibling request from the same page load inside the short grace window; presenting it
# after that is treated as theft: the request is refused and the preference is marked compromised.
class PreferenceRefreshReplayTest < ActionDispatch::IntegrationTest
  test "a rotated preference refresh token replayed after the grace window is refused and compromises the preference" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    access_name = PreferenceCookieName.access(production: false, surface: :app)
    refresh_name = PreferenceCookieName.refresh(production: false, surface: :app)
    get base_app_preference_path(ri: "jp")

    assert_response :success
    original_refresh = cookies[refresh_name]
    preference = AppPreference.order(:created_at).last

    cookies.delete(access_name)
    get base_app_preference_path(ri: "jp")

    assert_response :success
    assert_not_equal original_refresh, cookies[refresh_name]

    travel SingleUseToken::PREFERENCE_REFRESH_GRACE_WINDOW + 1.second do
      cookies.delete(access_name)
      cookies[refresh_name] = original_refresh
      get base_app_preference_path(ri: "jp")

      assert_response :unauthorized
      assert_predicate preference.reload, :revoked?
      assert_predicate cookies[refresh_name].to_s, :empty?
    end
  end

  test "a rotated preference refresh token replayed inside the grace window is served without compromise" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    access_name = PreferenceCookieName.access(production: false, surface: :app)
    refresh_name = PreferenceCookieName.refresh(production: false, surface: :app)
    get base_app_preference_path(ri: "jp")

    assert_response :success
    original_refresh = cookies[refresh_name]
    preference = AppPreference.order(:created_at).last

    cookies.delete(access_name)
    get base_app_preference_path(ri: "jp")

    assert_response :success
    rotated_refresh = cookies[refresh_name]

    cookies.delete(access_name)
    cookies[refresh_name] = original_refresh
    get base_app_preference_path(ri: "jp")

    assert_response :success
    assert_not_predicate preference.reload, :revoked?
    assert_not_equal rotated_refresh, original_refresh
  end
  test "a DBSC-bound preference cannot refresh without its bound session cookie" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    access_name = PreferenceCookieName.access(production: false, surface: :app)
    refresh_name = PreferenceCookieName.refresh(production: false, surface: :app)
    dbsc_name = PreferenceCookieName.dbsc(production: false, surface: :app)
    get base_app_preference_path(ri: "jp")

    assert_response :success
    refresh = cookies[refresh_name]
    preference = AppPreference.order(:created_at).last
    preference.update_columns(
      binding_method_id: AppPreferenceBindingMethod::DBSC,
      dbsc_status_id: AppPreferenceDbscStatus::ACTIVE,
      dbsc_session_id: "bound-preference-session",
    )

    cookies.delete(access_name)
    cookies.delete(dbsc_name)
    get base_app_preference_path(ri: "jp")

    assert_response :unauthorized
    assert_predicate cookies[refresh_name].to_s, :empty?

    cookies[refresh_name] = refresh
    cookies[dbsc_name] = "another-session"
    get base_app_preference_path(ri: "jp")

    assert_response :unauthorized
  end

  test "a DBSC-bound preference whose DBSC lifecycle is not active cannot refresh" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    access_name = PreferenceCookieName.access(production: false, surface: :app)
    dbsc_name = PreferenceCookieName.dbsc(production: false, surface: :app)
    get base_app_preference_path(ri: "jp")

    assert_response :success
    preference = AppPreference.order(:created_at).last
    preference.update_columns(
      binding_method_id: AppPreferenceBindingMethod::DBSC,
      dbsc_status_id: AppPreferenceDbscStatus::FAILED,
      dbsc_session_id: "bound-preference-session",
    )

    cookies.delete(access_name)
    cookies[dbsc_name] = "bound-preference-session"
    get base_app_preference_path(ri: "jp")

    assert_response :unauthorized
  end
  test "a DBSC-bound preference refreshes with its bound session cookie and keeps the binding" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    access_name = PreferenceCookieName.access(production: false, surface: :app)
    refresh_name = PreferenceCookieName.refresh(production: false, surface: :app)
    dbsc_name = PreferenceCookieName.dbsc(production: false, surface: :app)
    get base_app_preference_path(ri: "jp")

    assert_response :success
    original_refresh = cookies[refresh_name]
    preference = AppPreference.order(:created_at).last
    preference.update_columns(
      binding_method_id: AppPreferenceBindingMethod::DBSC,
      dbsc_status_id: AppPreferenceDbscStatus::ACTIVE,
      dbsc_session_id: "bound-preference-session",
    )

    cookies.delete(access_name)
    cookies[dbsc_name] = "bound-preference-session"
    get base_app_preference_path(ri: "jp")

    assert_response :success
    assert_not_equal original_refresh, cookies[refresh_name]
    bound = AppPreference.where(dbsc_session_id: "bound-preference-session").to_a

    assert_equal 1, bound.size
    assert_not_equal preference.id, bound.first.id
    assert_equal AppPreferenceBindingMethod::DBSC, bound.first.binding_method_id

    travel SingleUseToken::PREFERENCE_REFRESH_GRACE_WINDOW + 1.second do
      cookies.delete(access_name)
      cookies[refresh_name] = original_refresh
      cookies[dbsc_name] = "bound-preference-session"
      get base_app_preference_path(ri: "jp")

      assert_response :unauthorized
    end
  end
end
