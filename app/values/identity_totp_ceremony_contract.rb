# typed: false
# frozen_string_literal: true

require "jwt"

module IdentityTotpCeremonyContract
  Error = Class.new(StandardError)
  module_function

  ALGORITHM = "ES384"
  SURFACES = %w(app).freeze
  OPERATIONS = %w(registration).freeze
  LEEWAY = 30

  SIGN_ISSUERS = { "app" => "https://log.umaxica.app" }.freeze
  ACME_ISSUERS = { "app" => "https://www.umaxica.app" }.freeze
  SIGN_AUDIENCES = { "app" => "https://log.umaxica.app/totp-ceremony" }.freeze
  ACME_AUDIENCES = { "app" => "https://www.umaxica.app/totp-ceremony-result" }.freeze

  FORBIDDEN_KEYS = %w(
    auth_token
    authorization
    delegated_authorization
    downstream_token
    first_token
    otp
    password
    password_digest
    private_key
    raw_secret
    raw_totp
    recent_auth
    refresh_token
    secret_key
    session_token
    step_up_freshness
    sudo
    token
    totp_secret
  ).freeze

  def sign_issuer(surface) = fetch_surface_value(SIGN_ISSUERS, surface)

  def acme_issuer(surface) = fetch_surface_value(ACME_ISSUERS, surface)

  def sign_audience(surface) = fetch_surface_value(SIGN_AUDIENCES, surface)

  def acme_audience(surface) = fetch_surface_value(ACME_AUDIENCES, surface)

  def sign_issuer_id(surface) = "surface:SIGN_#{surface.to_s.upcase}"

  def acme_issuer_id(surface) = "surface:BASE_#{surface.to_s.upcase}"

  def fetch_surface_value(values, surface)
    values.fetch(surface.to_s)
  rescue KeyError
    raise IdentityTotpCeremonyContract::Error, "surface is invalid"
  end

  def validate_common_payload!(payload, required:, allowed:, purpose:, audience:, issuer:, now:)
    validate_keys!(payload, allowed: allowed)
    validate_required!(payload, required)
    validate_exact!(payload, "iss", issuer)
    validate_exact!(payload, "aud", audience)
    validate_exact!(payload, "purpose", purpose)
    validate_inclusion!(payload, "surface", SURFACES)
    validate_inclusion!(payload, "operation", OPERATIONS)
    validate_timestamp!(payload, "iat")
    validate_future_timestamp!(payload, "exp", now: now) if payload.key?("exp")
    validate_future_timestamp!(payload, "expires_at", now: now) if payload.key?("expires_at")
    validate_binding!(payload)
  end

  def validate_keys!(payload, allowed:)
    keys = payload.keys.map(&:to_s)
    forbidden = keys & FORBIDDEN_KEYS
    raise IdentityTotpCeremonyContract::Error, "forbidden claims: #{forbidden.sort.join(", ")}" if forbidden.present?

    unknown = keys - allowed
    raise IdentityTotpCeremonyContract::Error, "unknown claims: #{unknown.sort.join(", ")}" if unknown.present?
  end

  def validate_required!(payload, required)
    missing = required.reject { |key| payload[key].present? }
    raise IdentityTotpCeremonyContract::Error, "missing required claims: #{missing.join(", ")}" if missing.present?
  end

  def validate_exact!(payload, key, expected)
    raise IdentityTotpCeremonyContract::Error, "#{key} is invalid" unless payload[key].to_s == expected.to_s
  end

  def validate_inclusion!(payload, key, allowed)
    raise IdentityTotpCeremonyContract::Error, "#{key} is invalid" unless allowed.include?(payload[key].to_s)
  end

  def validate_binding!(payload)
    raise IdentityTotpCeremonyContract::Error, "actor_ref is required" if payload["actor_ref"].blank?
    raise IdentityTotpCeremonyContract::Error, "session_ref is required" if payload["session_ref"].blank?
  end

  def validate_timestamp!(payload, key)
    Integer(payload[key])
  rescue ArgumentError, TypeError
    raise IdentityTotpCeremonyContract::Error, "#{key} must be an integer timestamp"
  end

  def validate_future_timestamp!(payload, key, now:)
    value = Integer(payload[key])
    raise IdentityTotpCeremonyContract::Error, "#{key} is expired" unless value > now.to_i
  rescue ArgumentError, TypeError
    raise IdentityTotpCeremonyContract::Error, "#{key} must be an integer timestamp"
  end

  def validate_header!(header, expected_type:)
    raise IdentityTotpCeremonyContract::Error, "header is invalid" if header.blank?
    raise IdentityTotpCeremonyContract::Error, "alg is invalid" unless header["alg"] == ALGORITHM
    raise IdentityTotpCeremonyContract::Error, "typ is invalid" unless header["typ"] == expected_type
    raise IdentityTotpCeremonyContract::Error, "kid is required" if header["kid"].blank?
    raise IdentityTotpCeremonyContract::Error, "unsafe header is forbidden" if %w(crit jku jwk x5u).any? { |key| header.key?(key) }
  end

  def decode_unverified_payload(token)
    payload, = JWT.decode(token, nil, false)
    raise IdentityTotpCeremonyContract::Error, "token payload must be a JSON object" unless payload.is_a?(Hash)

    payload
  rescue JWT::DecodeError => e
    raise IdentityTotpCeremonyContract::Error, "token is invalid: #{e.message}"
  end

  def decode_verified_payload(token:, issuer_id:, issuer:, audience:, expected_type:, required:)
    header = JitSecurityJwtKeyring.parse_header(token)
    validate_header!(header, expected_type: expected_type)

    public_key = JitSecurityJwtKeyring.public_key_for(header["kid"], issuer_id: issuer_id)
    raise IdentityTotpCeremonyContract::Error, "kid is unknown" if public_key.blank?

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
    raise IdentityTotpCeremonyContract::Error, "token verification failed: #{e.message}"
  end
end
