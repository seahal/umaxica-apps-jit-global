# typed: false
# frozen_string_literal: true

require "jwt"

module IdentitySocialCeremonyContract
  Error = Class.new(StandardError)
  module_function

  ALGORITHM = "ES384"
  SURFACES = %w(app).freeze
  OPERATIONS = %w(link login signup account_selection).freeze
  PROVIDERS = %w(apple google).freeze
  LEEWAY = 30

  SIGN_ISSUERS = {
    "app" => "https://log.umaxica.app",
  }.freeze

  ACME_ISSUERS = {
    "app" => "https://www.umaxica.app",
  }.freeze

  SIGN_AUDIENCES = {
    "app" => "https://log.umaxica.app/social-ceremony",
  }.freeze

  ACME_AUDIENCES = {
    "app" => "https://www.umaxica.app/social-ceremony-result",
  }.freeze

  FORBIDDEN_KEYS = %w(
    access_token
    auth_token
    authorization
    delegated_authorization
    downstream_token
    id_token
    raw_email
    recent_auth
    refresh_token
    session_token
    step_up_freshness
    sudo
    token
  ).freeze

  def sign_issuer(surface) = fetch_surface_value(SIGN_ISSUERS, surface)

  def acme_issuer(surface) = fetch_surface_value(ACME_ISSUERS, surface)

  def sign_audience(surface) = fetch_surface_value(SIGN_AUDIENCES, surface)

  def acme_audience(surface) = fetch_surface_value(ACME_AUDIENCES, surface)

  def sign_issuer_id(surface) = "surface:SIGN_#{surface.to_s.upcase}"

  def acme_issuer_id(surface) = "surface:BASE_#{surface.to_s.upcase}"

  def provider_subject_digest(provider:, subject:)
    Digest::SHA256.hexdigest("#{SocialIdentifiable.normalize_provider(provider)}:#{subject}")
  end

  def fetch_surface_value(values, surface)
    values.fetch(surface.to_s)
  rescue KeyError
    raise IdentitySocialCeremonyContract::Error, "surface is invalid"
  end

  def validate_common_payload!(payload, required:, allowed:, purpose:, audience:, issuer:, now:)
    validate_keys!(payload, allowed: allowed)
    validate_required!(payload, required)
    validate_exact!(payload, "iss", issuer)
    validate_exact!(payload, "aud", audience)
    validate_exact!(payload, "purpose", purpose)
    validate_inclusion!(payload, "surface", SURFACES)
    validate_inclusion!(payload, "operation", OPERATIONS)
    validate_inclusion!(payload, "provider", PROVIDERS)
    validate_timestamp!(payload, "iat")
    validate_future_timestamp!(payload, "exp", now: now) if payload.key?("exp")
    validate_future_timestamp!(payload, "expires_at", now: now) if payload.key?("expires_at")
    validate_binding!(payload)
  end

  def validate_keys!(payload, allowed:)
    keys = payload.keys.map(&:to_s)
    forbidden = keys & FORBIDDEN_KEYS
    raise IdentitySocialCeremonyContract::Error, "forbidden claims: #{forbidden.sort.join(", ")}" if forbidden.present?

    unknown = keys - allowed
    raise IdentitySocialCeremonyContract::Error, "unknown claims: #{unknown.sort.join(", ")}" if unknown.present?
  end

  def validate_required!(payload, required)
    missing = required.reject { |key| payload[key].present? }
    raise IdentitySocialCeremonyContract::Error, "missing required claims: #{missing.join(", ")}" if missing.present?
  end

  def validate_exact!(payload, key, expected)
    raise IdentitySocialCeremonyContract::Error, "#{key} is invalid" unless payload[key].to_s == expected.to_s
  end

  def validate_inclusion!(payload, key, allowed)
    raise IdentitySocialCeremonyContract::Error, "#{key} is invalid" unless allowed.include?(payload[key].to_s)
  end

  def validate_binding!(payload)
    raise IdentitySocialCeremonyContract::Error, "actor_ref is required" if payload["actor_ref"].blank?
    raise IdentitySocialCeremonyContract::Error, "session_ref is required" if payload["session_ref"].blank?
  end

  def validate_timestamp!(payload, key)
    Integer(payload[key])
  rescue ArgumentError, TypeError
    raise IdentitySocialCeremonyContract::Error, "#{key} must be an integer timestamp"
  end

  def validate_future_timestamp!(payload, key, now:)
    value = Integer(payload[key])
    raise IdentitySocialCeremonyContract::Error, "#{key} is expired" unless value > now.to_i
  rescue ArgumentError, TypeError
    raise IdentitySocialCeremonyContract::Error, "#{key} must be an integer timestamp"
  end

  def validate_header!(header, expected_type:)
    raise IdentitySocialCeremonyContract::Error, "header is invalid" if header.blank?
    raise IdentitySocialCeremonyContract::Error, "alg is invalid" unless header["alg"] == ALGORITHM
    raise IdentitySocialCeremonyContract::Error, "typ is invalid" unless header["typ"] == expected_type
    raise IdentitySocialCeremonyContract::Error, "kid is required" if header["kid"].blank?
    raise IdentitySocialCeremonyContract::Error, "unsafe header is forbidden" if %w(crit jku jwk x5u).any? { |key| header.key?(key) }
  end

  # Decodes the JWT WITHOUT signature verification. The returned payload is
  # attacker-controlled and MUST NOT be trusted: use it only to extract routing
  # claims (the `surface` used to pick issuer/audience, and on the Base social
  # path the `session_ref`/`operation` used for routing and fail-safe
  # rejection). Every authentication, authorization, account-link, identity
  # creation, signup-finalization, and final-commit decision must go through the
  # verified path (`decode_verified_payload` /
  # `IdentitySocialCeremonyResult.decode`), which re-checks these fields against
  # the cryptographically verified payload. See the allowlist test in
  # test/services/identity/social_ceremony_untrusted_payload_allowlist_test.rb.
  def decode_untrusted_routing_payload(token)
    payload, = JWT.decode(token, nil, false)
    raise IdentitySocialCeremonyContract::Error, "token payload must be a JSON object" unless payload.is_a?(Hash)

    payload
  rescue JWT::DecodeError => e
    raise IdentitySocialCeremonyContract::Error, "token is invalid: #{e.message}"
  end

  def decode_verified_payload(token:, issuer_id:, issuer:, audience:, expected_type:, required:)
    header = JitSecurityJwtKeyring.parse_header(token)
    validate_header!(header, expected_type: expected_type)

    public_key = JitSecurityJwtKeyring.public_key_for(header["kid"], issuer_id: issuer_id)
    raise IdentitySocialCeremonyContract::Error, "kid is unknown" if public_key.blank?

    payload, = JWT.decode(
      token,
      public_key,
      true,
      algorithms: [ALGORITHM],
      required_claims: required,
      leeway: LEEWAY,
      verify_iat: true,
      verify_exp: true,
      verify_iss: true,
      iss: issuer,
      verify_aud: true,
      aud: audience,
    )
    [payload, header]
  rescue JWT::DecodeError, JWT::VerificationError => e
    raise IdentitySocialCeremonyContract::Error, "token verification failed: #{e.message}"
  end
end
