# typed: false
# frozen_string_literal: true

require "jwt"

module IdentityTelephoneCeremonyContract
  module_function

  ALGORITHM = "ES384"
  SURFACES = %w(app com org).freeze
  OPERATIONS = %w(registration replacement).freeze
  LEEWAY = 30

  SIGN_ISSUERS = {
    "app" => "https://log.umaxica.app",
    "com" => "https://log.umaxica.com",
    "org" => "https://log.umaxica.org",
  }.freeze

  ACME_ISSUERS = {
    "app" => "https://www.umaxica.app",
    "com" => "https://www.umaxica.com",
    "org" => "https://www.umaxica.org",
  }.freeze

  SIGN_AUDIENCES = {
    "app" => "https://log.umaxica.app/telephone-ceremony",
    "com" => "https://log.umaxica.com/telephone-ceremony",
    "org" => "https://log.umaxica.org/telephone-ceremony",
  }.freeze

  ACME_AUDIENCES = {
    "app" => "https://www.umaxica.app/telephone-ceremony-result",
    "com" => "https://www.umaxica.com/telephone-ceremony-result",
    "org" => "https://www.umaxica.org/telephone-ceremony-result",
  }.freeze

  FORBIDDEN_KEYS = %w(
    auth_token
    authorization
    delegated_authorization
    downstream_token
    final_verified_status
    otp
    otp_counter
    otp_digest
    otp_private_key
    raw_number
    recent_auth
    refresh_token
    session_token
    step_up_freshness
    sudo
    telephone_number
    token
    verifier_digest
    verifier_secret
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
    raise IdentityTelephoneCeremony::Error, "surface is invalid"
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
    raise IdentityTelephoneCeremony::Error, "forbidden claims: #{forbidden.sort.join(", ")}" if forbidden.present?

    unknown = keys - allowed
    raise IdentityTelephoneCeremony::Error, "unknown claims: #{unknown.sort.join(", ")}" if unknown.present?
  end

  def validate_required!(payload, required)
    missing = required.reject { |key| payload[key].present? }
    raise IdentityTelephoneCeremony::Error, "missing required claims: #{missing.join(", ")}" if missing.present?
  end

  def validate_exact!(payload, key, expected)
    raise IdentityTelephoneCeremony::Error, "#{key} is invalid" unless payload[key].to_s == expected.to_s
  end

  def validate_inclusion!(payload, key, allowed)
    raise IdentityTelephoneCeremony::Error, "#{key} is invalid" unless allowed.include?(payload[key].to_s)
  end

  def validate_binding!(payload)
    raise IdentityTelephoneCeremony::Error, "actor_ref is required" if payload["actor_ref"].blank?
    raise IdentityTelephoneCeremony::Error, "session_ref is required" if payload["session_ref"].blank?
  end

  def validate_timestamp!(payload, key)
    Integer(payload[key])
  rescue ArgumentError, TypeError
    raise IdentityTelephoneCeremony::Error, "#{key} must be an integer timestamp"
  end

  def validate_future_timestamp!(payload, key, now:)
    value = Integer(payload[key])
    raise IdentityTelephoneCeremony::Error, "#{key} is expired" unless value > now.to_i
  rescue ArgumentError, TypeError
    raise IdentityTelephoneCeremony::Error, "#{key} must be an integer timestamp"
  end

  def validate_return_to!(payload)
    return if payload["return_to"].blank?

    value = payload["return_to"].to_s
    raise IdentityTelephoneCeremony::Error,
          "return_to must be relative navigation metadata" unless value.start_with?("/") && !value.start_with?("//")
  end

  def validate_header!(header, expected_type:)
    raise IdentityTelephoneCeremony::Error, "header is invalid" if header.blank?
    raise IdentityTelephoneCeremony::Error, "alg is invalid" unless header["alg"] == ALGORITHM
    raise IdentityTelephoneCeremony::Error, "typ is invalid" unless header["typ"] == expected_type
    raise IdentityTelephoneCeremony::Error, "kid is required" if header["kid"].blank?
    raise IdentityTelephoneCeremony::Error, "unsafe header is forbidden" if %w(crit jku jwk x5u).any? { |key| header.key?(key) }
  end

  def decode_unverified_payload(token)
    payload, = JWT.decode(token, nil, false)
    raise IdentityTelephoneCeremony::Error, "token payload must be a JSON object" unless payload.is_a?(Hash)

    payload
  rescue JWT::DecodeError => e
    raise IdentityTelephoneCeremony::Error, "token is invalid: #{e.message}"
  end

  def decode_verified_payload(token:, issuer_id:, issuer:, audience:, expected_type:, required:)
    header = JitSecurityJwtKeyring.parse_header(token)
    validate_header!(header, expected_type: expected_type)

    public_key = JitSecurityJwtKeyring.public_key_for(header["kid"], issuer_id: issuer_id)
    raise IdentityTelephoneCeremony::Error, "kid is unknown" if public_key.blank?

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
    raise IdentityTelephoneCeremony::Error, "token verification failed: #{e.message}"
  end
end
