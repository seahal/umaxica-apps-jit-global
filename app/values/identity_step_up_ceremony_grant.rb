# typed: false
# frozen_string_literal: true

class IdentityStepUpCeremonyGrant
  TOKEN_TYPE = "step-up-ceremony-grant+jwt"
  PURPOSE = "step_up_ceremony"

  REQUIRED_CLAIMS = %w(
    typ iss aud purpose surface actor_ref session_ref transaction_id jti required_scope required_aal
    step_up_required user_verification_required full_reauthentication_required phishing_resistant_required
    audience token_binding require_session_binding allowed_methods iat exp
  ).freeze
  OPTIONAL_CLAIMS = %w(resource_ref tenant_ref return_to).freeze
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
    # @deprecated This is a wire/storage label only and never authorizes a ceremony.
    value = self[:required_aal].to_s
    (value == StepUpRequirement::NO_AAL) ? nil : value.to_sym
  end

  def step_up_required? = self[:step_up_required] == true

  def user_verification_required? = self[:user_verification_required] == true

  def full_reauthentication_required? = self[:full_reauthentication_required] == true

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
    %w(step_up_required user_verification_required full_reauthentication_required require_session_binding).each do |key|
      IdentityStepUpCeremonyContract.validate_boolean!(payload, key)
    end
    IdentityStepUpCeremonyContract.validate_boolean!(payload, "phishing_resistant_required")
    if payload["required_aal"].to_s != StepUpRequirement::NO_AAL
      raise IdentityStepUpCeremonyContract::Error, "legacy AAL requirements are unsupported"
    end

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
    methods = Array(payload["allowed_methods"]).map(&:to_s)
    raise IdentityStepUpCeremonyContract::Error, "allowed_methods is required" if methods.empty?

    invalid = methods - IdentityStepUpCeremonyContract::METHODS
    raise IdentityStepUpCeremonyContract::Error,
          "allowed_methods contains invalid methods: #{invalid.join(", ")}" if invalid.present?
  end
end
