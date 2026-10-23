# typed: false
# frozen_string_literal: true

require "test_helper"

class JwtTemporalValidationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "auth access enforces the fixed thirty second iat nbf and exp boundaries" do
    travel_to Time.utc(2026, 10, 22, 12) do
      now = Time.current.to_i
      payload = {
        "iss" => AuthenticationJwtConfiguration.issuer,
        "aud" => AuthenticationJwtConfiguration.audiences("client"),
        "exp" => now + 300,
        "iat" => now - 60,
        "nbf" => now - 60,
        "sub" => "temporal-subject",
        "sid" => "temporal-session",
        "client_id" => AuthenticationJwtConfiguration.client_id("client"),
        "jti" => "temporal-jti",
        "acr" => "aal1",
        "scope" => "openid domain:client",
      }
      cases = [
        ["iat", now + 29, true], ["iat", now + 30, true], ["iat", now + 31, false],
        ["nbf", now + 29, true], ["nbf", now + 30, true], ["nbf", now + 31, false],
        ["exp", now - 29, true], ["exp", now - 30, false], ["exp", now - 31, false],
      ]
      cases.each do |claim, value, accepted|
        token = JitSecurityJwtKeyring.encode(payload.merge(claim => value), typ: "at+jwt", issuer_id: "auth")
        result = SecurityJwtAuthAccessTokenCodec.decode(token, host: "audit.example", resource_type: "client")

        assert_equal accepted, result.present?, "#{claim}=#{value - now}"
      end
    end
  end

  test "expired access decoding relaxes only expiration and preserves signature issuer audience and nbf checks" do
    travel_to Time.utc(2026, 10, 22, 12) do
      now = Time.current.to_i
      payload = {
        "iss" => AuthenticationJwtConfiguration.issuer,
        "aud" => AuthenticationJwtConfiguration.audiences("client"),
        "exp" => now + 300,
        "iat" => now - 60,
        "nbf" => now - 60,
        "sub" => "temporal-subject",
        "sid" => "temporal-session",
        "client_id" => AuthenticationJwtConfiguration.client_id("client"),
        "jti" => "temporal-jti",
        "acr" => "aal1",
        "scope" => "openid domain:client",
      }
      payload["exp"] = now - 120
      payload["iat"] = payload["nbf"] = now - 180
      token = JitSecurityJwtKeyring.encode(payload, typ: "at+jwt", issuer_id: "auth")

      assert_nil SecurityJwtAuthAccessTokenCodec.decode(token, host: "audit.example", resource_type: "client")
      assert_equal payload, SecurityJwtAuthAccessTokenCodec.decode_allow_expired(
        token, host: "audit.example", resource_type: "client",
      )

      [
        payload.merge("iss" => "urn:other:auth"),
        payload.merge("aud" => ["other-audience"]),
        payload.merge("nbf" => now + 31),
        payload.merge("iat" => now + 31),
        payload.except("exp"),
      ].each do |invalid_payload|
        invalid = JitSecurityJwtKeyring.encode(invalid_payload, typ: "at+jwt", issuer_id: "auth")

        assert_nil SecurityJwtAuthAccessTokenCodec.decode_allow_expired(
          invalid, host: "audit.example", resource_type: "client",
        )
      end

      forged = JWT.encode(
        payload, OpenSSL::PKey::EC.generate("secp384r1"), "ES384",
        { typ: "at+jwt", kid: JitSecurityJwtKeyring.active_kid("auth") },
      )

      assert_nil SecurityJwtAuthAccessTokenCodec.decode_allow_expired(
        forged, host: "audit.example", resource_type: "client",
      )
    end
  end

  test "preference access enforces the fixed thirty second iat nbf and exp boundaries" do
    travel_to Time.utc(2026, 10, 22, 12) do
      now = Time.current.to_i
      host = Rails.configuration.x.boot_config.fetch(:hosts).base_service.host
      original = PreferenceToken.encode(
        { "lx" => "ja" }, host: host, preference_type: "AppPreference",
                          public_id: "temporal-preference", jti: "temporal-jti",
      )
      payload, header = JWT.decode(original, nil, false)
      payload.merge!("iat" => now - 60, "nbf" => now - 60, "exp" => now + 300)
      cases = [
        ["iat", now + 29, true], ["iat", now + 30, true], ["iat", now + 31, false],
        ["nbf", now + 29, true], ["nbf", now + 30, true], ["nbf", now + 31, false],
        ["exp", now - 29, true], ["exp", now - 30, false], ["exp", now - 31, false],
      ]
      cases.each do |claim, value, accepted|
        token = JWT.encode(
          payload.merge(claim => value), PreferenceJwtConfiguration.private_key_for_active, "ES384", header,
        )

        assert_equal accepted, PreferenceToken.decode(token, host: host).present?, "#{claim}=#{value - now}"
      end
    end
  end

  test "shared OIDC ID verification enforces the fixed thirty second iat nbf and exp boundaries" do
    travel_to Time.utc(2026, 10, 22, 12) do
      now = Time.current.to_i
      issuer = OidcIssuer.for_resource_type("client")
      issuer_id = OidcIssuer.jwt_issuer_id_for_resource_type("client")
      payload = {
        "iss" => issuer,
        "aud" => ["core-app-jp"],
        "exp" => now + 300,
        "iat" => now - 60,
        "nbf" => now - 60,
        "sub" => "temporal-subject",
        "sid" => "temporal-session",
        "jti" => "temporal-jti",
        "nonce" => "temporal-nonce",
        "typ" => "id-token+jwt",
        "act" => "client",
      }
      cases = [
        ["iat", now + 29, true], ["iat", now + 30, true], ["iat", now + 31, false],
        ["nbf", now + 29, true], ["nbf", now + 30, true], ["nbf", now + 31, false],
        ["exp", now - 29, true], ["exp", now - 30, false], ["exp", now - 31, false],
      ]
      cases.each do |claim, value, accepted|
        token = SecurityJwtOidcIdTokenCodec.encode(payload.merge(claim => value), issuer_id: issuer_id)
        result = OidcIdTokenVerifier.call(
          id_token: token, client_id: "core-app-jp", resource_type: "client", expected_nonce: "temporal-nonce",
          jwt_issuer_id: issuer_id, issuer: issuer,
        )

        assert_equal accepted, result.success?, "#{claim}=#{value - now}"
      end
    end
  end

  test "separated RP access verification enforces the fixed thirty second iat nbf and exp boundaries" do
    travel_to Time.utc(2026, 10, 22, 12) do
      now = Time.current.to_i
      issuer = "https://base.example/app"
      key = OpenSSL::PKey::EC.generate("secp384r1")
      jwk = JitSecurityJwtJwk.export_public(key, kid: "temporal-key")
      jwks_client = OidcOpJwksClient.new(
        jwks_uri: "https://base.example/.well-known/jwks.json",
        fetcher: -> { { "keys" => [jwk] } },
      )
      payload = {
        "iss" => issuer,
        "aud" => ["core-app-jp"],
        "exp" => now + 240,
        "iat" => now - 60,
        "nbf" => now - 60,
        "sub" => "temporal-subject",
        "sid" => "temporal-session",
        "jti" => "temporal-jti",
        "client_id" => "core-app-jp",
        "scope" => "openid",
        "authn_ctx" => "normal",
      }
      cases = [
        ["iat", now + 29, true], ["iat", now + 30, true], ["iat", now + 31, false],
        ["nbf", now + 29, true], ["nbf", now + 30, true], ["nbf", now + 31, false],
        ["exp", now - 29, true], ["exp", now - 30, false], ["exp", now - 31, false],
      ]
      cases.each do |claim, value, accepted|
        token = JWT.encode(payload.merge(claim => value), key, "ES384", { typ: "at+jwt", kid: "temporal-key" })
        result = OidcOpAccessTokenVerifier.new(
          access_token: token, client_id: "core-app-jp", realm: "app", issuer: issuer,
          audience: "core-app-jp", jwks_client: jwks_client,
        ).call

        assert_equal accepted, result.success?, "#{claim}=#{value - now}"
      end
    end
  end

  test "separated RP ID verification enforces the fixed thirty second iat nbf and exp boundaries" do
    travel_to Time.utc(2026, 10, 22, 12) do
      now = Time.current.to_i
      issuer = "https://base.example/app"
      key = OpenSSL::PKey::EC.generate("secp384r1")
      jwk = JitSecurityJwtJwk.export_public(key, kid: "temporal-key")
      jwks_client = OidcOpJwksClient.new(
        jwks_uri: "https://base.example/.well-known/jwks.json",
        fetcher: -> { { "keys" => [jwk] } },
      )
      payload = {
        "iss" => issuer,
        "aud" => ["core-app-jp"],
        "exp" => now + 240,
        "iat" => now - 60,
        "nbf" => now - 60,
        "sub" => "temporal-subject",
        "sid" => "temporal-session",
        "jti" => "temporal-jti",
        "nonce" => "temporal-nonce",
        "typ" => "id-token+jwt",
        "act" => "client",
      }
      cases = [
        ["iat", now + 29, true], ["iat", now + 30, true], ["iat", now + 31, false],
        ["nbf", now + 29, true], ["nbf", now + 30, true], ["nbf", now + 31, false],
        ["exp", now - 29, true], ["exp", now - 30, false], ["exp", now - 31, false],
      ]
      cases.each do |claim, value, accepted|
        token = JWT.encode(payload.merge(claim => value), key, "ES384", { typ: "id-token+jwt", kid: "temporal-key" })
        result = OidcOpIdTokenVerifier.new(
          id_token: token, client_id: "core-app-jp", realm: "app", issuer: issuer,
          expected_nonce: "temporal-nonce", jwks_client: jwks_client,
        ).call

        assert_equal accepted, result.success?, "#{claim}=#{value - now}"
      end
    end
  end

  test "separated RP logout verification enforces the fixed thirty second iat nbf and exp boundaries" do
    travel_to Time.utc(2026, 10, 22, 12) do
      now = Time.current.to_i
      issuer = "https://base.example/app"
      key = OpenSSL::PKey::EC.generate("secp384r1")
      jwk = JitSecurityJwtJwk.export_public(key, kid: "temporal-key")
      jwks_client = OidcOpJwksClient.new(
        jwks_uri: "https://base.example/.well-known/jwks.json",
        fetcher: -> { { "keys" => [jwk] } },
      )
      payload = {
        "iss" => issuer,
        "aud" => ["core-app-jp"],
        "exp" => now + 240,
        "iat" => now - 60,
        "nbf" => now - 60,
        "sub" => "temporal-subject",
        "sid" => "temporal-session",
        "jti" => "temporal-jti",
        "events" => { OidcOpLogoutTokenVerifier::EVENT => {} },
      }
      cases = [
        ["iat", now + 29, true], ["iat", now + 30, true], ["iat", now + 31, false],
        ["nbf", now + 29, true], ["nbf", now + 30, true], ["nbf", now + 31, false],
        ["exp", now - 29, true], ["exp", now - 30, false], ["exp", now - 31, false],
      ]
      cases.each do |claim, value, accepted|
        token = JWT.encode(payload.merge(claim => value), key, "ES384", { typ: "logout+jwt", kid: "temporal-key" })
        result = OidcOpLogoutTokenVerifier.new(
          logout_token: token, client_id: "core-app-jp", issuer: issuer, jwks_client: jwks_client,
        ).call

        assert_equal accepted, result.success?, "#{claim}=#{value - now}"
      end
    end
  end

  test "client assertions enforce the fixed thirty second iat boundary" do
    travel_to Time.utc(2026, 10, 22, 12) do
      now = Time.current
      token_url = OidcIssuer.token_endpoint("client")
      [[29, true], [30, true], [31, false]].each do |offset, accepted|
        token = OidcClientAssertionJwt.issue(
          client_id: "core-app-jp", token_url: token_url, now: now + offset,
        )

        assert_equal accepted, OidcClientAssertionJwt.valid?(
          client_id: "core-app-jp", assertion: token, token_url: token_url, now: now,
        ), "iat=now+#{offset}"
      end
    end
  end
end
