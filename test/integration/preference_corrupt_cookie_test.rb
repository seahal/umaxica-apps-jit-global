# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceCorruptCookieTest < ActionDispatch::IntegrationTest
  setup do
    https!
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
  end

  test "a malformed anonymous JWT is detached on GET without creating a preference" do
    cookies[PreferenceCookieName.anonymous_jwt] = "not.a.jwt"
    cookies[PreferenceIoKeys::Cookies::LANGUAGE] = "en"
    cookies[PreferenceCookieName.anonymous_experience] = "{\"theme\":\"dark\"}"

    assert_no_difference -> { AppPreference.count } do
      get "/preference?ri=jp"
    end

    assert_response :success
    [PreferenceCookieName.anonymous_jwt, PreferenceIoKeys::Cookies::LANGUAGE,
     PreferenceCookieName.anonymous_experience,].each do |name|
      assert_shared_cookie_expired(name)
    end
  end

  test "an explicit write after a malformed JWT creates a fresh row and issues the three shared cookies" do
    cookies[PreferenceCookieName.anonymous_jwt] = "not.a.jwt"
    before = AppPreference.count

    patch base_app_preference_theme_path(ri: "jp"),
          params: { preference_theme: { option_id: AppPreferenceThemeOption::DARK.to_s } }

    assert_response :redirect
    assert_equal before + 1, AppPreference.count
    [PreferenceCookieName.anonymous_jwt, PreferenceIoKeys::Cookies::LANGUAGE,
     PreferenceCookieName.anonymous_experience,].each do |name|
      assert_predicate cookies[name], :present?, "#{name} should be issued after the explicit write"
    end
  end

  private

  def assert_shared_cookie_expired(name)
    entry = set_cookie_entries(name).sole

    assert_equal "", entry[:value]
    assert(entry[:"max-age"] == "0" || (entry[:expires] && Time.httpdate(entry[:expires]) < Time.current))
  end
end
