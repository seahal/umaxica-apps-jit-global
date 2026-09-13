# typed: false
# frozen_string_literal: true

class IdentityEmailCeremonyResult
  TOKEN_TYPE = "email-ceremony-result+jwt"
  PURPOSE = "email_ceremony_result"
  PROOF_METHOD = "email_otp"

  REQUIRED_CLAIMS = %w(
    typ iss aud purpose surface actor_ref session_ref transaction_id grant_jti result_jti operation proof_method
    verified_at challenge_id expires_at iat exp
  ).freeze
  OPTIONAL_CLAIMS = %w(
    email_candidate_ref email_candidate_digest normalized_email_digest attempt_count
  ).freeze
  ALLOWED_CLAIMS = (REQUIRED_CLAIMS + OPTIONAL_CLAIMS).freeze

  attr_reader :payload, :kid

  def initialize(payload, kid: nil, now: Time.current)
    @payload = payload.stringify_keys
    @kid = kid
    validate!(now: now)
  end

  def self.issue(attributes, issuer_id:, now: Time.current)
    result = new(attributes.merge(default_claims(attributes, now: now)), now: now)
    JitSecurityJwtKeyring.encode(result.payload, typ: TOKEN_TYPE, issuer_id: issuer_id)
  end

  def self.decode(token, issuer_id:, now: Time.current)
    unverified = IdentityEmailCeremonyContract.decode_unverified_payload(token)
    surface = unverified["surface"].to_s
    payload, header = IdentityEmailCeremonyContract.decode_verified_payload(
      token: token,
      issuer_id: issuer_id,
      issuer: IdentityEmailCeremonyContract.sign_issuer(surface),
      audience: IdentityEmailCeremonyContract.acme_audience(surface),
      expected_type: TOKEN_TYPE,
      required: REQUIRED_CLAIMS,
    )
    new(payload, kid: header["kid"], now: now)
  end

  def [](key) = payload[key.to_s]

  def validate!(now: Time.current)
    IdentityEmailCeremonyContract.validate_common_payload!(
      payload,
      required: REQUIRED_CLAIMS,
      allowed: ALLOWED_CLAIMS,
      purpose: PURPOSE,
      audience: IdentityEmailCeremonyContract.acme_audience(payload["surface"]),
      issuer: IdentityEmailCeremonyContract.sign_issuer(payload["surface"]),
      now: now,
    )
    IdentityEmailCeremonyContract.validate_exact!(payload, "proof_method", PROOF_METHOD)
    IdentityEmailCeremonyContract.validate_timestamp!(payload, "verified_at")
    raise IdentityEmailCeremonyContract::Error,
          "verified_at must not be in the future" if payload["verified_at"].to_i > now.to_i + IdentityEmailCeremonyContract::LEEWAY
  end

  def self.default_claims(attributes, now:)
    surface = attributes.fetch(:surface, attributes["surface"]).to_s
    {
      "typ" => TOKEN_TYPE,
      "iss" => IdentityEmailCeremonyContract.sign_issuer(surface),
      "aud" => IdentityEmailCeremonyContract.acme_audience(surface),
      "purpose" => PURPOSE,
      "proof_method" => PROOF_METHOD,
      "iat" => now.to_i,
      "exp" => IdentityCeremonyNumericDate.value(attributes.fetch(:expires_at) { attributes.fetch("expires_at") }),
    }
  end
end
