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
  test "anonymous Preference JWT lifetime is 400 days" do
    assert_equal 400.days, SecurityJwtPreferenceTokenCodec::ANONYMOUS_ACCESS_TOKEN_TTL
  end

  test "anonymous Preference browser cookies use the shared realm contract" do
    assert_equal "__Secure-preference", PreferenceCookieName.anonymous_jwt
    assert_equal "__Secure-experience", PreferenceCookieName.anonymous_experience
    assert_equal "language", PreferenceIoKeys::Cookies::LANGUAGE
    assert_equal "__Host-preference_binding", PreferenceBrowserBinding::COOKIE_NAME
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
    host = "base.app.localhost"
    token = PreferenceToken.encode(
      SecurityJwtPreferenceTokenCodec::ANONYMOUS_PREFERENCE_VALUES.transform_values(&:first),
      host:,
      preference_type: "AppPreference",
      public_id: "abcdefghijk01234567890",
      jti: SecureRandom.uuid,
      jwt_issuer_id: "preference_app",
    )

    assert token
    assert PreferenceToken.decode(token, host: "visa.app.localhost", jwt_issuer_id: "preference_app")
    assert_nil PreferenceToken.decode(token, host: "base.com.localhost", jwt_issuer_id: "preference_com")
  end

  test "an anonymous Preference JWT has no account or preference type claim" do
    host = "base.app.localhost"
    token = PreferenceToken.encode(
      SecurityJwtPreferenceTokenCodec::ANONYMOUS_PREFERENCE_VALUES.transform_values(&:first),
      host:,
      preference_type: "AppPreference",
      public_id: "abcdefghijk01234567890",
      jti: SecureRandom.uuid,
      jwt_issuer_id: "preference_app",
    )
    claims = PreferenceToken.decode(token, host:, jwt_issuer_id: "preference_app")

    assert claims
    assert_equal %w(aud exp iat iss jti preferences sub), claims.keys.sort
  end
end
