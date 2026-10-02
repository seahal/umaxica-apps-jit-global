# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class JumpRtReturnVerifierTest < ActiveSupport::TestCase
  JWKS_URL = "https://jump.umaxica.net/.well-known/jwks.json"

  self.fixture_table_names = []

  setup do
    @private_key = OpenSSL::PKey::EC.generate("secp384r1")
    @public_jwk = JWT::JWK.new(@private_key, kid: "jump-test").export.stringify_keys.except("d").merge(
      "alg" => "ES384",
      "use" => "sig",
    )
    @now = Time.current.change(usec: 0)
    @previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @previous_cache
  end

  test "verifies jump-signed return token against configured jwks" do
    token = sign_return_token

    result = verify(token)

    assert_predicate result, :success?
    assert_equal "https://jump.umaxica.net", result.payload.fetch("iss")
    assert_equal "https://auth.umaxica.app", result.payload.fetch("src")
  end

  test "a reusable return token verifies repeatedly and records no consumed jti" do
    token = sign_return_token(jti: "reusable-jti")

    assert_no_difference -> { SecurityConsumedJti.count } do
      assert_predicate verify(token), :success?
      assert_predicate verify(token), :success?
    end
  end

  test "rpl exact reuse is the only accepted replay policy" do
    assert_predicate verify(sign_return_token(rpl: "reuse")), :success?
  end

  test "rpl missing is rejected rather than treated as reuse" do
    assert_equal "invalid_claim", verify(sign_return_token_without(:rpl)).error
  end

  {
    "null" => nil,
    "empty string" => "",
    "once" => "once",
    "capitalized" => "Reuse",
    "uppercase" => "REUSE",
    "other string" => "single",
    "NUL suffix" => "reuse\u0000",
    "padded" => " reuse",
    "zero" => 0,
    "false" => false,
    "true" => true,
    "array" => ["reuse"],
    "empty array" => [],
    "object" => { "rpl" => "reuse" },
    "empty object" => {},
  }.each do |label, value|
    test "rpl #{label} is rejected" do
      assert_equal "invalid_claim", verify(sign_return_token(rpl: value)).error
    end
  end

  test "rejects wrong audience" do
    token = sign_return_token(aud: "https://www.umaxica.com")

    assert_equal "audience_mismatch", verify(token).error
  end

  test "rejects wrong issuer" do
    token = sign_return_token(iss: "https://evil.example")

    assert_equal "issuer_mismatch", verify(token).error
  end

  test "rejects an expired token" do
    token = sign_return_token(iat: @now.to_i - 20, nbf: @now.to_i - 20, exp: @now.to_i - 10)

    assert_equal "invalid_claim", verify(token).error
  end

  test "rejects a token that is not yet valid" do
    token = sign_return_token(nbf: @now.to_i + 20, exp: @now.to_i + 30)

    assert_equal "invalid_claim", verify(token).error
  end

  test "rejects a tampered payload with a valid header" do
    token = sign_return_token
    parts = token.split(".")
    payload = JSON.parse(Base64.urlsafe_decode64(parts[1]))
    payload["dst"] = "external"
    parts[1] = Base64.urlsafe_encode64(JSON.generate(payload), padding: false)

    assert_equal "invalid_signature", verify(parts.join(".")).error
  end

  test "rejects the same kid signed with a different private key" do
    other_key = OpenSSL::PKey::EC.generate("secp384r1")
    token = sign_return_token_with(other_key)

    assert_equal "invalid_signature", verify(token).error
  end

  test "rejects none es256 and rs256 algorithms" do
    payload = return_payload
    none_header = Base64.urlsafe_encode64({ typ: "JWT", alg: "none", kid: "jump-test" }.to_json, padding: false)
    none_payload = Base64.urlsafe_encode64(JSON.generate(payload), padding: false)
    none = "#{none_header}.#{none_payload}.e30"
    es256_key = OpenSSL::PKey::EC.generate("prime256v1")
    es256 = JWT.encode(payload, es256_key, "ES256", { typ: "JWT", kid: "jump-test" })
    rsa_key = OpenSSL::PKey::RSA.generate(2048)
    rs256 = JWT.encode(payload, rsa_key, "RS256", { typ: "JWT", kid: "jump-test" })

    assert_equal "invalid_header", verify(none).error
    assert_equal "invalid_header", verify(es256).error
    assert_equal "invalid_header", verify(rs256).error
  end

  test "rejects wrong source for destination origin" do
    token = sign_return_token(src: "https://auth.umaxica.com")

    assert_equal "invalid_claim", verify(token).error
  end

  test "rejects the retired logical ceremony issuer as source" do
    token = sign_return_token(src: "https://log.umaxica.app")

    assert_equal "invalid_claim", verify(token).error
  end

  test "rejects when token url does not match current request without rt" do
    token = sign_return_token(url: "https://www.umaxica.app/other")

    assert_equal "invalid_url", verify(token).error
  end

  test "matches token url to request when query parameter order differs" do
    token = sign_return_token(url: "https://www.umaxica.app/path?ok=1&extra=2")

    result = JumpRtReturnVerifier.call(
      token: token,
      request_url: "https://www.umaxica.app/path?extra=2&rt=#{token}&ok=1",
      request_base_url: "https://www.umaxica.app",
      fetcher: -> { { "keys" => [@public_jwk] } },
      now: @now,
    )

    assert_predicate result, :success?
  end

  test "rejects jwks entries with private material" do
    token = sign_return_token
    jwks = { "keys" => [@public_jwk.merge("d" => "private")] }

    result = JumpRtReturnVerifier.call(
      token: token,
      request_url: "https://www.umaxica.app/path?ok=1&rt=#{token}",
      request_base_url: "https://www.umaxica.app",
      fetcher: -> { jwks },
      now: @now,
    )

    assert_equal "unknown_kid", result.error
  end

  test "rejects excessive ttl" do
    token = sign_return_token(exp: @now.to_i + 1.hour.to_i)

    assert_equal "invalid_claim", verify(token).error
  end

  test "refreshes jwks once when kid is missing from cached set" do
    token = sign_return_token
    calls = 0
    fetcher =
      lambda do
        calls += 1
        { "keys" => (calls == 1) ? [] : [@public_jwk] }
      end

    result = JumpRtReturnVerifier.call(
      token: token,
      request_url: "https://www.umaxica.app/path?ok=1&rt=#{token}",
      request_base_url: "https://www.umaxica.app",
      fetcher: fetcher,
      now: @now,
    )

    assert_predicate result, :success?
    assert_equal 2, calls
  end

  test "negative caches unknown kid after forced refresh misses" do
    token = sign_return_token
    calls = 0
    fetcher =
      lambda do
        calls += 1
        { "keys" => [] }
      end

    2.times do
      result = JumpRtReturnVerifier.call(
        token: token,
        request_url: "https://www.umaxica.app/path?ok=1&rt=#{token}",
        request_base_url: "https://www.umaxica.app",
        fetcher: fetcher,
        now: @now,
      )

      assert_equal "unknown_kid", result.error
    end

    assert_equal 2, calls
  end

  test "rejects locally revoked kid before using cached jwks" do
    token = sign_return_token
    jump = ConfigValues::JumpGatewayValues.build(
      env: { "PUBLIC_JUMP_GATEWAY_URL" => "https://jump.umaxica.net", "JUMP_RETURN_REVOKED_KIDS" => "jump-test" },
    )

    Rails.configuration.x.stub(:boot_config, Rails.configuration.x.boot_config.merge(jump: jump)) do
      assert_equal "revoked_kid", verify(token).error
    end
  end

  test "fails closed when jwks refresh fails even if a stale cache exists" do
    token = sign_return_token
    jwks_url = "https://jump.umaxica.net/.well-known/jwks.json"
    stale_key = "jump_rt:return_jwks:stale:#{Digest::SHA256.hexdigest(jwks_url)}"
    Rails.cache.write(stale_key, { "keys" => [@public_jwk] }, expires_in: 1.hour)

    result = JumpRtReturnVerifier.call(
      token: token,
      request_url: "https://www.umaxica.app/path?ok=1&rt=#{token}",
      request_base_url: "https://www.umaxica.app",
      fetcher: -> { raise JWT::DecodeError, "offline" },
      now: @now,
    )

    assert_equal "jwks_unavailable", result.error
  end

  test "rejects invalid url in token payload" do
    token = sign_return_token(url: "not a valid url")

    assert_equal "invalid_url", verify(token).error
  end

  test "rejects missing oversized and non compact tokens before signature checks" do
    assert_equal "missing_token", verify("").error
    assert_equal "malformed", verify("a." * ((JumpRtReturnVerifier::MAX_TOKEN_LENGTH / 2) + 2)).error
    assert_equal "malformed", verify("not-a-jwt").error
  end

  test "rejects payload claim mismatches that the happy path does not exercise" do
    assert_includes %w(invalid_claim invalid_signature), verify(sign_return_token(schema: 2)).error
    assert_includes %w(invalid_claim invalid_signature), verify(sign_return_token(sub: "other")).error
    assert_includes %w(invalid_claim invalid_signature), verify(sign_return_token(dst: "external")).error
    assert_includes %w(invalid_claim invalid_signature), verify(sign_return_token(jti: "")).error
    assert_includes %w(invalid_claim invalid_signature), verify(sign_return_token(src: "")).error
    assert_includes %w(invalid_claim invalid_signature),
                    verify(sign_return_token(nbf: @now.to_i + 90, exp: @now.to_i + 60)).error
  end

  test "rejects http claimed urls in the local environment too" do
    token = sign_return_token(aud: "http://www.umaxica.app", url: "http://www.umaxica.app/path?ok=1")

    result = JumpRtReturnVerifier.call(
      token: token,
      request_url: "http://www.umaxica.app/path?ok=1&rt=#{token}",
      request_base_url: "http://www.umaxica.app",
      fetcher: -> { { "keys" => [@public_jwk] } },
      now: @now,
    )

    assert_predicate Rails.env, :local?
    assert_equal "invalid_url", result.error
  end

  test "rejects claimed urls that include userinfo or fragments" do
    assert_equal "invalid_url", verify(sign_return_token(url: "https://user:pass@www.umaxica.app/path?ok=1")).error
    assert_equal "invalid_url", verify(sign_return_token(url: "https://www.umaxica.app/path?ok=1#frag")).error
  end

  test "call rejects invalid header" do
    verifier = JumpRtReturnVerifier.new(
      token: "a.b.c",
      request_url: "https://www.umaxica.app/path",
      request_base_url: "https://www.umaxica.app",
      fetcher: -> { { "keys" => [] } },
      now: @now,
    )
    verifier.stub(:parse_header, { "alg" => "none", "typ" => "JWT", "kid" => "x" }) do
      result = verifier.call

      assert_not result.success?
      assert_equal "invalid_header", result.error
    end
  end

  test "fails closed when the jwks fetcher returns something other than a json object" do
    token = sign_return_token

    result = JumpRtReturnVerifier.call(
      token: token,
      request_url: "https://www.umaxica.app/path?ok=1&rt=#{token}",
      request_base_url: "https://www.umaxica.app",
      fetcher: -> { [@public_jwk] },
      now: @now,
    )

    assert_equal "jwks_unavailable", result.error
  end

  test "default fetcher reads the JWKS URI derived from PUBLIC_JUMP_GATEWAY_URL" do
    token = sign_return_token
    response = Struct.new(:success?, :body).new(true, { "keys" => [@public_jwk] }.to_json)
    requested = []
    connection = Object.new
    connection.define_singleton_method(:get) do |uri|
      requested << uri.to_s
      response
    end

    result =
      OutboundHttp::Connection.stub(:build, connection) do
        JumpRtReturnVerifier.call(
          token: token,
          request_url: "https://www.umaxica.app/path?ok=1&rt=#{token}",
          request_base_url: "https://www.umaxica.app",
          now: @now,
        )
      end

    assert_predicate result, :success?
    assert_equal [JWKS_URL], requested
  end

  test "default fetcher fails closed on a non-success jwks response" do
    token = sign_return_token
    response = Struct.new(:success?, :body).new(false, { "keys" => [@public_jwk] }.to_json)
    connection = Object.new
    connection.define_singleton_method(:get) { |_uri| response }

    result =
      OutboundHttp::Connection.stub(:build, connection) do
        JumpRtReturnVerifier.call(
          token: token,
          request_url: "https://www.umaxica.app/path?ok=1&rt=#{token}",
          request_base_url: "https://www.umaxica.app",
          now: @now,
        )
      end

    assert_equal "jwks_unavailable", result.error
  end

  test "default fetcher accepts a jwks body at the size limit and rejects one byte above it" do
    token = sign_return_token
    jwks_json = { "keys" => [@public_jwk] }.to_json
    at_limit = jwks_json + (" " * (JumpRtReturnVerifier::MAX_JWKS_BYTES - jwks_json.bytesize))
    results =
      [at_limit, "#{at_limit} "].map do |body|
        Rails.cache.clear
        response = Struct.new(:success?, :body).new(true, body)
        connection = Object.new
        connection.define_singleton_method(:get) { |_uri| response }
        OutboundHttp::Connection.stub(:build, connection) do
          JumpRtReturnVerifier.call(
            token: token,
            request_url: "https://www.umaxica.app/path?ok=1&rt=#{token}",
            request_base_url: "https://www.umaxica.app",
            now: @now,
          )
        end
      end

    assert_predicate results.first, :success?
    assert_equal "jwks_unavailable", results.last.error
  end

  private

  def verify(token)
    JumpRtReturnVerifier.call(
      token: token,
      request_url: "https://www.umaxica.app/path?ok=1&rt=#{token}",
      request_base_url: "https://www.umaxica.app",
      fetcher: -> { { "keys" => [@public_jwk] } },
      now: @now,
    )
  end

  def sign_return_token(overrides = {})
    JWT.encode(return_payload.merge(overrides), @private_key, "ES384", { typ: "JWT", kid: "jump-test" })
  end

  def sign_return_token_with(private_key, overrides = {})
    JWT.encode(return_payload.merge(overrides), private_key, "ES384", { typ: "JWT", kid: "jump-test" })
  end

  def return_payload
    iat = @now.to_i
    {
      schema: 1,
      iss: "https://jump.umaxica.net",
      aud: "https://www.umaxica.app",
      sub: "jump-redirect",
      iat: iat,
      nbf: iat,
      exp: iat + 30,
      jti: "jump-return-jti",
      src: "https://auth.umaxica.app",
      dst: "internal",
      rpl: "reuse",
      url: "https://www.umaxica.app/path?ok=1",
    }
  end

  def sign_return_token_without(claim)
    JWT.encode(return_payload.except(claim), @private_key, "ES384", { typ: "JWT", kid: "jump-test" })
  end
end
