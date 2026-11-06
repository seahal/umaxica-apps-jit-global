# typed: false
# frozen_string_literal: true

require "test_helper"

# Cookie consent is a browser-bound recorded decision; changing it replaces the decision receipt.
class PreferenceCookieConsentLifecycleTest < ActionDispatch::IntegrationTest
  test "granting and withdrawing consent updates the cookie and replaces its decision receipt" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    https!

    patch base_app_preference_cookie_path(ri: "jp"),
          params: { preference_cookie: { consented: "1", functional: "1", performant: "0", targetable: "0" } }

    assert_response :redirect
    first_claims, = JWT.decode(cookies[PreferenceCookieName.anonymous_jwt], nil, false)
    preference = AppPreference.includes(:app_preference_cookie).find_by!(public_id: first_claims.fetch("sub"))
    first_receipt = AppPreferenceConsentReceipt.find_by!(preference_id: preference.id)
    first_binding = AppPreferenceBrowserBinding.find_by!(preference_id: preference.id)

    cookie = preference.app_preference_cookie.reload

    assert_predicate cookie, :consented?
    assert cookie.functional
    assert_predicate first_receipt.version, :present?
    assert_predicate first_receipt.recorded_at, :present?
    assert_equal PreferenceBrowserBinding.digest_for(cookies[PreferenceBrowserBinding::COOKIE_NAME]),
                 first_binding.digest

    patch base_app_preference_cookie_path(ri: "jp"),
          params: { preference_cookie: { consented: "0", functional: "0", performant: "0", targetable: "0" } }

    assert_response :redirect
    second_claims, = JWT.decode(cookies[PreferenceCookieName.anonymous_jwt], nil, false)
    second_preference = AppPreference.includes(:app_preference_cookie)
      .find_by!(public_id: second_claims.fetch("sub"))
    second_receipt = AppPreferenceConsentReceipt.find_by!(preference_id: second_preference.id)
    cookie = second_preference.app_preference_cookie

    assert_equal preference.id, second_preference.id
    cookie.reload

    assert_not cookie.consented?
    assert_not cookie.functional
    assert_not_equal first_receipt.version, second_receipt.version
    assert_operator second_receipt.recorded_at, :>=, first_receipt.recorded_at
    assert_equal PreferenceBrowserBinding.digest_for(cookies[PreferenceBrowserBinding::COOKIE_NAME]),
                 AppPreferenceBrowserBinding.find_by!(preference_id: second_preference.id).digest
  end

  test "APP cookie screen reads consent only when its browser binding matches" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    https!

    patch base_app_preference_cookie_path(ri: "jp"),
          params: { preference_cookie: { consented: "1", functional: "1", performant: "0", targetable: "0" } }

    assert_response :redirect
    preference = AppPreference.find_by!(
      public_id: JWT.decode(cookies[PreferenceCookieName.anonymous_jwt], nil, false)
        .first.fetch("sub"),
    )
    receipt = AppPreferenceConsentReceipt.find_by!(preference_id: preference.id)
    issuance = [preference.jti, preference.last_issued_at, receipt.version, AppPreferenceChronicle.count]

    get edit_base_app_preference_cookie_url(host:, ri: "jp")

    assert_response :success
    categories = inertia_props.dig("form", "categories")

    assert categories.find { |category| category.fetch("key") == "consented" }.fetch("value")

    cookies[PreferenceBrowserBinding::COOKIE_NAME] = "invalid-binding"
    get edit_base_app_preference_cookie_url(host:, ri: "jp")

    assert_response :success
    categories = inertia_props.dig("form", "categories")

    assert_not categories.find { |category| category.fetch("key") == "consented" }.fetch("value")
    assert_equal AppPreference::ACTIVE_STATUS_ID, preference.reload.status_id
    assert_equal issuance, [preference.reload.jti, preference.last_issued_at, receipt.reload.version,
                            AppPreferenceChronicle.count,]
  end

  test "ORG cookie screen reads consent only when its browser binding matches" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host
    https!

    patch base_org_preference_cookie_path(ri: "jp"),
          params: { preference_cookie: { consented: "1", functional: "1", performant: "0", targetable: "0" } }

    assert_response :redirect
    preference = OrgPreference.find_by!(
      public_id: JWT.decode(cookies[PreferenceCookieName.anonymous_jwt], nil, false)
        .first.fetch("sub"),
    )
    receipt = OrgPreferenceConsentReceipt.find_by!(preference_id: preference.id)
    issuance = [preference.jti, preference.last_issued_at, receipt.version, OrgPreferenceChronicle.count]

    get edit_base_org_preference_cookie_url(host:, ri: "jp")

    assert_response :success
    categories = inertia_props.dig("form", "categories")

    assert categories.find { |category| category.fetch("key") == "consented" }.fetch("value")

    cookies[PreferenceBrowserBinding::COOKIE_NAME] = "invalid-binding"
    get edit_base_org_preference_cookie_url(host:, ri: "jp")

    assert_response :success
    categories = inertia_props.dig("form", "categories")

    assert_not categories.find { |category| category.fetch("key") == "consented" }.fetch("value")
    assert_equal OrgPreference::ACTIVE_STATUS_ID, preference.reload.status_id
    assert_equal issuance, [preference.reload.jti, preference.last_issued_at, receipt.reload.version,
                            OrgPreferenceChronicle.count,]
  end
end
