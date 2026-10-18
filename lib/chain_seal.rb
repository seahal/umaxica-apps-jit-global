# frozen_string_literal: true

require "base64"
require "active_support/security_utils"
require "json/canonicalization"
require "openssl"

module ChainSeal
  VERSION = "bc1"
  CANONICALIZATION = "jcs-rfc8785"
  HASH_ALG = "sha3-256"
  SIGNATURE_ALG = "es384"
  DELIMITER = "$"
  SHA3_256_HEX_LENGTH = 64
  GENESIS_PREVIOUS_HASH = "0" * SHA3_256_HEX_LENGTH
  ES384_CURVE = "secp384r1"
  ES384_DIGEST = "SHA384"
  ES384_COMPONENT_BYTES = 48
  ES384_RAW_SIGNATURE_BYTES = ES384_COMPONENT_BYTES * 2

  HEX_64_PATTERN = /\A\h{64}\z/
  KID_PATTERN = /\A[A-Za-z0-9._:-]+\z/
  BASE64URL_PATTERN = /\A[A-Za-z0-9_-]+\z/

  class Error < StandardError; end

  class FormatError < Error; end

  class VerificationError < Error; end

  Seal =
    Struct.new(
      :version,
      :canonicalization,
      :hash_alg,
      :signature_alg,
      :kid,
      :previous_hash,
      :block_hash,
      :signature,
      keyword_init: true,
    ) do
      def compact
        [
          "",
          version,
          canonicalization,
          hash_alg,
          signature_alg,
          kid,
          previous_hash,
          block_hash,
          signature,
        ].join(DELIMITER)
      end

      def to_h
        {
          format: version,
          canonicalization_alg: canonicalization,
          hash_alg: hash_alg,
          signature_alg: signature_alg,
          kid: kid,
          previous_hash: previous_hash,
          block_hash: block_hash,
          signature: signature,
        }
      end

      def as_json(*)
        to_h
      end
    end

  module_function

  def seal(payload:, kid:, private_key:, previous_hash: GENESIS_PREVIOUS_HASH)
    validate_kid!(kid)
    validate_hash_hex!(previous_hash, "previous_hash")
    validate_private_key!(private_key)

    canonical_payload = canonicalize(payload)
    block_hash = block_hash_for(previous_hash: previous_hash, canonical_payload: canonical_payload)
    signature = sign_block_hash(block_hash, private_key)

    Seal.new(
      version: VERSION,
      canonicalization: CANONICALIZATION,
      hash_alg: HASH_ALG,
      signature_alg: SIGNATURE_ALG,
      kid: kid,
      previous_hash: previous_hash,
      block_hash: block_hash,
      signature: signature,
    )
  end

  def parse(compact)
    raise FormatError, "compact seal is required" if compact.nil? || compact.to_s.empty?
    raise FormatError, "compact seal must not use key-value fields" if compact.to_s.include?("=")

    parts = compact.to_s.split(DELIMITER, -1)
    raise FormatError, "compact seal has invalid delimiter structure" unless parts.size == 9 && parts.first == ""

    seal = Seal.new(
      version: parts.fetch(1),
      canonicalization: parts.fetch(2),
      hash_alg: parts.fetch(3),
      signature_alg: parts.fetch(4),
      kid: parts.fetch(5),
      previous_hash: parts.fetch(6),
      block_hash: parts.fetch(7),
      signature: parts.fetch(8),
    )
    validate_seal!(seal)
    seal
  end

  def verify(compact:, payload:, public_key:)
    seal = parse(compact)
    verification_key = public_key_for_verification(public_key)

    canonical_payload = canonicalize(payload)
    expected_hash = block_hash_for(previous_hash: seal.previous_hash, canonical_payload: canonical_payload)
    raise VerificationError, "block hash mismatch" unless secure_compare(expected_hash, seal.block_hash)

    raw_signature = decode_signature(seal.signature)
    verify_raw_signature(verification_key, block_hash_bytes(seal.block_hash), raw_signature)
  rescue FormatError, VerificationError
    raise
  rescue OpenSSL::PKey::PKeyError, OpenSSL::ASN1::ASN1Error, ArgumentError => e
    raise VerificationError, e.message
  end

  def canonicalize(payload)
    payload.to_json_c14n
  rescue RangeError, NoMethodError, TypeError => e
    raise FormatError, "payload is not JCS canonicalizable: #{e.message}"
  end

  def block_hash_for(previous_hash:, canonical_payload:)
    validate_hash_hex!(previous_hash, "previous_hash")
    digest = OpenSSL::Digest.new("SHA3-256")
    digest.hexdigest(previous_hash.b + canonical_payload.to_s.b)
  end

  def sign_block_hash(block_hash, private_key)
    digest = OpenSSL::Digest.new(ES384_DIGEST).digest(block_hash_bytes(block_hash))
    der_signature = private_key.dsa_sign_asn1(digest)
    Base64.urlsafe_encode64(asn1_to_raw_signature(der_signature), padding: false)
  end

  def verify_raw_signature(public_key, data, raw_signature)
    digest = OpenSSL::Digest.new(ES384_DIGEST).digest(data)
    verified = public_key.dsa_verify_asn1(digest, raw_to_asn1_signature(raw_signature))
    raise VerificationError, "invalid signature" unless verified

    true
  end

  def validate_seal!(seal)
    raise FormatError, "unsupported version" unless seal.version == VERSION
    raise FormatError, "unsupported canonicalization" unless seal.canonicalization == CANONICALIZATION
    raise FormatError, "unsupported hash algorithm" unless seal.hash_alg == HASH_ALG
    raise FormatError, "unsupported signature algorithm" unless seal.signature_alg == SIGNATURE_ALG

    validate_kid!(seal.kid)
    validate_hash_hex!(seal.previous_hash, "previous_hash")
    validate_hash_hex!(seal.block_hash, "block_hash")
    decode_signature(seal.signature)
    seal
  end

  def validate_kid!(kid)
    raise FormatError, "kid is required" if kid.nil? || kid.to_s.empty?
    raise FormatError, "kid contains unsupported characters" unless KID_PATTERN.match?(kid.to_s)
  end

  def validate_hash_hex!(value, name)
    raise FormatError, "#{name} must be 64 hex characters" unless HEX_64_PATTERN.match?(value.to_s)
  end

  def validate_private_key!(key)
    validate_ec_key!(key)
    raise FormatError, "private key is required" unless key.private?
  end

  def validate_public_key!(key)
    validate_ec_key!(key)
  end

  def public_key_for_verification(key)
    return create_public_key_from_point(key) if key.is_a?(OpenSSL::PKey::EC::Point)

    validate_public_key!(key)
    key
  end

  def validate_ec_key!(key)
    raise FormatError, "key must be an OpenSSL::PKey::EC" unless key.is_a?(OpenSSL::PKey::EC)
    raise FormatError, "key must use P-384" unless key.group.curve_name == ES384_CURVE
  end

  def create_public_key_from_point(point)
    raise FormatError, "key must use P-384" unless point.group.curve_name == ES384_CURVE

    sequence = OpenSSL::ASN1::Sequence(
      [
        OpenSSL::ASN1::Sequence(
          [
            OpenSSL::ASN1::ObjectId("id-ecPublicKey"),
            OpenSSL::ASN1::ObjectId(point.group.curve_name),
          ],
        ),
        OpenSSL::ASN1::BitString(point.to_octet_string(:uncompressed)),
      ],
    )
    OpenSSL::PKey::EC.new(sequence.to_der)
  end

  def decode_signature(signature)
    raise FormatError, "signature is required" if signature.nil? || signature.to_s.empty?
    raise FormatError, "signature must be base64url without padding" if signature.to_s.include?("=")
    raise FormatError, "signature must be base64url" unless BASE64URL_PATTERN.match?(signature.to_s)

    raw = Base64.urlsafe_decode64(pad_base64(signature.to_s))
    unless raw.bytesize == ES384_RAW_SIGNATURE_BYTES
      raise FormatError, "signature must be #{ES384_RAW_SIGNATURE_BYTES} bytes"
    end

    raw
  rescue ArgumentError => e
    raise FormatError, "signature must be valid base64url: #{e.message}"
  end

  def block_hash_bytes(block_hash)
    validate_hash_hex!(block_hash, "block_hash")
    [block_hash].pack("H*")
  end

  def asn1_to_raw_signature(der_signature)
    values = OpenSSL::ASN1.decode(der_signature).value
    raise FormatError, "ECDSA signature must have two components" unless values.size == 2

    values.map { |value| value.value.to_s(2).rjust(ES384_COMPONENT_BYTES, "\x00") }.join
  end

  def raw_to_asn1_signature(raw_signature)
    unless raw_signature.bytesize == ES384_RAW_SIGNATURE_BYTES
      raise FormatError, "signature must be #{ES384_RAW_SIGNATURE_BYTES} bytes"
    end

    r = raw_signature.byteslice(0, ES384_COMPONENT_BYTES)
    s = raw_signature.byteslice(ES384_COMPONENT_BYTES, ES384_COMPONENT_BYTES)
    OpenSSL::ASN1::Sequence.new(
      [r, s].map { |integer| OpenSSL::ASN1::Integer.new(OpenSSL::BN.new(integer, 2)) },
    ).to_der
  end

  def pad_base64(value)
    value + ("=" * ((4 - (value.length % 4)) % 4))
  end

  def secure_compare(left, right)
    return false unless left.bytesize == right.bytesize

    ActiveSupport::SecurityUtils.secure_compare(left, right)
  end

  private_class_method :block_hash_for, :sign_block_hash, :validate_seal!, :validate_kid!, :validate_hash_hex!,
                       :validate_private_key!, :validate_ec_key!, :block_hash_bytes, :asn1_to_raw_signature
end
