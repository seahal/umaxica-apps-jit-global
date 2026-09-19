# typed: false
# frozen_string_literal: true

class IdentityStepUpCeremonyGrant
  TOKEN_TYPE = "step-up-ceremony-grant+jwt"
  PURPOSE = "step_up_ceremony"

  REQUIRED_CLAIMS = %w(
    typ iss aud purpose surface actor_ref session_ref transaction_id jti required_scope required_aal iat exp
  ).freeze
  OPTIONAL_CLAIMS = %w(allowed_methods resource_ref return_to phishing_resistant_required).freeze
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
    unverified = IdentityStepUpCeremonyContract.decode_unverified_payload(token)
    surface = unverified["surface"].to_s
    payload, header = IdentityStepUpCeremonyContract.decode_verified_payload(
      token: token,
      issuer_id: issuer_id,
      issuer: IdentityStepUpCeremonyContract.acme_issuer(surface),
      audience: IdentityStepUpCeremonyContract.sign_audience(surface),
      expected_type: TOKEN_TYPE,
      required: REQUIRED_CLAIMS,
    )
    new(payload, kid: header["kid"], now: now)
  end

  def [](key) = payload[key.to_s]

  def required_aal
    value = self[:required_aal].to_s
    (value == StepUpRequirement::NO_AAL) ? nil : value.to_sym
  end

  def phishing_resistant_required? = self[:phishing_resistant_required] == true

  def validate!(now: Time.current)
    IdentityStepUpCeremonyContract.validate_common_payload!(
      payload,
      required: REQUIRED_CLAIMS,
      allowed: ALLOWED_CLAIMS,
      purpose: PURPOSE,
      audience: IdentityStepUpCeremonyContract.sign_audience(payload["surface"]),
      issuer: IdentityStepUpCeremonyContract.acme_issuer(payload["surface"]),
      now: now,
    )
    IdentityStepUpCeremonyContract.validate_boolean!(
      payload,
      "phishing_resistant_required",
    ) if payload.key?("phishing_resistant_required")
    validate_allowed_methods!
  end

  def self.default_claims(attributes, now:)
    surface = attributes.fetch(:surface, attributes["surface"]).to_s
    {
      "typ" => TOKEN_TYPE,
      "iss" => IdentityStepUpCeremonyContract.acme_issuer(surface),
      "aud" => IdentityStepUpCeremonyContract.sign_audience(surface),
      "purpose" => PURPOSE,
      "iat" => now.to_i,
    }
  end

  private

  def validate_allowed_methods!
    return if payload["allowed_methods"].blank?

    methods = Array(payload["allowed_methods"]).map(&:to_s)
    invalid = methods - IdentityStepUpCeremonyContract::METHODS
    raise IdentityStepUpCeremonyContract::Error,
          "allowed_methods contains invalid methods: #{invalid.join(", ")}" if invalid.present?
  end
end
