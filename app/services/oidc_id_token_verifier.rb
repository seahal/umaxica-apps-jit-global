# typed: false
# frozen_string_literal: true

class OidcIdTokenVerifier < ApplicationService
  Result =
    Data.define(:success, :payload, :canonical_audience, :error) do
      def success? = success
    end

  def initialize(id_token:, client_id:, resource_type:, expected_nonce:, expected_max_age: nil,
                 jwt_issuer_id: nil, issuer: nil)
    super()
    @id_token = id_token
    @client_id = client_id
    @resource_type = resource_type
    @expected_nonce = expected_nonce
    @expected_max_age = expected_max_age
    @jwt_issuer_id = jwt_issuer_id
    @issuer = issuer
  end

  def call
    return failure("missing_id_token") if id_token.blank?
    return failure("missing_nonce") if expected_nonce.blank?

    payload = decode!
    canonical_audience = validate_audience!(payload)
    return failure("nonce_mismatch") unless secure_equal?(payload["nonce"], expected_nonce)

    authentication_time = validate_authentication_time!(payload)
    validate_max_age!(authentication_time)

    Result.new(success: true, payload: payload, canonical_audience: canonical_audience, error: nil)
  rescue JWT::DecodeError, JWT::VerificationError, OpenSSL::PKey::PKeyError, ArgumentError, TypeError
    failure("invalid_id_token")
  end

  private

  attr_reader :id_token, :client_id, :resource_type, :expected_nonce, :expected_max_age, :jwt_issuer_id, :issuer

  def decode!
    SecurityJwtOidcIdTokenCodec.decode(
      id_token: id_token,
      client_id: client_id,
      resource_type: resource_type,
      jwt_issuer_id: resolved_jwt_issuer_id,
      issuer: issuer,
    )
  end

  def secure_equal?(actual, expected)
    actual = actual.to_s
    expected = expected.to_s
    return false if actual.bytesize != expected.bytesize

    ActiveSupport::SecurityUtils.secure_compare(actual, expected)
  end

  def failure(error)
    Result.new(success: false, payload: nil, canonical_audience: nil, error: error)
  end

  def resolved_jwt_issuer_id
    jwt_issuer_id.presence || OidcIssuer.jwt_issuer_id_for_resource_type(resource_type)
  end

  def validate_audience!(payload)
    aud = payload.fetch("aud")
    raise ArgumentError, "invalid audience type" unless aud.is_a?(Array)
    raise ArgumentError, "invalid audience size" unless aud.size == 1

    canonical_audience = aud.first.to_s
    raise ArgumentError, "invalid audience value" unless secure_equal?(canonical_audience, client_id)

    canonical_audience
  end

  def validate_authentication_time!(payload)
    raw = payload["auth_time"]
    return if raw.blank?

    authentication_time = raw.is_a?(Numeric) ? raw.to_f : Float(raw)
    raise ArgumentError, "invalid auth_time" unless authentication_time.finite?
    raise ArgumentError, "auth_time is in the future" if authentication_time >
      Time.current.to_f + AuthenticationJwtConfiguration.leeway_seconds

    authentication_time
  end

  def validate_max_age!(authentication_time)
    max_age = OidcAuthorizeRequestResolver.normalize_max_age(expected_max_age)
    return if max_age.nil?
    raise ArgumentError, "auth_time is required for max_age" if authentication_time.blank?

    leeway = AuthenticationJwtConfiguration.leeway_seconds
    raise ArgumentError, "auth_time is too old" if authentication_time < Time.current.to_f - max_age - leeway
  end
end
