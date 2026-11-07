# typed: false
# frozen_string_literal: true

require "openssl"
require "test_helper"

class PreferenceCookieInvalidValuesTest < ActionDispatch::IntegrationTest
  test "web cookie update rejects invalid consent values without changing canonical preference" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    https!
    issued_at = Time.current.change(usec: 0)
    preference = AppPreference.create!(
      status_id: AppPreferenceStatus::ACTIVE,
      jti: SecureRandom.uuid,
      last_issued_at: issued_at,
      last_issued_expires_at: issued_at + 400.days,
    )
    AppPreferenceCookie.create!(
      preference: preference,
      targetable: false,
      performant: false,
      functional: false,
      consented: false,
    )
    key = OpenSSL::PKey::EC.generate("secp384r1")
    public_key_for_stub = ->(_kid, **_options) { key }
    preferences = {
      "theme" => "system",
      "language" => "ja",
      "timezone" => "Asia/Tokyo",
      "currency" => "jpy",
      "date_format" => "iso",
      "time_format" => "24",
      "motion" => "standard",
      "density" => "standard",
      "page_size" => "infinity",
    }

    PreferenceJwtConfiguration.stub(:private_key_for_active, key) do
      PreferenceJwtConfiguration.stub(:public_key_for, public_key_for_stub) do
        PreferenceJwtConfiguration.stub(:active_kid, "default") do
          PreferenceJwtConfiguration.stub(:issuer_for, "jit-preference") do
            cookies[PreferenceCookieName.anonymous_jwt] = PreferenceToken.encode(
              preferences,
              host: host,
              preference_type: "AppPreference",
              public_id: preference.public_id,
              jti: preference.jti,
              jwt_issuer_id: "preference_app",
              issued_at: issued_at,
            )

            ["banana", ["true"], { value: true }, nil].each do |invalid_value|
              patch base_app_api_v0_preferences_cookie_path, params: { consented: invalid_value }, as: :json

              # Well-formed JSON with an unreadable decision is a validation problem.
              assert_response :unprocessable_content
              assert_equal ["/consented"], response.parsed_body.fetch("errors").pluck("pointer")
            end
          end
        end
      end
    end

    cookie = preference.reload.app_preference_cookie

    assert_not cookie.consented
    assert_nil AppPreferenceConsentReceipt.find_by(preference_id: preference.id)
  end
end
