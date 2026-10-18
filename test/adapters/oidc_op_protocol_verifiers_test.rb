# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcOpProtocolVerifiersTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  CLIENT_ID = "core-app-jp"
  REALM = "app"
  ISSUER = "https://base.example/app"
  AUDIENCE = "core-app-jp"

  setup do
    @private_key = OpenSSL::PKey::EC.generate("secp384r1")
    @rotated_private_key = OpenSSL::PKey::EC.generate("secp384r1")
  end

  test "access verifier accepts a target token using only the fixed public JWKS" do
    result = access_verifier(token: access_token).call

    assert_predicate result, :success?, "error=#{result.error.inspect} fetches=#{@jwks_fetches}"
    assert_equal CLIENT_ID, result.payload.fetch("client_id")
    assert_equal 1, @jwks_fetches
  end

  test "access verifier rejects profile confusion and binding mismatches" do
    valid_payload = access_payload
    cases = {
      "wrong JOSE type" => [valid_payload, { typ: "id-token+jwt" }],
      "wrong issuer" => [valid_payload.merge("iss" => "https://other.example/app"), {}],
      "wrong audience" => [valid_payload.merge("aud" => ["other-client"]), {}],
      "wrong client" => [valid_payload.merge("client_id" => "warp-app-jp"), {}],
      "wrong realm scope" => [valid_payload.merge("scope" => "openid domain:operator"), {}],
      "wrong contract epoch" => [valid_payload.merge("umx_contract_epoch" => 2), {}],
      "unknown authentication context" => [valid_payload.merge("authn_ctx" => "standby"), {}],
      "missing session binding" => [valid_payload.except("sid"), {}],
    }

    cases.each do |label, (payload, header_overrides)|
      token = encode(payload, header: { "kid" => "access-a" }.merge(header_overrides))
      result = access_verifier(token: token).call

      assert_not_predicate result, :success?, label
    end
  end

  test "access verifier rejects a token carrying a key or URL header" do
    token = encode(access_payload, header: { "kid" => "access-a", "jku" => "https://attacker.example/jwks" })

    result = access_verifier(token: token).call

    assert_not_predicate result, :success?
    assert_equal 0, @jwks_fetches
  end

  test "an unknown kid gets one bounded rotation fetch" do
    first_jwk = public_jwk(@private_key, kid: "access-a")
    rotated_jwk = public_jwk(@rotated_private_key, kid: "access-b")
    documents = [{ "keys" => [first_jwk] }, { "keys" => [rotated_jwk] }]
    fetcher =
      lambda do
        @jwks_fetches += 1
        documents.fetch(@jwks_fetches - 1, documents.last)
      end
    token = encode(access_payload, key: @rotated_private_key, kid: "access-b")

    result = access_verifier(token: token, fetcher: fetcher).call

    assert_predicate result, :success?, "error=#{result.error.inspect} fetches=#{@jwks_fetches}"
    assert_equal 2, @jwks_fetches
  end

  test "a known key can use a briefly stale cache but an unknown key cannot" do
    @jwks_fetches = 0
    clock = [Time.current]
    fetcher =
      lambda do
        @jwks_fetches += 1
        raise OidcOpJwksClient::FetchError, "JWKS unavailable" if @jwks_fetches > 1

        { "keys" => [public_jwk(@private_key, kid: "access-a")] }
      end
    client = jwks_client(fetcher: fetcher, clock: -> { clock.first })

    assert client.public_key_for("access-a")
    clock[0] += OidcOpJwksClient::CACHE_TTL + 1.minute

    assert client.public_key_for("access-a")

    clock[0] += OidcOpJwksClient::MAX_STALE_TTL + 1.second

    assert_nil client.public_key_for("access-a")
  end

  test "JWKS client rejects duplicate, private and oversized key documents" do
    jwk = public_jwk(@private_key, kid: "access-a")
    invalid_documents = [
      { "keys" => [jwk, jwk] },
      { "keys" => [jwk.merge("d" => "private")] },
      { "keys" => Array.new(OidcOpJwksClient::MAXIMUM_KEYS + 1) { jwk } },
    ]

    invalid_documents.each do |document|
      client = jwks_client(fetcher: -> { document })

      assert_nil client.public_key_for("access-a")
    end
  end

  test "ID verifier accepts exact client nonce and resource bindings" do
    result = id_verifier(token: id_token).call

    assert_predicate result, :success?
    assert_equal CLIENT_ID, result.payload.fetch("aud").first
  end

  test "access verifier rejects a floating point contract epoch despite numeric equality" do
    now = Time.current.to_i
    token = JWT.encode(
      { "iss" => ISSUER,
        "aud" => [CLIENT_ID],
        "exp" => now + 300,
        "nbf" => now - 5,
        "iat" => now - 5,
        "sub" => "subject",
        "sid" => "sid",
        "client_id" => CLIENT_ID,
        "jti" => "epoch-type",
        "scope" => "openid",
        "umx_contract_epoch" => 1.0,
        "authn_ctx" => "normal", },
      @private_key, "ES384", { "kid" => "epoch-key", "typ" => "at+jwt" },
    )
    client = OidcOpJwksClient.new(
      jwks_uri: "https://base.example/.well-known/jwks.json",
      fetcher: -> { { "keys" => [JitSecurityJwtJwk.export_public(@private_key, kid: "epoch-key")] } },
    )
    result = OidcOpAccessTokenVerifier.new(
      access_token: token, client_id: CLIENT_ID, realm: REALM, issuer: ISSUER,
      audience: AUDIENCE, contract_epoch: 1, jwks_client: client,
    ).call

    assert_not_predicate result, :success?
  end

  test "a successful JWKS rotation removing a known key cannot restore its stale trust" do
    now = Time.current
    fetch_count = 0
    old_jwk = JitSecurityJwtJwk.export_public(@private_key, kid: "old")
    new_jwk = JitSecurityJwtJwk.export_public(@rotated_private_key, kid: "new")
    client = OidcOpJwksClient.new(
      jwks_uri: "https://base.example/.well-known/jwks.json", clock: -> { now },
      fetcher: -> {
        fetch_count += 1
        { "keys" => [(fetch_count == 1) ? old_jwk : new_jwk] }
      },
    )

    assert client.public_key_for("old")
    now += OidcOpJwksClient::CACHE_TTL + 1.second

    assert_nil client.public_key_for("old")
    assert client.public_key_for("new")
    assert_equal 2, fetch_count
  end

  test "JWKS outage obeys fresh and final stale trust boundaries and never trusts an unknown kid" do
    base = Time.current
    [OidcOpJwksClient::CACHE_TTL, OidcOpJwksClient::CACHE_TTL + OidcOpJwksClient::MAX_STALE_TTL].each do |limit|
      [-0.001, 0, 0.001].each do |offset|
        now = base
        fetch_count = 0
        client = OidcOpJwksClient.new(
          jwks_uri: "https://base.example/.well-known/jwks.json", clock: -> { now },
          fetcher: -> {
            fetch_count += 1
            raise OidcOpJwksClient::FetchError, "unavailable" if fetch_count > 1

            { "keys" => [JitSecurityJwtJwk.export_public(@private_key, kid: "known")] }
          },
        )

        assert client.public_key_for("known")
        now = base + limit + offset
        if limit + offset <= OidcOpJwksClient::CACHE_TTL + OidcOpJwksClient::MAX_STALE_TTL
          assert client.public_key_for("known"), "age=#{limit + offset}"
        else
          assert_nil client.public_key_for("known")
        end

        assert_nil client.public_key_for("unknown")
      end
    end
  end

  test "an OP key rotation during a JWKS outage refuses the new key until a successful fetch" do
    old_jwk = public_jwk(@private_key, kid: "access-a")
    new_jwk = public_jwk(@rotated_private_key, kid: "access-b")
    outage = true
    fetch_count = 0
    client = jwks_client(
      fetcher: -> {
        fetch_count += 1
        next { "keys" => [old_jwk] } if fetch_count == 1
        raise OidcOpJwksClient::FetchError, "unavailable" if outage

        { "keys" => [old_jwk, new_jwk] }
      },
    )
    verify =
      lambda do |token|
        OidcOpAccessTokenVerifier.new(
          access_token: token, client_id: CLIENT_ID, realm: REALM, issuer: ISSUER,
          audience: AUDIENCE, contract_epoch: 1, jwks_client: client,
          expected_authentication_context: "normal",
        ).call
      end
    old_token = encode(access_payload)
    new_token = encode(access_payload, key: @rotated_private_key, kid: "access-b")
    forged_token = encode(access_payload, key: OpenSSL::PKey::EC.generate("secp384r1"), kid: "access-a")

    assert_predicate verify.call(old_token), :success?
    assert_not_predicate verify.call(new_token), :success?
    assert_equal 2, fetch_count, "a kid miss during the outage makes exactly one refetch"
    assert_predicate verify.call(old_token), :success?, "a failed refetch keeps the fresh cached key"
    assert_not_predicate verify.call(forged_token), :success?
    assert_equal 2, fetch_count

    outage = false

    assert_predicate verify.call(new_token), :success?
    assert_equal 3, fetch_count
    assert_predicate verify.call(old_token), :success?
  end

  test "ID verifier rejects nonce, audience, type and max-age mismatches" do
    cases = {
      "wrong nonce" => id_payload.merge("nonce" => "other-nonce"),
      "wrong audience" => id_payload.merge("aud" => ["other-client"]),
      "wrong payload type" => id_payload.merge("typ" => "at+jwt"),
      "wrong resource" => id_payload.merge("act" => "operator"),
      "stale authentication" => id_payload.merge("auth_time" => 1),
    }

    cases.each do |label, payload|
      result = id_verifier(token: encode(payload, typ: OidcOpIdTokenVerifier::TOKEN_TYPE)).call

      assert_not_predicate result, :success?, label
    end
  end

  private

  def access_verifier(token:, fetcher: nil, clock: -> { Time.current })
    @jwks_fetches ||= 0
    OidcOpAccessTokenVerifier.new(
      access_token: token,
      client_id: CLIENT_ID,
      realm: REALM,
      issuer: ISSUER,
      audience: AUDIENCE,
      contract_epoch: 1,
      jwks_client: jwks_client(fetcher: fetcher, clock: clock),
      expected_authentication_context: "normal",
    )
  end

  def id_verifier(token:)
    OidcOpIdTokenVerifier.new(
      id_token: token,
      client_id: CLIENT_ID,
      realm: REALM,
      issuer: ISSUER,
      expected_nonce: "nonce-1",
      expected_max_age: 60,
      expected_resource_type: "client",
      jwks_client: jwks_client,
    )
  end

  def jwks_client(fetcher: nil, clock: -> { Time.current })
    @jwks_fetches ||= 0
    fetcher ||=
      lambda do
        @jwks_fetches += 1
        { "keys" => [public_jwk(@private_key, kid: "access-a")] }
      end
    OidcOpJwksClient.new(
      jwks_uri: "https://base.example/.well-known/jwks.json",
      fetcher: fetcher,
      clock: clock,
    )
  end

  def access_token
    encode(access_payload)
  end

  def access_payload
    now = Time.current.to_i
    {
      "iss" => ISSUER,
      "aud" => [AUDIENCE],
      "exp" => now + 300,
      "nbf" => now - 5,
      "iat" => now - 5,
      "sub" => "principal-1",
      "sid" => "sid-1",
      "client_id" => CLIENT_ID,
      "jti" => "jti-1",
      "scope" => "openid domain:client read:self",
      "umx_contract_epoch" => 1,
      "authn_ctx" => "normal",
    }
  end

  def id_token
    encode(id_payload, typ: OidcOpIdTokenVerifier::TOKEN_TYPE)
  end

  def id_payload
    now = Time.current.to_i
    {
      "iss" => ISSUER,
      "aud" => [CLIENT_ID],
      "exp" => now + 300,
      "nbf" => now - 5,
      "iat" => now - 5,
      "sub" => "principal-1",
      "nonce" => "nonce-1",
      "jti" => "jti-1",
      "sid" => "sid-1",
      "typ" => OidcOpIdTokenVerifier::TOKEN_TYPE,
      "act" => "client",
      "auth_time" => now - 5,
    }
  end

  def encode(payload, key: @private_key, kid: "access-a", typ: OidcOpAccessTokenVerifier::TOKEN_TYPE,
             header: {})
    JWT.encode(
      payload, key, OidcOpAccessTokenVerifier::ALGORITHM,
      { "kid" => kid, "alg" => OidcOpAccessTokenVerifier::ALGORITHM, "typ" => typ }.merge(header),
    )
  end

  def public_jwk(key, kid:)
    JitSecurityJwtJwk.export_public(key, kid: kid)
  end
end
