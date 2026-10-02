# typed: false
# frozen_string_literal: true

require "openssl"
require "test_helper"

class PreferenceCookieInvalidValuesTest < ActionDispatch::IntegrationTest
  test "web cookie update rejects invalid consent values without changing canonical preference" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    preference = AppPreference.create!(status_id: AppPreferenceStatus::NOTHING)
    AppPreferenceCookie.create!(
      preference: preference,
      targetable: false,
      performant: false,
      functional: false,
      consented: false,
      consented_at: nil,
    )
    key = OpenSSL::PKey::EC.generate("secp384r1")
    public_key_for_stub = ->(_kid, **_options) { key }

    PreferenceJwtConfiguration.stub(:private_key, key) do
      PreferenceJwtConfiguration.stub(:public_key, key) do
        PreferenceJwtConfiguration.stub(:private_key_for_active, key) do
          PreferenceJwtConfiguration.stub(:public_key_for, public_key_for_stub) do
            PreferenceJwtConfiguration.stub(:active_kid, "default") do
              PreferenceJwtConfiguration.stub(:issuer, "jit-preference") do
                PreferenceJwtConfiguration.stub(:audiences, [host]) do
                  cookies[PreferenceCookieName.access] = PreferenceToken.encode(
                    { "consented" => false },
                    host: host,
                    preference_type: "AppPreference",
                    public_id: preference.public_id,
                    jti: "test-jti-#{SecureRandom.uuid}",
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
        end
      end
    end

    cookie = preference.reload.app_preference_cookie

    assert_not cookie.consented
    assert_nil cookie.consented_at
  end
end
