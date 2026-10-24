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

  def initialize(payload, kid: nil, issuer_id: nil, now: Time.current)
    @payload = payload.stringify_keys
    @kid = kid
    @issuer_id = issuer_id || IdentitySocialCeremonyContract.acme_issuer_id(@payload["surface"])
    validate!(now: now)
  end

  def self.issue(attributes, issuer_id:, now: Time.current)
    grant = new(
      attributes.merge(default_claims(attributes, issuer_id: issuer_id, now: now)),
      issuer_id: issuer_id,
      now: now,
    )
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
      issuer: IdentitySocialCeremonyContract.issuer_for_id(surface, issuer_id),
      audience: IdentitySocialCeremonyContract.sign_audience(surface),
      expected_type: TOKEN_TYPE,
      required: REQUIRED_CLAIMS,
    )
    new(payload, kid: header["kid"], issuer_id: issuer_id, now: now)
  end

  public_class_method :issue, :decode

  public

  def [](key) = payload[key.to_s]

  def fetch(key, *, &) = payload.fetch(key.to_s, *, &)

  def expires_at = Time.zone.at(payload.fetch("exp").to_i)

  def validate!(now: Time.current)
    IdentitySocialCeremonyContract.validate_common_payload!(
      payload,
      required: REQUIRED_CLAIMS,
      allowed: ALLOWED_CLAIMS,
      purpose: PURPOSE,
      audience: IdentitySocialCeremonyContract.sign_audience(payload["surface"]),
      issuer: IdentitySocialCeremonyContract.issuer_for_id(payload["surface"], @issuer_id),
      now: now,
    )
  end

  def self.default_claims(attributes, issuer_id: nil, now:)
    surface = attributes.fetch(:surface, attributes["surface"]).to_s
    {
      "typ" => TOKEN_TYPE,
      "iss" => IdentitySocialCeremonyContract.issuer_for_id(
        surface,
        issuer_id || IdentitySocialCeremonyContract.acme_issuer_id(surface),
      ),
      "aud" => IdentitySocialCeremonyContract.sign_audience(surface),
      "purpose" => PURPOSE,
      "iat" => now.to_i,
    }
  end

  public_class_method :default_claims
end
