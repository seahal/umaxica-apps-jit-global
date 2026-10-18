# typed: false
# frozen_string_literal: true

class IdentityStepUpCeremonyResult
  TOKEN_TYPE = "step-up-ceremony-result+jwt"
  PURPOSE = "step_up_ceremony_result"

  REQUIRED_CLAIMS = %w(
    typ iss aud purpose surface actor_ref session_ref transaction_id grant_jti result_jti scope aal method
    verified_at challenge_id expires_at phishing_resistant user_verified credential_ref full_reauthentication iat exp
  ).freeze
  OPTIONAL_CLAIMS = %w(attempt_count resource_ref tenant_ref).freeze
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
    unverified = IdentityStepUpCeremonyContract.decode_unverified_payload(token)
    surface = unverified["surface"].to_s
    payload, header = IdentityStepUpCeremonyContract.decode_verified_payload(
      token: token,
      issuer_id: issuer_id,
      issuer: IdentityStepUpCeremonyContract.sign_issuer(surface),
      audience: IdentityStepUpCeremonyContract.acme_audience(surface),
      expected_type: TOKEN_TYPE,
      required: REQUIRED_CLAIMS,
    )
    new(payload, kid: header["kid"], now: now)
  end

  def [](key) = payload[key.to_s]

  def achieved_aal
    # @deprecated This is a signed legacy label only and never authorizes a ceremony.
    value = self[:aal].to_s
    (value == StepUpRequirement::NO_AAL) ? nil : value.to_sym
  end

  def phishing_resistant? = self[:phishing_resistant] == true

  def validate!(now: Time.current)
    IdentityStepUpCeremonyContract.validate_common_payload!(
      payload,
      required: REQUIRED_CLAIMS,
      allowed: ALLOWED_CLAIMS,
      purpose: PURPOSE,
      audience: IdentityStepUpCeremonyContract.acme_audience(payload["surface"]),
      issuer: IdentityStepUpCeremonyContract.sign_issuer(payload["surface"]),
      now: now,
    )
    IdentityStepUpCeremonyContract.validate_inclusion!(payload, "method", IdentityStepUpCeremonyContract::METHODS)
    %w(user_verified full_reauthentication).each do |key|
      IdentityStepUpCeremonyContract.validate_boolean!(payload, key)
    end
    IdentityStepUpCeremonyContract.validate_boolean!(payload, "phishing_resistant")
    return if payload["credential_ref"].is_a?(String) && payload["credential_ref"].present?

    raise IdentityStepUpCeremonyContract::Error, "credential_ref is invalid"

  end

  def self.default_claims(attributes, now:)
    surface = attributes.fetch(:surface, attributes["surface"]).to_s
    {
      "typ" => TOKEN_TYPE,
      "iss" => IdentityStepUpCeremonyContract.sign_issuer(surface),
      "aud" => IdentityStepUpCeremonyContract.acme_audience(surface),
      "purpose" => PURPOSE,
      "iat" => now.to_i,
      "exp" => IdentityCeremonyNumericDate.value(attributes.fetch(:expires_at) { attributes.fetch("expires_at") }),
    }
  end
end
