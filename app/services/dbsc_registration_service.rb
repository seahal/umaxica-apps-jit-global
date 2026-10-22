# typed: false
# frozen_string_literal: true

# Completes DBSC registration from a decoded JWT string and stores the binding
# key. The HTTP boundary owns Structured Field parsing.
class DbscRegistrationService < ApplicationService
  def initialize(record:, proof:, now: Time.current, session_id: nil, expected_audience: nil)
    super
    @record = record
    @proof = proof
    @now = now
    @session_id = session_id.presence || record&.dbsc_session_id.presence || SecureRandom.urlsafe_base64(24)
    @expected_audience = expected_audience
  end

  def call
    return failure("record_missing") if record.blank?

    validation = validate_proof
    return failure(validation.error_code, message: validation.message) unless validation.ok

    header = validation.header
    jwk = DbscRecordAdapter.normalize_public_key(header["jwk"])
    return failure("missing_public_key") if jwk.blank?

    # The JWK arrives in the client's proof header, so the key-type contract is
    # enforced here rather than trusting whatever the client offers.
    verify_key = DbscRecordAdapter.verification_key_from_jwk(jwk, source: "registration JWK")
    signature = proof_validator.verify_signature(verify_key, header["alg"])
    return failure("invalid_proof", message: signature.message) unless signature.ok

    record.with_lock do
      record.update!(
        DbscRecordAdapter.binding_method_attribute(record) => DbscRecordAdapter.binding_method_class(record)::DBSC,
        DbscRecordAdapter.dbsc_status_attribute(record) => DbscRecordAdapter.dbsc_status_class(record)::ACTIVE,
        :dbsc_session_id => session_id,
        :dbsc_public_key => jwk,
        :dbsc_challenge => nil,
        :dbsc_challenge_issued_at => nil,
      )
    end

    { ok: true, session_id: session_id, record: record }
  rescue DbscRecordAdapter::PublicKeyError => e
    failure("invalid_public_key", message: e.message)
  rescue JWT::JWKError, JSON::ParserError, ArgumentError => e
    failure("invalid_proof", message: e.message)
  end

  private

  attr_reader :record, :proof, :now, :session_id, :expected_audience

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
