# typed: false
# frozen_string_literal: true

# Verifies a decoded session identifier and JWT string against the stored public
# key. The HTTP boundary owns Structured Field parsing.
class DbscVerificationService < ApplicationService
  def initialize(record:, session_id:, proof:, now: Time.current, expected_audience: nil)
    super
    @record = record
    @session_id = session_id
    @proof = proof
    @now = now
    @expected_audience = expected_audience
  end

  def call
    return failure("record_missing") if record.blank?
    return failure("missing_session_id") if session_id.blank?
    return failure("missing_proof") if proof.blank?

    registered_session_id = record.dbsc_session_id
    return failure("registration_incomplete") if registered_session_id.to_s.blank?
    return failure("session_id_mismatch") unless registered_session_id == session_id
    return failure("missing_public_key") if record.dbsc_public_key.blank?

    validation = validate_proof
    return failure(validation.error_code, message: validation.message) unless validation.ok

    header = validation.header
    return failure("unexpected_public_key") if header["jwk"].present?

    signature = proof_validator.verify_signature(DbscRecordAdapter.dbsc_public_key(record), header["alg"])
    return failure("invalid_proof", message: signature.message) unless signature.ok

    { ok: true, record: record }
  rescue DbscRecordAdapter::PublicKeyError => e
    # The stored key is unusable: server-side state, not a client-supplied
    # proof. Reported separately so operations does not read data corruption as
    # a hijack attempt (this path revokes the session and forces a sign-out).
    failure("invalid_public_key", message: e.message)
  rescue JWT::JWKError, JSON::ParserError, ArgumentError => e
    failure("invalid_proof", message: e.message)
  end

  private

  attr_reader :record, :session_id, :proof, :now, :expected_audience

  def validate_proof
    proof_validator.call
  end

  def proof_validator
    @proof_validator ||= DbscProofVerifier.new(
      proof: proof,
      challenge: record.dbsc_challenge,
      challenge_issued_at: record.dbsc_challenge_issued_at,
      now: now,
      expected_audience: expected_audience,
    )
  end

  def failure(error_code, message: nil)
    { ok: false, error_code: error_code, message: message }
  end
end
