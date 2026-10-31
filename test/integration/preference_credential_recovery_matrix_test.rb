# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceCredentialRecoveryMatrixTest < ActionDispatch::IntegrationTest
  APP_HOST_ENV = "PUBLIC_BASE_SERVICE_URL"
  ORG_HOST_ENV = "PUBLIC_BASE_STAFF_URL"
  SHARED_COOKIES = [
    PreferenceCookieName.anonymous_jwt,
    PreferenceIoKeys::Cookies::LANGUAGE,
    PreferenceCookieName.anonymous_experience,
  ].freeze

  setup { https! }

  test "a valid APP anonymous JWT is refused by ORG without writing an ORG row" do
    app_host = ENV.fetch(APP_HOST_ENV)
    token = app_token(app_host)
    host! ENV.fetch(ORG_HOST_ENV)
    cookies[PreferenceCookieName.anonymous_jwt] = token
    before = OrgPreference.count

    get "/preference?ri=jp"

    assert_response :success
    assert_equal before, OrgPreference.count
    assert_shared_cookies_expired
  end

  test "malformed anonymous JWTs on APP and ORG GETs create no preference rows" do
    {
      "APP" => [APP_HOST_ENV, AppPreference],
      "ORG" => [ORG_HOST_ENV, OrgPreference],
    }.each do |label, (host_env, preference_class)|
      host! ENV.fetch(host_env)
      cookies[PreferenceCookieName.anonymous_jwt] = "malformed.jwt.value"

      assert_no_difference -> { preference_class.count }, label do
        get "/preference?ri=jp"
      end

      assert_response :success, label
      assert_shared_cookies_expired
    end
  end

  private

  def app_token(host)
    PreferenceToken.encode(
      SecurityJwtPreferenceTokenCodec::ANONYMOUS_PREFERENCE_VALUES.transform_values(&:first),
      host:,
      preference_type: "AppPreference",
      public_id: SecureRandom.alphanumeric(21),
      jti: SecureRandom.uuid,
      jwt_issuer_id: "preference_app",
      issued_at: Time.current,
    )
  end

  def assert_shared_cookies_expired
    SHARED_COOKIES.each do |name|
      entries = set_cookie_entries(name)
      assert_equal 1, entries.size, "expected one deletion for #{name}"
      entry = entries.first
      assert_equal "", entry[:value], "#{name} deletion must carry an empty value"
      assert(
        entry["max-age".to_sym] == "0" || (entry[:expires] && Time.httpdate(entry[:expires]) < Time.current),
        "#{name} deletion must expire the shared cookie",
      )
    end
  end
end
