# typed: false
# frozen_string_literal: true

class IdentityEmailCeremonyGrant
  TOKEN_TYPE = "email-ceremony-grant+jwt"
  PURPOSE = "email_ceremony"

  REQUIRED_CLAIMS = %w(
    typ iss aud purpose surface actor_ref session_ref transaction_id jti operation iat exp
  ).freeze
  OPTIONAL_CLAIMS = %w(
    email_candidate_ref email_candidate_digest normalized_email_digest required_step_up_scope return_to
  ).freeze
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
    unverified = IdentityEmailCeremonyContract.decode_unverified_payload(token)
    surface = unverified["surface"].to_s
    payload, header = IdentityEmailCeremonyContract.decode_verified_payload(
      token: token,
      issuer_id: issuer_id,
      issuer: IdentityEmailCeremonyContract.acme_issuer(surface),
      audience: IdentityEmailCeremonyContract.sign_audience(surface),
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
      audience: IdentityEmailCeremonyContract.sign_audience(payload["surface"]),
      issuer: IdentityEmailCeremonyContract.acme_issuer(payload["surface"]),
      now: now,
    )
    IdentityEmailCeremonyContract.validate_return_to!(payload)
  end

  def self.default_claims(attributes, now:)
    surface = attributes.fetch(:surface, attributes["surface"]).to_s
    {
      "typ" => TOKEN_TYPE,
      "iss" => IdentityEmailCeremonyContract.acme_issuer(surface),
      "aud" => IdentityEmailCeremonyContract.sign_audience(surface),
      "purpose" => PURPOSE,
      "iat" => now.to_i,
    }
  end
end
