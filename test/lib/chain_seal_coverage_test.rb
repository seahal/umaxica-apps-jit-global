# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "chain_seal"

class ChainSealCoverageTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @private_key = OpenSSL::PKey::EC.generate("secp384r1")
    @payload = { "event" => "coverage", "nested" => { "b" => 2, "a" => 1 } }
  end

  test "parse rejects empty compact seals" do
    assert_raises(ChainSeal::FormatError) { ChainSeal.parse(nil) }
    assert_raises(ChainSeal::FormatError) { ChainSeal.parse("") }
    assert_raises(ChainSeal::FormatError) { ChainSeal.parse("k=v") }
  end

  test "seal rejects invalid kid and hash formats" do
    assert_raises(ChainSeal::FormatError) do
      ChainSeal.seal(payload: @payload, kid: "", private_key: @private_key)
    end

    assert_raises(ChainSeal::FormatError) do
      ChainSeal.seal(payload: @payload, kid: "kid", previous_hash: "x" * 63, private_key: @private_key)
    end
  end

  test "verify rejects tampered payload and malformed signatures" do
    seal = ChainSeal.seal(payload: @payload, kid: "kid-1", private_key: @private_key)

    assert_raises(ChainSeal::VerificationError) do
      ChainSeal.verify(
        compact: seal.compact, payload: @payload.merge("event" => "other"),
        public_key: @private_key.public_key,
      )
    end

    assert_raises(ChainSeal::FormatError) do
      ChainSeal.parse(seal.compact.sub(seal.signature, "bad"))
    end
  end

  test "verify accepts a non-Point OpenSSL::PKey::EC public key via validate_public_key!" do
    seal = ChainSeal.seal(payload: @payload, kid: "ec-kid", private_key: @private_key)
    public_ec = OpenSSL::PKey::EC.new(@private_key.public_to_der)

    assert_instance_of OpenSSL::PKey::EC, public_ec
    assert_not_predicate public_ec, :private?
    assert_not public_ec.is_a?(OpenSSL::PKey::EC::Point)

    assert ChainSeal.verify(compact: seal.compact, payload: @payload, public_key: public_ec)
  end

  test "verify rejects a non-EC public key with FormatError" do
    seal = ChainSeal.seal(payload: @payload, kid: "kid-1", private_key: @private_key)
    rsa = OpenSSL::PKey::RSA.generate(1024)

    assert_raises(ChainSeal::FormatError) do
      ChainSeal.verify(compact: seal.compact, payload: @payload, public_key: rsa)
    end
  end
end
