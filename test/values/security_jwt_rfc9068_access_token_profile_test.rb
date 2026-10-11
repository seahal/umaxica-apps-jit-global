# typed: false
# frozen_string_literal: true

require "test_helper"

class SecurityJwtRfc9068AccessTokenProfileTest < ActiveSupport::TestCase
  test "auth access token header and required claims follow the RFC 9068 profile" do
    token = AuthenticationToken.encode(
      clients(:one), host: "example.com", session_public_id: "sid", resource_type: "client",
    )
    payload, header = JWT.decode(token, nil, false)

    assert_equal "at+jwt", header["typ"]
    assert_equal "ES384", header["alg"]
    assert_predicate header["kid"], :present?
    %w(iss exp aud sub client_id iat jti).each do |claim|
      assert payload.key?(claim), "missing #{claim}"
    end
    assert_kind_of String, payload["sub"]
    assert_equal clients(:one).id.to_s, payload["sub"]
    assert_equal AuthenticationJwtConfiguration.client_id("client"), payload["client_id"]
    assert_equal AuthenticationJwtConfiguration.issuer, payload["iss"]
    assert_equal AuthenticationJwtConfiguration.audiences("client"), payload["aud"]
    assert_equal "authenticated domain:client read:self write:self", payload["scope"]
    assert_nil payload["scp"]
    assert_nil payload["typ"]
    assert_nil payload["act"]
    assert_equal "aal1", payload["acr"]
    assert_equal "sid", payload["sid"]
  end

  test "preference access token header and required claims follow the RFC 9068 profile" do
    public_id = "pref-public-id"
    token = PreferenceToken.encode(
      { "lx" => "ja" },
      host: "app.localhost",
      preference_type: "AppPreference",
      public_id: public_id,
      jti: "pref-jti",
    )
    payload, header = JWT.decode(token, nil, false)

    assert_equal "at+jwt", header["typ"]
    assert_equal "ES384", header["alg"]
    assert_predicate header["kid"], :present?
    %w(iss exp aud sub client_id iat jti).each do |claim|
      assert payload.key?(claim), "missing #{claim}"
    end
    assert_equal public_id, payload["sub"]
    assert_equal PreferenceJwtConfiguration.client_id, payload["client_id"]
    assert_equal PreferenceJwtConfiguration.issuer, payload["iss"]
    assert_equal "preference", payload["scope"]
    assert_equal({ "lx" => "ja" }, payload["preferences"])
    assert_nil payload["typ"]
    assert_nil payload["act"]
    assert_nil payload["scp"]
  end

  test "auth access verification rejects wrong JOSE typ, missing typ, and none alg" do
    token = AuthenticationToken.encode(
      clients(:one), host: "example.com", session_public_id: "sid", resource_type: "client",
    )
    payload, header = JWT.decode(token, nil, false)
    key = AuthenticationJwtConfiguration.private_key

    wrong_typ = JWT.encode(payload, key, "ES384", header.merge("typ" => "auth-access-token;client"))
    missing_typ = JWT.encode(payload, key, "ES384", header.except("typ"))
    none_alg = JWT.encode(payload, nil, "none", header.merge("alg" => "none"))

    assert_nil AuthenticationToken.decode(wrong_typ, host: "example.com", resource_type: "client")
    assert_nil AuthenticationToken.decode(missing_typ, host: "example.com", resource_type: "client")
    assert_nil AuthenticationToken.decode(none_alg, host: "example.com", resource_type: "client")
  end

  test "auth access verification rejects expired tokens and wrong issuer or audience" do
    token = AuthenticationToken.encode(
      clients(:one), host: "example.com", session_public_id: "sid", resource_type: "client",
    )
    payload, header = JWT.decode(token, nil, false)
    key = AuthenticationJwtConfiguration.private_key

    expired = JWT.encode(payload.merge("exp" => 1.hour.ago.to_i), key, "ES384", header)
    wrong_iss = JWT.encode(payload.merge("iss" => "urn:umaxica:other:auth"), key, "ES384", header)
    wrong_aud = JWT.encode(payload.merge("aud" => ["not-this-resource"]), key, "ES384", header)

    assert_nil AuthenticationToken.decode(expired, host: "example.com", resource_type: "client")
    assert_nil AuthenticationToken.decode(wrong_iss, host: "example.com", resource_type: "client")
    assert_nil AuthenticationToken.decode(wrong_aud, host: "example.com", resource_type: "client")
  end

  test "auth access verification rejects a development issuer when expecting the test issuer" do
    token = AuthenticationToken.encode(
      clients(:one), host: "example.com", session_public_id: "sid", resource_type: "client",
    )
    payload, header = JWT.decode(token, nil, false)
    key = AuthenticationJwtConfiguration.private_key
    foreign = JWT.encode(
      payload.merge("iss" => "urn:umaxica:development:auth"),
      key,
      "ES384",
      header,
    )

    assert_nil AuthenticationToken.decode(foreign, host: "example.com", resource_type: "client")
  end

  test "production auth audience configuration rejects localhost" do
    error =
      assert_raises(ArgumentError) do
        with_env("AUTH_JWT_CLIENT_AUDIENCES" => "umaxica-api-client,app.localhost") do
          Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
            AuthenticationJwtConfiguration.audiences("client")
          end
        end
      end

    assert_match(/non-production identifiers: app\.localhost/, error.message)
  end

  test "production preference audience configuration rejects localhost" do
    error =
      assert_raises(ArgumentError) do
        Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
          PreferenceJwtConfiguration.stub(:audiences_from_boot_config, %w(www.umaxica.app localhost)) do
            PreferenceJwtConfiguration.audiences
          end
        end
      end

    assert_match(/non-production identifiers: localhost/, error.message)
  end

  private

  def with_env(vars)
    originals = vars.keys.index_with { |key| ENV.fetch(key, nil) }
    vars.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    originals.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
