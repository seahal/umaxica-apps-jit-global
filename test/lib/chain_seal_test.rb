# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "chain_seal"

class ChainSealTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @private_key = OpenSSL::PKey::EC.generate("secp384r1")
    @payload = {
      "event" => "auth.sign_in.succeeded",
      "metadata" => { "b" => 2, "a" => 1 },
      "result" => true,
    }
  end

  test "seals and verifies a payload with a temporary P-384 key" do
    seal = ChainSeal.seal(payload: @payload, kid: "test-kid", private_key: @private_key)

    assert ChainSeal.verify(compact: seal.compact, payload: @payload, public_key: @private_key.public_key)
    assert_equal ChainSeal::GENESIS_PREVIOUS_HASH, seal.previous_hash
    assert_match(/\A\h{64}\z/, seal.block_hash)
  end

  test "canonical payload ignores hash key insertion order" do
    left = { "z" => 1, "a" => { "b" => 2, "a" => 1 } }
    right = { "a" => { "a" => 1, "b" => 2 }, "z" => 1 }

    left_seal = ChainSeal.seal(payload: left, kid: "test-kid", private_key: @private_key)
    right_seal = ChainSeal.seal(payload: right, kid: "test-kid", private_key: @private_key)

    assert_equal left_seal.block_hash, right_seal.block_hash
    assert ChainSeal.verify(compact: left_seal.compact, payload: right, public_key: @private_key.public_key)
  end

  test "compact string uses fixed fields and base64url raw signature" do
    seal = ChainSeal.seal(payload: @payload, kid: "kid_1", private_key: @private_key)
    parts = seal.compact.split("$", -1)

    assert_equal ["", "bc1", "jcs-rfc8785", "sha3-256", "es384"], parts.first(5)
    assert_equal 9, parts.size
    assert_equal "kid_1", parts.fetch(5)
    assert_equal 96, Base64.urlsafe_decode64(ChainSeal.pad_base64(parts.fetch(8))).bytesize
    assert_not_includes parts.fetch(8), "="
  end

  test "external json exposes compact fields" do
    seal = ChainSeal.seal(payload: @payload, kid: "kid-1", private_key: @private_key)

    assert_equal(
      {
        format: "bc1",
        canonicalization_alg: "jcs-rfc8785",
        hash_alg: "sha3-256",
        signature_alg: "es384",
        kid: "kid-1",
        previous_hash: ChainSeal::GENESIS_PREVIOUS_HASH,
        block_hash: seal.block_hash,
        signature: seal.signature,
      },
      seal.as_json,
    )
  end

  test "tampered payload fails verification" do
    seal = ChainSeal.seal(payload: @payload, kid: "test-kid", private_key: @private_key)

    assert_raises(ChainSeal::VerificationError) do
      ChainSeal.verify(
        compact: seal.compact,
        payload: @payload.merge("result" => false),
        public_key: @private_key.public_key,
      )
    end
  end

  test "tampered compact fields fail parsing or verification" do
    seal = ChainSeal.seal(payload: @payload, kid: "test-kid", private_key: @private_key)

    assert_raises(ChainSeal::FormatError) { ChainSeal.parse(seal.compact.sub("sha3-256", "sha256")) }
    assert_raises(ChainSeal::FormatError) { ChainSeal.parse(seal.compact.sub("es384", "hs256")) }
    assert_raises(ChainSeal::FormatError) { ChainSeal.parse(seal.compact.sub("test-kid", "kid=value")) }
    assert_raises(ChainSeal::FormatError) { ChainSeal.parse(seal.compact.delete_prefix("$")) }
    assert_raises(ChainSeal::VerificationError) do
      ChainSeal.verify(
        compact: seal.compact.sub(seal.block_hash, "f" * 64),
        payload: @payload,
        public_key: @private_key.public_key,
      )
    end
  end

  test "rejects invalid hashes and key-value compact strings" do
    assert_raises(ChainSeal::FormatError) do
      ChainSeal.seal(payload: @payload, previous_hash: "0" * 63, kid: "kid", private_key: @private_key)
    end

    assert_raises(ChainSeal::FormatError) do
      ChainSeal.parse("$bc1$jcs-rfc8785$sha3-256$es384$kid=1$#{"0" * 64}$#{"1" * 64}$abc")
    end
  end

  test "rejects non P-384 keys" do
    wrong_key = OpenSSL::PKey::EC.generate("prime256v1")

    assert_raises(ChainSeal::FormatError) do
      ChainSeal.seal(payload: @payload, kid: "kid", private_key: wrong_key)
    end
  end

  test "verify accepts an EC::Point as the public key" do
    seal = ChainSeal.seal(payload: @payload, kid: "point-kid", private_key: @private_key)
    public_key = @private_key.public_key
    point = public_key.is_a?(OpenSSL::PKey::EC::Point) ? public_key : public_key.public_key

    assert_instance_of OpenSSL::PKey::EC::Point, point
    assert ChainSeal.verify(compact: seal.compact, payload: @payload, public_key: point)
  end

  test "verify rejects an EC::Point from a mismatched key" do
    seal = ChainSeal.seal(payload: @payload, kid: "point-kid", private_key: @private_key)
    other_key = OpenSSL::PKey::EC.generate(ChainSeal::ES384_CURVE)
    other_public = other_key.public_key
    other_point = other_public.is_a?(OpenSSL::PKey::EC::Point) ? other_public : other_public.public_key

    assert_raises(ChainSeal::VerificationError) do
      ChainSeal.verify(compact: seal.compact, payload: @payload, public_key: other_point)
    end
  end

  test "create_public_key_from_point rejects a non P-384 point" do
    wrong_key = OpenSSL::PKey::EC.generate("prime256v1")
    wrong_public = wrong_key.public_key
    wrong_point = wrong_public.is_a?(OpenSSL::PKey::EC::Point) ? wrong_public : wrong_public.public_key
    seal = ChainSeal.seal(payload: @payload, kid: "point-kid", private_key: @private_key)

    assert_raises(ChainSeal::FormatError) do
      ChainSeal.verify(compact: seal.compact, payload: @payload, public_key: wrong_point)
    end
  end

  test "canonicalize raises FormatError for a non-canonicalizable payload" do
    assert_raises(ChainSeal::FormatError) do
      ChainSeal.canonicalize(Float::NAN)
    end
  end

  test "seal raises FormatError when payload cannot be canonicalized" do
    assert_raises(ChainSeal::FormatError) do
      ChainSeal.seal(payload: { "x" => Float::NAN }, kid: "kid", private_key: @private_key)
    end
  end

  test "to_h exposes the compact field hash directly" do
    seal = ChainSeal.seal(payload: @payload, kid: "to_h-kid", private_key: @private_key)

    assert_equal seal.as_json, seal.to_h
    assert_equal "to_h-kid", seal.to_h.fetch(:kid)
  end
  test "parse refuses a compact seal whose fixed fields were rewritten" do
    parts = ChainSeal.seal(payload: @payload, kid: "test-kid", private_key: @private_key).compact.split("$", -1)
    rewritten = {
      "version" => [1, "bc2", "unsupported version"],
      "canonicalization" => [2, "json", "unsupported canonicalization"],
      "kid" => [5, "kid with space", "kid contains unsupported characters"],
      "empty signature" => [8, "", "signature is required"],
      "non-base64url signature" => [8, "abc+/def", "signature must be base64url"],
      "short signature" => [8, "AAAA", "signature must be #{ChainSeal::ES384_RAW_SIGNATURE_BYTES} bytes"],
    }

    rewritten.each do |label, (index, value, message)|
      tampered = parts.dup
      tampered[index] = value

      error = assert_raises(ChainSeal::FormatError, label) { ChainSeal.parse(tampered.join("$")) }

      assert_includes error.message, message, label
    end
  end

  test "parse refuses a padded signature as a key-value compact string" do
    parts = ChainSeal.seal(payload: @payload, kid: "test-kid", private_key: @private_key).compact.split("$", -1)
    parts[8] = "#{parts[8]}=="

    assert_raises(ChainSeal::FormatError) { ChainSeal.parse(parts.join("$")) }
  end

  test "seal refuses a public-only key" do
    public_only = OpenSSL::PKey::EC.new(@private_key.public_to_der)

    error =
      assert_raises(ChainSeal::FormatError) do
        ChainSeal.seal(payload: @payload, kid: "test-kid", private_key: public_only)
      end
    assert_includes error.message, "private key is required"
  end

  test "verify refuses a signature produced by another key over the same block" do
    genuine = ChainSeal.seal(payload: @payload, kid: "test-kid", private_key: @private_key)
    forged = ChainSeal.seal(payload: @payload, kid: "test-kid", private_key: OpenSSL::PKey::EC.generate("secp384r1"))
    parts = genuine.compact.split("$", -1)
    parts[8] = forged.signature

    error =
      assert_raises(ChainSeal::VerificationError) do
        ChainSeal.verify(compact: parts.join("$"), payload: @payload, public_key: @private_key)
      end
    assert_equal "invalid signature", error.message
  end
end
