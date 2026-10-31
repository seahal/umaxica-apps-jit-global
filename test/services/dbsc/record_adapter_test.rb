# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class DbscRecordAdapterTest < ActiveSupport::TestCase
  test "binding_method_attribute delegates to model metadata" do
    assert_equal :user_token_binding_method_id, DbscRecordAdapter.binding_method_attribute(ClientToken.new)
    assert_equal :staff_token_binding_method_id, DbscRecordAdapter.binding_method_attribute(OperatorToken.new)
  end

  test "dbsc_status_attribute delegates to model metadata" do
    assert_equal :user_token_dbsc_status_id, DbscRecordAdapter.dbsc_status_attribute(ClientToken.new)
    assert_equal :staff_token_dbsc_status_id, DbscRecordAdapter.dbsc_status_attribute(OperatorToken.new)
  end

  test "binding_method_class returns ClientTokenBindingMethod" do
    record = ClientToken.new

    result = DbscRecordAdapter.binding_method_class(record)

    assert_equal ClientTokenBindingMethod, result
  end

  test "binding_method_class returns OperatorTokenBindingMethod" do
    record = OperatorToken.new

    result = DbscRecordAdapter.binding_method_class(record)

    assert_equal OperatorTokenBindingMethod, result
  end

  test "binding_method_class raises for unsupported record" do
    record = Struct.new(:id).new(1)

    assert_raises(ArgumentError) { DbscRecordAdapter.binding_method_class(record) }
  end

  test "binding_method_attribute raises for unsupported record" do
    record = Struct.new(:id).new(1)

    assert_raises(ArgumentError) { DbscRecordAdapter.binding_method_attribute(record) }
  end

  test "dbsc_status_attribute raises for unsupported record" do
    record = Struct.new(:id).new(1)

    assert_raises(ArgumentError) { DbscRecordAdapter.dbsc_status_attribute(record) }
  end

  test "normalize_public_key returns nil for blank key" do
    result = DbscRecordAdapter.normalize_public_key(nil)

    assert_nil result
  end

  test "normalize_public_key returns nil for empty string" do
    result = DbscRecordAdapter.normalize_public_key("")

    assert_nil result
  end

  test "normalize_public_key parses JSON string" do
    json = '{"kid":"key1"}'

    result = DbscRecordAdapter.normalize_public_key(json)

    assert_equal "key1", result["kid"]
  end

  test "normalize_public_key handles hash input" do
    hash = { "kid" => "key1" }

    result = DbscRecordAdapter.normalize_public_key(hash)

    assert_equal "key1", result["kid"]
  end

  test "normalize_public_key handles object with to_h" do
    record = Struct.new(:to_h).new({ "kid" => "key1" })

    result = DbscRecordAdapter.normalize_public_key(record)

    assert_equal "key1", result["kid"]
  end

  # DBSC binds a session to a key only the device holds. A symmetric JWK would
  # make the verification key equal to the signing secret, so the resolver must
  # refuse it outright rather than leaving the invariant to the caller.
  test "verification_key_from_jwk rejects symmetric key types" do
    error =
      assert_raises(DbscRecordAdapter::PublicKeyError) do
        DbscRecordAdapter.verification_key_from_jwk(
          { "kty" => "oct", "k" => "c2VjcmV0" }, source: "test JWK",
        )
      end

    assert_match(/asymmetric/, error.message)
  end

  test "verification_key_from_jwk resolves an asymmetric JWK to a private-key-free verifier" do
    private_key = OpenSSL::PKey::EC.generate("prime256v1")
    jwk = JWT::JWK.new(private_key).export.deep_stringify_keys

    key = DbscRecordAdapter.verification_key_from_jwk(jwk, source: "test JWK")

    # Never a String: that is the shape an HMAC secret would take, and it is
    # what keeps JWT.decode from treating the key as a shared secret.
    assert_kind_of OpenSSL::PKey::PKey, key
    assert_not key.private?
  end

  test "verification_key_from_jwk raises instead of returning nil for unusable input" do
    ["", nil, {}, { "kty" => "bogus" }].each do |raw_key|
      assert_raises(DbscRecordAdapter::PublicKeyError, raw_key.inspect) do
        DbscRecordAdapter.verification_key_from_jwk(raw_key, source: "test JWK")
      end
    end
  end
end
