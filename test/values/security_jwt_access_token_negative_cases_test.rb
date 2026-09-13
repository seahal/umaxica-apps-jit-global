# typed: false
# frozen_string_literal: true

require "test_helper"

# Negative verification cases for the RFC 9068 access-token profile shared by
# auth_access and preference access tokens. Each case re-signs an otherwise
# valid token with one defect and asserts the verifier fails closed.
class SecurityJwtAccessTokenNegativeCasesTest < ActiveSupport::TestCase
  AUTH_HOST = "example.com"

  # --- auth_access -----------------------------------------------------------

  test "auth access rejects every algorithm other than ES384" do
    payload, header = auth_parts

    foreign_keys.each do |alg, key|
      token = JWT.encode(payload, key, alg, header.merge("alg" => alg))

      assert_nil decode_auth(token), "#{alg} must be rejected"
    end
  end

  test "auth access rejects a token signed by another keyring" do
    surface_token = AuthenticationToken.encode(
      clients(:one), host: AUTH_HOST, session_public_id: "sid", resource_type: "client",
                     jwt_issuer_id: "surface:SIGN_APP",
    )
    payload, header = auth_parts
    preference_signed = JWT.encode(payload, PreferenceJwtConfiguration.private_key_for_active, "ES384", header)

    assert_nil decode_auth(surface_token)
    assert_nil decode_auth(preference_signed)
  end

  test "auth access rejects malformed and missing required claims" do
    variants = {
      "client_id missing" => ->(p) { p.except("client_id") },
      "client_id not a string" => ->(p) { p.merge("client_id" => 7) },
      "exp missing" => ->(p) { p.except("exp") },
      "jti missing" => ->(p) { p.except("jti") },
      "iss missing" => ->(p) { p.except("iss") },
      "aud empty" => ->(p) { p.merge("aud" => []) },
      "iat as float" => ->(p) { p.merge("iat" => p["iat"] + 0.5) },
      "sub numeric" => ->(p) { p.merge("sub" => clients(:one).id) },
      "scope as array" => ->(p) { p.merge("scope" => p["scope"].split) },
      "scope missing" => ->(p) { p.except("scope") },
      "future nbf" => ->(p) { p.merge("nbf" => 10.minutes.from_now.to_i) },
    }

    variants.each do |label, mutate|
      assert_nil decode_auth(resign_auth(&mutate)), "#{label} must be rejected"
    end
  end

  test "auth access rejects legacy scp, act, and payload typ claims" do
    assert_nil decode_auth(resign_auth { |p| p.merge("scp" => p["scope"].split) })
    assert_nil decode_auth(resign_auth { |p| p.merge("act" => "client") })
    assert_nil decode_auth(resign_auth { |p| p.merge("typ" => "auth-access-token;client") })
  end

  test "auth access rejects a token whose domain scope names another resource type" do
    payload = decode_auth(resign_auth { |p| p.merge("scope" => "authenticated domain:operator") })

    assert_not AuthenticationToken.resource_type_scope_matches?(payload, "client")
  end

  test "auth access rejects a legacy custom-typ token end to end" do
    payload, header = auth_parts
    legacy = JWT.encode(
      payload.merge("scp" => payload["scope"].split, "act" => "client", "sub" => clients(:one).id),
      AuthenticationJwtConfiguration.private_key,
      "ES384",
      header.merge("typ" => "auth-access-token;client"),
    )

    assert_nil decode_auth(legacy)
  end

  # --- preference access -----------------------------------------------------

  test "preference access rejects every algorithm other than ES384" do
    payload, header = preference_parts

    foreign_keys.each do |alg, key|
      token = JWT.encode(payload, key, alg, header.merge("alg" => alg))

      assert_nil decode_preference(token), "#{alg} must be rejected"
    end
  end

  test "preference access rejects expired, numeric-sub, and mismatched-sub tokens" do
    assert_nil decode_preference(resign_preference { |p| p.merge("exp" => 1.hour.ago.to_i) })
    assert_nil decode_preference(resign_preference { |p| p.merge("sub" => 42) })
    assert_nil decode_preference(resign_preference { |p| p.merge("sub" => "someone-else") })
    assert_nil decode_preference(resign_preference { |p| p.merge("scope" => "authenticated") })
    assert_nil decode_preference(resign_preference { |p| p.merge("typ" => "preference-access-token") })
  end

  test "preference access rejects a sibling host and an audience that omits the host scope" do
    token = resign_preference { |p| p }

    assert_nil decode_preference(token, host: "evil.#{preference_host}.example")
    assert_nil decode_preference(resign_preference { |p| p.merge("aud" => ["unrelated.localhost"]) })
  end

  test "preference extract_public_id does not fall back to sub" do
    assert_nil PreferenceToken.extract_public_id({ "sub" => "pref-1" })
  end

  # --- environment isolation -------------------------------------------------

  test "local issuers are environment specific" do
    assert_equal "urn:umaxica:test:auth", AuthenticationJwtConfiguration.issuer
    assert_equal "urn:umaxica:test:preference", PreferenceJwtConfiguration.issuer
    assert_nil decode_auth(resign_auth { |p| p.merge("iss" => "urn:umaxica:development:auth") })
    assert_nil decode_preference(resign_preference { |p| p.merge("iss" => "urn:umaxica:development:preference") })
  end

  test "production boot validation rejects development and test issuers" do
    with_production do
      error = assert_raises(ArgumentError) { AuthenticationJwtConfiguration.validate! }

      assert_match(/AUTH_JWT_ISSUER must not include non-production identifiers/, error.message)
    end

    with_env("AUTH_JWT_ISSUER" => "https://sign.umaxica.app") do
      with_production do
        error = assert_raises(ArgumentError) { PreferenceJwtConfiguration.validate! }

        assert_match(/PREFERENCE_JWT_ISSUER must not include non-production identifiers/, error.message)
      end
    end
  end

  test "production boot validation accepts production identifiers" do
    with_env(
      "AUTH_JWT_ISSUER" => "https://sign.umaxica.app",
      "PREFERENCE_JWT_ISSUER" => "https://sign.umaxica.app/preference",
    ) do
      with_production do
        assert AuthenticationJwtConfiguration.validate!
        PreferenceJwtConfiguration.stub(:audiences_from_boot_config, %w(www.umaxica.app)) do
          assert PreferenceJwtConfiguration.validate!
        end
      end
    end
  end

  test "production rejects the reserved test TLD in auth audiences" do
    with_env("AUTH_JWT_VISITOR_AUDIENCES" => "api.example.test") do
      with_production do
        assert_raises(ArgumentError) { AuthenticationJwtConfiguration.audiences("visitor") }
      end
    end
  end

  test "leeway is fixed and not read from the environment" do
    with_env("AUTH_JWT_LEEWAY_SECONDS" => "86400") do
      assert_equal SecurityJwtRfc9068AccessTokenProfile::CLOCK_SKEW_LEEWAY_SECONDS,
                   AuthenticationJwtConfiguration.leeway_seconds
    end
  end

  test "keyring encode requires an explicit JOSE typ and ignores payload typ" do
    assert_raises(ArgumentError) { JitSecurityJwtKeyring.encode({ "typ" => "x+jwt" }, typ: nil) }

    token = JitSecurityJwtKeyring.encode({ "typ" => "payload-typ" }, typ: "at+jwt")

    assert_equal "at+jwt", JWT.decode(token, nil, false)[1]["typ"]
  end

  private

  def foreign_keys
    {
      "ES256" => OpenSSL::PKey::EC.generate("prime256v1"),
      "ES512" => OpenSSL::PKey::EC.generate("secp521r1"),
      "RS256" => OpenSSL::PKey::RSA.generate(2048),
      "PS256" => OpenSSL::PKey::RSA.generate(2048),
      "HS256" => "shared-secret",
      "none" => nil,
    }
  end

  def auth_parts
    token = AuthenticationToken.encode(
      clients(:one), host: AUTH_HOST, session_public_id: "sid", resource_type: "client",
    )
    JWT.decode(token, nil, false)
  end

  def resign_auth
    payload, header = auth_parts
    JWT.encode(yield(payload), AuthenticationJwtConfiguration.private_key, "ES384", header)
  end

  def decode_auth(token)
    AuthenticationToken.decode(token, host: AUTH_HOST, resource_type: "client")
  end

  def preference_host
    Rails.configuration.x.boot_config.fetch(:hosts).base_service.host
  end

  def preference_parts
    token = PreferenceToken.encode(
      { "lx" => "ja" }, host: preference_host, preference_type: "AppPreference",
                        public_id: "pref-public-id", jti: "pref-jti",
    )
    JWT.decode(token, nil, false)
  end

  def resign_preference
    payload, header = preference_parts
    JWT.encode(yield(payload), PreferenceJwtConfiguration.private_key_for_active, "ES384", header)
  end

  def decode_preference(token, host: preference_host)
    PreferenceToken.decode(token, host: host)
  end

  def with_production(&)
    Rails.stub(:env, ActiveSupport::StringInquirer.new("production"), &)
  end

  def with_env(vars)
    originals = vars.keys.index_with { |key| ENV.fetch(key, nil) }
    vars.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    originals.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
