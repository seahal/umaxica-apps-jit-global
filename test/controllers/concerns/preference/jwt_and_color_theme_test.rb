# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class PreferenceJwtAndColorThemeTest < ActiveSupport::TestCase
  test "THEME_SHORT_MAP contains correct mappings" do
    assert_equal "li", PreferenceBase::THEME_SHORT_MAP["light"]
    assert_equal "dr", PreferenceBase::THEME_SHORT_MAP["dark"]
    assert_equal "sy", PreferenceBase::THEME_SHORT_MAP["system"]
  end

  test "THEME_OPTION_MAP contains correct mappings" do
    assert_equal "light", PreferenceBase::THEME_OPTION_MAP["li"]
    assert_equal "dark", PreferenceBase::THEME_OPTION_MAP["dr"]
    assert_equal "system", PreferenceBase::THEME_OPTION_MAP["sy"]
  end
end

class PreferenceOptionMappingTest < ActiveSupport::TestCase
  test "ACCESS_TOKEN_TTL is 7 days" do
    assert_equal 7.days, PreferenceBase::ACCESS_TOKEN_TTL
  end

  test "REFRESH_TOKEN_TTL is 400 days" do
    assert_equal 400.days, PreferenceBase::REFRESH_TOKEN_TTL
  end

  test "THEME_COOKIE_KEY is correct" do
    assert_equal "ct", PreferenceBase::THEME_COOKIE_KEY
  end

  test "LANGUAGE_COOKIE_KEY is correct" do
    assert_equal "language", PreferenceBase::LANGUAGE_COOKIE_KEY
  end

  test "TIMEZONE_COOKIE_KEY is correct" do
    assert_equal "tz", PreferenceBase::TIMEZONE_COOKIE_KEY
  end
end

class PreferenceJwtConfigurationTest < ActiveSupport::TestCase
  test "jwt configuration reads the issuer from the environment and uses the fixed leeway" do
    with_env(
      "PREFERENCE_JWT_ACTIVE_KID" => "kid-1",
      "PREFERENCE_JWT_ISSUER" => "jit-test",
    ) do
      assert_equal JitSecurityJwtRegistry.issuer("preference").current_kid,
                   PreferenceJwtConfiguration.active_kid
      assert_equal SecurityJwtRfc9068AccessTokenProfile::CLOCK_SKEW_LEEWAY_SECONDS,
                   PreferenceJwtConfiguration.leeway_seconds
      assert_equal "jit-test", PreferenceJwtConfiguration.issuer
      expected = Rails.configuration.x.boot_config.fetch(:hosts).base_origins.map(&:host)
      expected.concat(%w(app.localhost org.localhost com.localhost localhost))
      expected.uniq!

      assert_equal expected,
                   PreferenceJwtConfiguration.audiences
    end
  end

  private

  def with_env(vars)
    original = {}
    vars.each_key { |key| original[key] = ENV[key] }

    vars.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end

    yield
  ensure
    original.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end

class PreferenceTokenTest < ActiveSupport::TestCase
  test "token issued on id host decodes on same TLD sibling when audience is configured" do
    token = PreferenceToken.encode(
      { "lx" => "ja" },
      host: "log.umaxica.app",
      preference_type: "AppPreference",
      public_id: "pref_123",
      jti: "jti_123",
    )

    assert token
    assert PreferenceToken.decode(token, host: "log.umaxica.app")
    assert_nil PreferenceToken.decode(token, host: "log.umaxica.com")
  end

  test "token issued on id host can decode for the same host without ENV audience config" do
    token = PreferenceToken.encode(
      { "lx" => "ja" },
      host: "log.umaxica.app",
      preference_type: "AppPreference",
      public_id: "pref_123",
      jti: "jti_123",
    )

    assert PreferenceToken.decode(token, host: "log.umaxica.app")
    assert_nil PreferenceToken.decode(token, host: "log.umaxica.com")
  end
end
