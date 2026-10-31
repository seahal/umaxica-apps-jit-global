# frozen_string_literal: true

require "test_helper"

class Base::Org::Api::V0::Preferences::CookieControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! @host
    https!
  end

  test "GET with an invalid Preference JWT shows the banner without writing state" do
    cookies[PreferenceCookieName.anonymous_jwt] = "invalid.jwt.token"
    preference_count = OrgPreference.count

    get base_org_api_v0_preferences_cookie_path, headers: { "Accept" => "application/json" }

    assert_response :ok
    assert_equal({ "show_banner" => true }, response.parsed_body)
    assert_equal preference_count, OrgPreference.count
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceCookieName.anonymous_jwt}="
  end

  test "an explicit refusal creates a bound receipt and remains readable on GET" do
    headers = { "Accept" => "application/json", "Content-Type" => "application/json" }

    patch base_org_api_v0_preferences_cookie_path,
          params: { consented: false }.to_json,
          headers: headers

    assert_response :no_content
    claims = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: @host)
    preference = OrgPreference.find_by!(public_id: claims.fetch("sub"))
    cookie = OrgPreferenceCookie.find_by!(preference_id: preference.id)
    receipt = OrgPreferenceConsentReceipt.find_by!(preference_id: preference.id)
    binding = OrgPreferenceBrowserBinding.find_by!(preference_id: preference.id)
    raw_binding = cookies[PreferenceBrowserBinding::COOKIE_NAME]
    set_cookie = response.headers["Set-Cookie"].to_s

    assert_not cookie.consented?
    assert_not cookie.functional?
    assert_predicate receipt.version, :present?
    assert_predicate receipt.recorded_at, :present?
    assert PreferenceBrowserBinding.matches?(raw_binding, binding.digest)
    assert_includes set_cookie, "#{PreferenceCookieName.anonymous_jwt}="
    assert_includes set_cookie, "language="
    assert_includes set_cookie, "#{PreferenceCookieName.anonymous_experience}="
    assert_includes set_cookie, "#{PreferenceBrowserBinding::COOKIE_NAME}="

    preference_count = OrgPreference.count
    receipt_version = receipt.version
    get base_org_api_v0_preferences_cookie_path, headers: { "Accept" => "application/json" }

    assert_response :ok
    assert_equal({ "show_banner" => false }, response.parsed_body)
    assert_equal preference_count, OrgPreference.count
    assert_equal receipt_version, receipt.reload.version
  end
end
