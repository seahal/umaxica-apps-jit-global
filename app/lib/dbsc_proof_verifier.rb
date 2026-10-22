# typed: false
# frozen_string_literal: true

# Validates a decoded DBSC JWT string before a service mutates state. HTTP
# Structured Field parsing belongs to the calling controller, exactly once.
class DbscProofVerifier
  ALLOWED_ALGORITHMS = %w(ES256 RS256).freeze
  # W3C DBSC permits RSA, but a short RSA modulus is trivially factorable and
  # would silently weaken the device binding. Reject anything below the
  # NIST-recommended 2048-bit floor. ES256 keys are fixed-size (P-256), so no
  # equivalent floor is needed there.
  RSA_MIN_KEY_BITS = 2048
  CHALLENGE_TTL = 5.minutes
  IAT_LEEWAY = 30.seconds

  # Normalized proof validation outcome.
  Result = Data.define(:ok, :payload, :header, :error_code, :message)
  # Normalized signature verification outcome.
  SignatureResult = Data.define(:ok, :message)

  def self.call(...)
    new(...).call
  end

  def initialize(proof:, challenge:, challenge_issued_at:, now: Time.current, expected_audience: nil)
    @proof = proof
    @challenge = challenge
    @challenge_issued_at = challenge_issued_at
    @now = now
    @expected_audience = expected_audience
  end

  def call
    return failure("missing_proof") if proof.blank?
    return failure("missing_challenge") if challenge.to_s.blank?
    return failure("challenge_expired") if challenge_expired?

    payload, header = JWT.decode(proof, nil, false)
    validate_claims(payload, header) || success(payload, header)
  rescue JWT::DecodeError, JWT::JWKError, JSON::ParserError, ArgumentError => e
    failure("invalid_proof", message: e.message)
  end

  def verify_signature(public_key, algorithm)
    return SignatureResult.new(ok: false, message: "rsa_key_too_short") unless rsa_key_length_ok?(
      public_key,
      algorithm,
    )

    JWT.decode(proof, public_key, true, algorithms: [algorithm])
    SignatureResult.new(ok: true, message: nil)
  rescue JWT::DecodeError, JWT::JWKError, JSON::ParserError, ArgumentError => e
    SignatureResult.new(ok: false, message: e.message)
  end

  private

  # Enforce the RSA modulus floor for RS256. Non-RSA keys (ES256) and keys
  # that do not expose a modulus pass through unchanged.
  def rsa_key_length_ok?(public_key, algorithm)
    return true unless algorithm.to_s == "RS256"
    return true unless public_key.is_a?(OpenSSL::PKey::RSA)

    public_key.n.present? && public_key.n.num_bits >= RSA_MIN_KEY_BITS
  end

  attr_reader :proof, :challenge, :challenge_issued_at, :now, :expected_audience

  def validate_claims(payload, header)
    audience = payload["aud"]

    return failure("invalid_type") unless header["typ"].to_s == "dbsc+jwt"
    return failure("invalid_algorithm") unless ALLOWED_ALGORITHMS.include?(header["alg"].to_s)
    return failure("missing_audience") if audience.to_s.blank?
    return failure("audience_mismatch") if expected_audience.present? && audience != expected_audience
    return failure("missing_issued_at") unless payload["iat"].is_a?(Numeric)

    issued_at = payload["iat"]
    return failure("issued_at_future") if issued_at > now.to_f + IAT_LEEWAY
    return failure("issued_at_expired") if issued_at < now.to_f - CHALLENGE_TTL
    return failure("challenge_mismatch") unless payload["jti"].to_s == challenge.to_s

    nil
  end

  def challenge_expired?
    challenge_issued_at.blank? || challenge_issued_at < now - CHALLENGE_TTL
  end

  def success(payload, header)
    Result.new(ok: true, payload: payload, header: header, error_code: nil, message: nil)
  end

  def failure(error_code, message: nil)
    Result.new(ok: false, payload: nil, header: nil, error_code: error_code, message: message)
  end
end
