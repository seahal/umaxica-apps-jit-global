# frozen_string_literal: true

require "test_helper"

class Base::App::Api::V0::Preferences::CookieControllerTest < ActionDispatch::IntegrationTest
  test "GET without a valid Preference JWT shows the banner and writes no state" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    https!
    cookies[PreferenceCookieName.anonymous_jwt] = "invalid.jwt.token"
    preference_count = AppPreference.count

    get base_app_api_v0_preferences_cookie_path, headers: { "Accept" => "application/json" }

    assert_response :ok
    assert_equal({ "show_banner" => true }, response.parsed_body)
    assert_equal preference_count, AppPreference.count
    expired_preference_cookie = set_cookie_entries(PreferenceCookieName.anonymous_jwt).sole

    assert_equal "", expired_preference_cookie.fetch(:value)
    assert_equal "0", expired_preference_cookie.fetch(:"max-age")
  end

  test "an explicit refusal creates a bound receipt and remains readable on GET" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    https!
    headers = { "Accept" => "application/json", "Content-Type" => "application/json" }

    patch base_app_api_v0_preferences_cookie_path,
          params: { consented: false }.to_json,
          headers: headers

    assert_response :ok
    assert_equal(
      {
        "cookie" => {
          "consented" => false,
          "functional" => false,
          "performant" => false,
          "targetable" => false,
        },
      },
      response.parsed_body,
    )
    claims = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: host)
    preference = AppPreference.find_by!(public_id: claims.fetch("sub"))
    cookie = AppPreferenceCookie.find_by!(preference_id: preference.id)
    receipt = AppPreferenceConsentReceipt.find_by!(preference_id: preference.id)
    binding = AppPreferenceBrowserBinding.find_by!(preference_id: preference.id)
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

    preference_count = AppPreference.count
    receipt_version = receipt.version
    get base_app_api_v0_preferences_cookie_path, headers: { "Accept" => "application/json" }

    assert_response :ok
    assert_equal({ "show_banner" => false }, response.parsed_body)
    assert_equal preference_count, AppPreference.count
    assert_equal receipt_version, receipt.reload.version
  end
end
