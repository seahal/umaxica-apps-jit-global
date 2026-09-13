# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcIdTokenVerifierTest < ActiveSupport::TestCase
  setup do
    @client = OidcClientRegistry.find!("core-next-rp")
    @user = clients(:one)
    @nonce = "nonce-#{SecureRandom.hex(4)}"
    @issuer = OidcIssuer.for_client(@client)
    @jwt_issuer_id = OidcIssuer.jwt_issuer_id_for_client(@client)
  end

  test "accepts a valid id token for the expected client issuer actor and nonce" do
    result = verify(id_token)

    assert_predicate result, :success?
    assert_equal @issuer, result.payload.fetch("iss")
    assert_equal [@client.client_id], result.payload.fetch("aud")
    assert_equal "client", result.payload.fetch("act")
    assert_equal @nonce, result.payload.fetch("nonce")
    assert_equal result.payload.fetch("iat"), result.payload.fetch("nbf")
  end

  test "rejects wrong issuer audience nonce and actor type" do
    assert_invalid id_token(issuer: "https://evil.example")

    assert_invalid token_with_claims("aud" => [])
    assert_invalid token_with_claims("aud" => ["base-rails-rp"])
    assert_invalid token_with_claims("aud" => ["evil", @client.client_id])
    assert_invalid token_with_claims("aud" => [@client.client_id, "evil"])
    assert_invalid token_with_claims("aud" => @client.client_id)

    nonce_mismatch = verify(id_token, expected_nonce: "wrong-nonce")

    assert_not nonce_mismatch.success?
    assert_equal "nonce_mismatch", nonce_mismatch.error

    assert_invalid token_with_claims("act" => "operator")
  end

  test "accepts exactly one expected audience" do
    result = verify(id_token)

    assert_predicate result, :success?
    assert_equal [@client.client_id], result.payload.fetch("aud")
    assert_equal @client.client_id, result.canonical_audience
  end

  test "rejects expired tokens and unknown key ids" do
    assert_invalid id_token(issued_at: 10.minutes.ago, expires_at: 1.minute.ago)

    private_key = OpenSSL::PKey::EC.generate("secp384r1")
    forged = JWT.encode(valid_claims, private_key, "ES384", { typ: OidcIdTokenIssuer::TOKEN_TYPE, kid: "unknown" })

    assert_invalid forged
  end

  test "rejects non id-token typ and unsupported algorithms" do
    assert_invalid token_with_claims("typ" => "access-token+jwt")

    private_key = OpenSSL::PKey::EC.generate("prime256v1")
    forged = JWT.encode(valid_claims, private_key, "ES256", { typ: OidcIdTokenIssuer::TOKEN_TYPE, kid: "kid" })

    assert_invalid forged

    none_token = JWT.encode(valid_claims, nil, "none", { typ: OidcIdTokenIssuer::TOKEN_TYPE, kid: "kid" })

    assert_invalid none_token
  end

  test "rejects a case-variant algorithm before key verification" do
    JitSecurityJwtKeyring.stub(
      :parse_header,
      { "alg" => "eS384", "typ" => SecurityJwtOidcIdTokenCodec::TOKEN_TYPE, "kid" => "kid" },
    ) do
      assert_raises(JWT::DecodeError) do
        SecurityJwtOidcIdTokenCodec.decode(
          id_token: "not.a.jwt",
          client_id: @client.client_id,
          resource_type: "client",
          jwt_issuer_id: @jwt_issuer_id,
          issuer: @issuer,
        )
      end
    end
  end

  test "rejects missing nbf and invalid time ordering" do
    assert_invalid token_with_claims_without("nbf")
    assert_invalid token_with_claims("iat" => 5.minutes.from_now.to_i, "nbf" => 5.minutes.from_now.to_i)
    assert_invalid token_with_claims("nbf" => 10.minutes.from_now.to_i)
  end

  private

  def id_token(issuer: @issuer, issued_at: Time.current.utc, expires_at: 5.minutes.from_now)
    OidcIdTokenIssuer.call(
      resource: @user,
      client: @client,
      nonce: @nonce,
      issuer: issuer,
      issued_at: issued_at,
      expires_at: expires_at,
      jwt_issuer_id: @jwt_issuer_id,
    )
  end

  def token_with_claims(overrides)
    claims = valid_claims.merge(overrides)
    JitSecurityJwtKeyring.encode(claims, typ: claim_typ(claims), issuer_id: @jwt_issuer_id)
  end

  def token_with_claims_without(*keys)
    claims = valid_claims
    keys.each { |key| claims.delete(key) }
    JitSecurityJwtKeyring.encode(claims, typ: claim_typ(claims), issuer_id: @jwt_issuer_id)
  end

  # The forged header mirrors the payload typ so wrong-typ cases stay wrong in both places.
  def claim_typ(claims)
    claims.stringify_keys["typ"].presence || SecurityJwtOidcIdTokenCodec::TOKEN_TYPE
  end

  def valid_claims
    now = Time.current.utc.to_i
    {
      "iss" => @issuer,
      "sub" => OidcSubject.for(@user, resource_type: "client"),
      "aud" => [@client.client_id],
      "exp" => 5.minutes.from_now.to_i,
      "iat" => now,
      "nbf" => now,
      "jti" => SecureRandom.uuid,
      "typ" => OidcIdTokenIssuer::TOKEN_TYPE,
      "act" => "client",
      "sid" => SecureRandom.urlsafe_base64(18),
      "nonce" => @nonce,
      "acr" => "aal1",
    }
  end

  def verify(token, expected_nonce: @nonce)
    OidcIdTokenVerifier.call(
      id_token: token,
      client_id: @client.client_id,
      resource_type: "client",
      expected_nonce: expected_nonce,
      issuer: @issuer,
      jwt_issuer_id: @jwt_issuer_id,
    )
  end

  def assert_invalid(token)
    result = verify(token)

    assert_not result.success?
    assert_equal "invalid_id_token", result.error
  end
end
