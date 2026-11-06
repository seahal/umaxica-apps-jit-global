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
    token = PreferenceToken.encode(
      SecurityJwtPreferenceTokenCodec::ANONYMOUS_PREFERENCE_VALUES.transform_values(&:first),
      host: app_host,
      preference_type: "AppPreference",
      public_id: SecureRandom.alphanumeric(21),
      jti: SecureRandom.uuid,
      jwt_issuer_id: "preference_app",
      issued_at: Time.current,
    )
    host! ENV.fetch(ORG_HOST_ENV)
    cookies[PreferenceCookieName.anonymous_jwt] = token
    before = OrgPreference.count

    get "/preference?ri=jp"

    assert_response :success
    assert_equal before, OrgPreference.count
    set_cookie_headers = Array(response.headers["Set-Cookie"]).flat_map { |header| header.to_s.split("\n") }
    shared_cookie_headers =
      set_cookie_headers.select do |header|
        SHARED_COOKIES.include?(header.split("=", 2).first)
      end
    shared_cookie_names = shared_cookie_headers.map { |header| header.split("=", 2).first }

    assert_equal [PreferenceCookieName.anonymous_jwt], shared_cookie_names
    deletion_header = shared_cookie_headers.sole

    assert_equal "#{PreferenceCookieName.anonymous_jwt}=", deletion_header.split(";", 2).first
    expiry = deletion_header.match(/(?:\A|;)\s*expires=([^;]+)/i)&.captures&.first
    max_age = deletion_header.match(/(?:\A|;)\s*max-age=([^;]+)/i)&.captures&.first

    assert(
      max_age == "0" || (expiry.present? && Time.httpdate(expiry) < Time.current),
      "Preference JWT deletion must set Max-Age=0 or an expired Expires value",
    )
  end

  test "malformed anonymous JWTs on APP and ORG GETs create no preference rows" do
    {
      "APP" => [APP_HOST_ENV, AppPreference],
      "ORG" => [ORG_HOST_ENV, OrgPreference],
    }.each do |label, (host_env, preference_class)|
      host! ENV.fetch(host_env)
      assert_no_difference -> { preference_class.count }, label do
        get "/preference?ri=jp",
            headers: { "Cookie" => "#{PreferenceCookieName.anonymous_jwt}=malformed.jwt.value" }
      end

      assert_response :success, label
      set_cookie_headers = Array(response.headers["Set-Cookie"]).flat_map { |header| header.to_s.split("\n") }
      shared_cookie_headers =
        set_cookie_headers.select do |header|
          SHARED_COOKIES.include?(header.split("=", 2).first)
        end
      shared_cookie_names = shared_cookie_headers.map { |header| header.split("=", 2).first }

      assert_equal [PreferenceCookieName.anonymous_jwt], shared_cookie_names, label
      deletion_header = shared_cookie_headers.sole

      assert_equal "#{PreferenceCookieName.anonymous_jwt}=", deletion_header.split(";", 2).first, label
      expiry = deletion_header.match(/(?:\A|;)\s*expires=([^;]+)/i)&.captures&.first
      max_age = deletion_header.match(/(?:\A|;)\s*max-age=([^;]+)/i)&.captures&.first

      assert(
        max_age == "0" || (expiry.present? && Time.httpdate(expiry) < Time.current),
        "Preference JWT deletion must set Max-Age=0 or an expired Expires value",
      )
    end
  end
end
