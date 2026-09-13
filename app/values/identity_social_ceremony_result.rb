# typed: false
# frozen_string_literal: true

class IdentitySocialCeremonyResult
  TOKEN_TYPE = "social-ceremony-result+jwt"
  PURPOSE = "social_ceremony_result"
  PROOF_METHOD = "provider_subject"

  REQUIRED_CLAIMS = %w(
    typ iss aud purpose surface actor_ref session_ref transaction_id grant_jti result_jti operation provider
    proof_method provider_subject_ref provider_subject_digest verified_at challenge_id expires_at iat exp
  ).freeze
  OPTIONAL_CLAIMS = %w(email_digest email_verified auth_time candidate_ref candidate_digest birthdate).freeze
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
    # Untrusted decode is used ONLY to read `surface` so the correct verified
    # issuer/audience can be selected; the verified decode below is what trust
    # decisions rely on.
    unverified = IdentitySocialCeremonyContract.decode_untrusted_routing_payload(token)
    surface = unverified["surface"].to_s
    payload, header = IdentitySocialCeremonyContract.decode_verified_payload(
      token: token,
      issuer_id: issuer_id,
      issuer: IdentitySocialCeremonyContract.sign_issuer(surface),
      audience: IdentitySocialCeremonyContract.acme_audience(surface),
      expected_type: TOKEN_TYPE,
      required: REQUIRED_CLAIMS,
    )
    new(payload, kid: header["kid"], now: now)
  end

  def [](key) = payload[key.to_s]

  def validate!(now: Time.current)
    IdentitySocialCeremonyContract.validate_common_payload!(
      payload,
      required: REQUIRED_CLAIMS,
      allowed: ALLOWED_CLAIMS,
      purpose: PURPOSE,
      audience: IdentitySocialCeremonyContract.acme_audience(payload["surface"]),
      issuer: IdentitySocialCeremonyContract.sign_issuer(payload["surface"]),
      now: now,
    )
    IdentitySocialCeremonyContract.validate_exact!(payload, "proof_method", PROOF_METHOD)
    IdentitySocialCeremonyContract.validate_timestamp!(payload, "verified_at")
    raise IdentitySocialCeremonyContract::Error,
          "verified_at must not be in the future" if payload["verified_at"].to_i > now.to_i + IdentitySocialCeremonyContract::LEEWAY
  end

  def self.default_claims(attributes, now:)
    surface = attributes.fetch(:surface, attributes["surface"]).to_s
    {
      "typ" => TOKEN_TYPE,
      "iss" => IdentitySocialCeremonyContract.sign_issuer(surface),
      "aud" => IdentitySocialCeremonyContract.acme_audience(surface),
      "purpose" => PURPOSE,
      "proof_method" => PROOF_METHOD,
      "iat" => now.to_i,
      "exp" => IdentityCeremonyNumericDate.value(attributes.fetch(:expires_at) { attributes.fetch("expires_at") }),
    }
  end
end
