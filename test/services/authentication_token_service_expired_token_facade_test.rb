# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthenticationTokenServiceExpiredTokenFacadeTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "expired access token facade returns signed claims while retaining other validation" do
    travel_to Time.utc(2026, 11, 6, 12) do
      now = Time.current.to_i
      payload = {
        "iss" => AuthenticationJwtConfiguration.issuer,
        "aud" => AuthenticationJwtConfiguration.audiences("client"),
        "exp" => now - 120,
        "iat" => now - 180,
        "nbf" => now - 180,
        "sub" => "expired-facade-subject",
        "sid" => "expired-facade-session",
        "client_id" => AuthenticationJwtConfiguration.client_id("client"),
        "jti" => "expired-facade-jti",
        "acr" => "aal1",
        "scope" => "openid domain:client",
      }
      token = JitSecurityJwtKeyring.encode(payload, typ: "at+jwt", issuer_id: "auth")

      assert_equal payload, AuthenticationTokenService.decode_allow_expired(
        token, host: "audit.example", resource_type: "client",
      )
      wrong_audience = JitSecurityJwtKeyring.encode(
        payload.merge("aud" => ["other-audience"]), typ: "at+jwt", issuer_id: "auth",
      )

      assert_nil AuthenticationTokenService.decode_allow_expired(
        wrong_audience, host: "audit.example", resource_type: "client",
      )
    end
  end

  test "expired access token facade rejects a forged signature" do
    now = Time.current.to_i
    payload = {
      "iss" => AuthenticationJwtConfiguration.issuer,
      "aud" => AuthenticationJwtConfiguration.audiences("client"),
      "exp" => now - 120,
      "iat" => now - 180,
      "nbf" => now - 180,
      "sub" => "forged-facade-subject",
      "sid" => "forged-facade-session",
      "client_id" => AuthenticationJwtConfiguration.client_id("client"),
      "jti" => "forged-facade-jti",
      "acr" => "aal1",
      "scope" => "openid domain:client",
    }
    forged = JWT.encode(
      payload, OpenSSL::PKey::EC.generate("secp384r1"), "ES384",
      { typ: "at+jwt", kid: JitSecurityJwtKeyring.active_kid("auth") },
    )

    assert_nil AuthenticationTokenService.decode_allow_expired(
      forged, host: "audit.example", resource_type: "client",
    )
  end
end
