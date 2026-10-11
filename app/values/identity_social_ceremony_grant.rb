# typed: false
# frozen_string_literal: true

class IdentitySocialCeremonyGrant
  TOKEN_TYPE = "social-ceremony-grant+jwt"
  PURPOSE = "social_ceremony"

  REQUIRED_CLAIMS = %w(
    typ iss aud purpose surface actor_ref session_ref transaction_id jti operation provider iat exp
  ).freeze
  OPTIONAL_CLAIMS = %w(provider_subject_ref provider_subject_digest return_to).freeze
  ALLOWED_CLAIMS = (REQUIRED_CLAIMS + OPTIONAL_CLAIMS).freeze

  attr_reader :payload, :kid

  def initialize(payload, kid: nil, now: Time.current)
    @payload = payload.stringify_keys
    @kid = kid
    validate!(now: now)
  end

  def self.issue(attributes, issuer_id:, now: Time.current)
    grant = new(attributes.merge(default_claims(attributes, now: now)), now: now)
    JitSecurityJwtKeyring.encode(grant.payload, typ: TOKEN_TYPE, issuer_id: issuer_id)
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
      issuer: IdentitySocialCeremonyContract.acme_issuer(surface),
      audience: IdentitySocialCeremonyContract.sign_audience(surface),
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
      audience: IdentitySocialCeremonyContract.sign_audience(payload["surface"]),
      issuer: IdentitySocialCeremonyContract.acme_issuer(payload["surface"]),
      now: now,
    )
  end

  def self.default_claims(attributes, now:)
    surface = attributes.fetch(:surface, attributes["surface"]).to_s
    {
      "typ" => TOKEN_TYPE,
      "iss" => IdentitySocialCeremonyContract.acme_issuer(surface),
      "aud" => IdentitySocialCeremonyContract.sign_audience(surface),
      "purpose" => PURPOSE,
      "iat" => now.to_i,
    }
  end
end
