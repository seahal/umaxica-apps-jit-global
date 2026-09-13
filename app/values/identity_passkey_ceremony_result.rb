# typed: false
# frozen_string_literal: true

class IdentityPasskeyCeremonyResult
  TOKEN_TYPE = "passkey-ceremony-result+jwt"
  PURPOSE = "passkey_ceremony_result"
  PROOF_METHOD = "webauthn_attestation"

  REQUIRED_CLAIMS = %w(
    typ iss aud purpose surface actor_ref session_ref transaction_id grant_jti result_jti operation proof_method
    verified_at challenge_id expires_at iat exp webauthn_id public_key sign_count
  ).freeze
  OPTIONAL_CLAIMS = %w(
    credential_candidate_ref credential_candidate_digest description transports authenticator_metadata
  ).freeze
  ALLOWED_CLAIMS = (REQUIRED_CLAIMS + OPTIONAL_CLAIMS).freeze

  attr_reader :payload, :kid

  def initialize(payload, kid: nil, now: Time.current)
    @payload = payload.stringify_keys
    validate!(now: now)
    @kid = kid
  end

  def self.issue(attributes, issuer_id:, now: Time.current)
    result = new(attributes.merge(default_claims(attributes, now: now)), now: now)
    JitSecurityJwtKeyring.encode(result.payload, typ: TOKEN_TYPE, issuer_id: issuer_id)
  end

  def self.decode(token, issuer_id:, now: Time.current)
    unverified = IdentityPasskeyCeremonyContract.decode_unverified_payload(token)
    surface = unverified["surface"].to_s
    payload, header = IdentityPasskeyCeremonyContract.decode_verified_payload(
      token: token,
      issuer_id: issuer_id,
      issuer: IdentityPasskeyCeremonyContract.sign_issuer(surface),
      audience: IdentityPasskeyCeremonyContract.acme_audience(surface),
      expected_type: TOKEN_TYPE,
      required: REQUIRED_CLAIMS,
    )
    new(payload, kid: header["kid"], now: now)
  end

  def [](key) = payload[key.to_s]

  def validate!(now: Time.current)
    IdentityPasskeyCeremonyContract.validate_common_payload!(
      payload,
      required: REQUIRED_CLAIMS,
      allowed: ALLOWED_CLAIMS,
      purpose: PURPOSE,
      audience: IdentityPasskeyCeremonyContract.acme_audience(payload["surface"]),
      issuer: IdentityPasskeyCeremonyContract.sign_issuer(payload["surface"]),
      now: now,
    )
    IdentityPasskeyCeremonyContract.validate_exact!(payload, "proof_method", PROOF_METHOD)
    IdentityPasskeyCeremonyContract.validate_timestamp!(payload, "verified_at")
    Integer(payload["sign_count"])
    raise IdentityPasskeyCeremonyContract::Error,
          "verified_at must not be in the future" if payload["verified_at"].to_i > now.to_i + IdentityPasskeyCeremonyContract::LEEWAY
  rescue ArgumentError, TypeError
    raise IdentityPasskeyCeremonyContract::Error, "sign_count must be an integer"
  end

  def self.default_claims(attributes, now:)
    surface = attributes.fetch(:surface, attributes["surface"]).to_s
    {
      "typ" => TOKEN_TYPE,
      "iss" => IdentityPasskeyCeremonyContract.sign_issuer(surface),
      "aud" => IdentityPasskeyCeremonyContract.acme_audience(surface),
      "purpose" => PURPOSE,
      "proof_method" => PROOF_METHOD,
      "iat" => now.to_i,
      "exp" => IdentityCeremonyNumericDate.value(attributes.fetch(:expires_at) { attributes.fetch("expires_at") }),
    }
  end
end
