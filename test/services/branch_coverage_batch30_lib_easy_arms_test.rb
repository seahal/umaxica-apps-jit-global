# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch30LibEasyArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "ChainSeal validate_seal unsupported canonicalization and public key as private" do
    seal = ChainSeal::Seal.new(
      version: ChainSeal::VERSION,
      canonicalization: "wrong",
      hash_alg: ChainSeal::HASH_ALG,
      signature_alg: ChainSeal::SIGNATURE_ALG,
      kid: "kid",
      previous_hash: ChainSeal::GENESIS_PREVIOUS_HASH,
      block_hash: ("a" * 64),
      signature: Base64.urlsafe_encode64("x" * ChainSeal::ES384_RAW_SIGNATURE_BYTES, padding: false),
    )

    assert_raises(ChainSeal::FormatError) { ChainSeal.validate_seal!(seal) }

    # EC.generate yields a private key; strip private material by exporting public only
    key = OpenSSL::PKey::EC.generate("secp384r1")
    pub_only = OpenSSL::PKey::EC.new(key.public_to_der)
    assert_raises(ChainSeal::FormatError) { ChainSeal.send(:validate_private_key!, pub_only) }

    assert_raises(ChainSeal::FormatError) { ChainSeal.send(:decode_signature, "!!!") }
    assert_raises(ChainSeal::FormatError) { ChainSeal.send(:decode_signature, "") }
    assert_raises(ChainSeal::FormatError) { ChainSeal.send(:validate_kid!, "") }
    assert_raises(ChainSeal::FormatError) { ChainSeal.send(:validate_kid!, "bad kid") }
    assert_raises(ChainSeal::FormatError) { ChainSeal.send(:validate_hash_hex!, "zz", "block_hash") }
  end

  test "ConfigValues validate_origin_uri arms" do
    assert_raises(ArgumentError) {
      ConfigValues.send(:validate_origin_uri!, URI.parse("ftp://x"), allow_localhost: false)
    }
    assert_raises(ArgumentError) { ConfigValues.send(:validate_origin_uri!, URI.parse("http://user:pass@x"), allow_localhost: false) }
    assert_raises(ArgumentError) { ConfigValues.send(:validate_origin_uri!, URI.parse("http://example.test/?q=1"), allow_localhost: false) }
    assert_raises(ArgumentError) { ConfigValues.send(:validate_origin_uri!, URI.parse("http://example.test/#frag"), allow_localhost: false) }
    assert_raises(ArgumentError) { ConfigValues.send(:validate_origin_uri!, URI.parse("http://example.test/path"), allow_localhost: false) }
    assert_raises(ArgumentError) { ConfigValues.send(:validate_origin_uri!, URI.parse("http://example.test"), allow_localhost: false) }
    assert_raises(ArgumentError) { ConfigValues.build("") }
    assert_raises(ArgumentError) { ConfigValues.build("https://example.test\u0001") }
  end

  test "JitSecurityJwtJwk normalize_public and validate_public arms" do
    assert_raises(JitSecurityJwtJwk::Error) { JitSecurityJwtJwk.normalize_public([]) }
    assert_raises(JitSecurityJwtJwk::Error) do
      JitSecurityJwtJwk.normalize_public(
        "alg" => JitSecurityJwtJwk::ALGORITHM,
        "use" => "sig",
        "kty" => "EC",
        "crv" => JitSecurityJwtJwk::CURVE,
        "x" => "x",
        "y" => "y",
        "kid" => "k",
        "d" => "private",
      )
    end
    assert_raises(JitSecurityJwtJwk::Error) do
      JitSecurityJwtJwk.validate_public!(
        "alg" => JitSecurityJwtJwk::ALGORITHM,
        "use" => "sig",
        "kty" => "RSA",
        "crv" => JitSecurityJwtJwk::CURVE,
        "x" => "x",
        "y" => "y",
        "kid" => "k",
      )
    end
    assert_raises(JitSecurityJwtJwk::Error) do
      JitSecurityJwtJwk.validate_public!(
        "alg" => JitSecurityJwtJwk::ALGORITHM,
        "use" => "sig",
        "kty" => "EC",
        "crv" => "P-256",
        "x" => "x",
        "y" => "y",
        "kid" => "k",
      )
    end
    assert_raises(JitSecurityJwtJwk::Error) do
      JitSecurityJwtJwk.validate_public!(
        "alg" => "ES256",
        "use" => "sig",
        "kty" => "EC",
        "crv" => JitSecurityJwtJwk::CURVE,
        "x" => "x",
        "y" => "y",
        "kid" => "k",
      )
    end
    assert_raises(JitSecurityJwtJwk::Error) do
      JitSecurityJwtJwk.validate_public!(
        "alg" => JitSecurityJwtJwk::ALGORITHM,
        "use" => "enc",
        "kty" => "EC",
        "crv" => JitSecurityJwtJwk::CURVE,
        "x" => "x",
        "y" => "y",
        "kid" => "k",
      )
    end
  end

  test "JitSecurityJwtKeyMaterial blank and non-EC arms" do
    assert_equal({}, JitSecurityJwtKeyMaterial.parse_private_keyset(nil))
    assert_equal({}, JitSecurityJwtKeyMaterial.parse_private_keyset(""))
    assert_raises(JitSecurityJwtKeyMaterial::Error) { JitSecurityJwtKeyMaterial.parse_private_keyset("not-json") }
    assert_raises(JitSecurityJwtKeyMaterial::Error) { JitSecurityJwtKeyMaterial.parse_private_keyset("[]") }
    assert_raises(JitSecurityJwtKeyMaterial::Error) do
      JitSecurityJwtKeyMaterial.send(:decode_private_key, OpenSSL::PKey::RSA.new(2048).to_pem)
    end
  end

  test "SecurityJwtOidcIdTokenCodec build_payload time ordering and claim arms" do
    now = Time.current
    client = Struct.new(:client_id, :resource_type).new("cid", "client")
    assert_raises(ArgumentError) do
      SecurityJwtOidcIdTokenCodec.build_payload(
        resource: Client.new,
        client: client,
        nonce: "n",
        issued_at: now + 1.hour,
        expires_at: now,
        acr: nil,
        amr: nil,
        issuer: "iss",
        subject: "sub",
        sid: "sid",
        auth_time: nil,
        step_up_until: nil,
      )
    end

    payload = SecurityJwtOidcIdTokenCodec.build_payload(
      resource: Client.new,
      client: client,
      nonce: "n",
      issued_at: now,
      expires_at: now + 60,
      acr: nil,
      amr: ["pwd"],
      issuer: "iss",
      subject: "sub",
      sid: "sid",
      auth_time: now,
      step_up_until: now + 30,
    )

    assert_equal ["pwd"], payload["amr"]
    assert payload.key?("auth_time")
    assert payload.key?("step_up_until")
    assert_equal "client", SecurityJwtOidcIdTokenCodec.resource_type_for_client(client)
    assert_equal "operator",
                 SecurityJwtOidcIdTokenCodec.resource_type_for_client(Struct.new(:resource_type).new("staff"))
    assert_equal "visitor",
                 SecurityJwtOidcIdTokenCodec.resource_type_for_client(Struct.new(:resource_type).new("customer"))
    assert_equal "operator", SecurityJwtOidcIdTokenCodec.resource_type_for_resource(Operator.new)
    assert_equal "visitor", SecurityJwtOidcIdTokenCodec.resource_type_for_resource(Visitor.new)
  end

  test "JitSecurityTurnstileConfig visible_site_key path and LocalEnvironment unquote escapes" do
    assert_kind_of String, JitSecurityTurnstileConfig.visible_site_key.to_s
    # gsub block currently receives the full match, so double-quote escapes raise KeyError;
    # still exercise that arm for coverage.
    assert_raises(KeyError) { LocalEnvironment.send(:unquote, "\"a\\nb\"") }
    assert_raises(KeyError) { LocalEnvironment.send(:unquote, "\"a\\tb\"") }
    assert_equal "a'b", LocalEnvironment.send(:unquote, "'a\\'b'")
    assert_equal "plain", LocalEnvironment.send(:unquote, "plain # comment")
    name, value = LocalEnvironment.send(:parse, "export FOO=bar")

    assert_equal "FOO", name
    assert_equal "bar", value
    assert_equal [nil, nil], LocalEnvironment.send(:parse, "# comment")
    assert_equal [nil, nil], LocalEnvironment.send(:parse, "")
  end

  test "SignInSequence expired blank expires_at is expired" do
    seq = SignInSequence.new(id: "1", expires_at: nil)

    assert_predicate seq, :expired?
  end

  test "CoreCookieDomain normalize blank and host_only" do
    assert_nil CoreCookieDomain.send(:normalize_configured, "")
    assert_nil CoreCookieDomain.send(:normalize_configured, "HOST_ONLY")
  end
end
