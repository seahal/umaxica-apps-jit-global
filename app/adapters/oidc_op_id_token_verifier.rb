# typed: false
# frozen_string_literal: true

require "jwt"

class OidcOpIdTokenVerifier
  Result =
    Data.define(:success, :payload, :error) do
      def success? = success
    end

  ALGORITHM = "ES384"
  TOKEN_TYPE = "id-token+jwt"
  REQUIRED_CLAIMS = %w(iss aud exp nbf iat sub nonce jti sid typ act).freeze
  RESOURCE_TYPE_BY_REALM = { "app" => "client", "com" => "visitor", "org" => "operator" }.freeze
  CLOCK_SKEW_LEEWAY_SECONDS = 30

  def initialize(id_token:, client_id:, realm:, issuer:, expected_nonce:, jwks_client:,
                 expected_max_age: nil, expected_resource_type: nil)
    @id_token = id_token
    @client_id = require_string(client_id, "client_id")
    @realm = require_realm(realm)
    @issuer = require_string(issuer, "issuer")
    @expected_nonce = require_string(expected_nonce, "expected_nonce")
    @jwks_client = jwks_client
    @expected_max_age = normalize_max_age(expected_max_age)
    @expected_resource_type = expected_resource_type || RESOURCE_TYPE_BY_REALM.fetch(@realm)
    validate_resource_type!
    validate_cell_binding!
  end

  public

  def call
    return failure("missing_id_token") if id_token.blank?

    unverified_payload, header = JWT.decode(id_token, nil, false)
    return failure("invalid_header") unless valid_header?(header)
    # D-144: no refetch for a token that names another issuer.
    return failure("invalid_id_token") unless unverified_payload.is_a?(Hash) && unverified_payload["iss"] == issuer

    lookup = jwks_client.lookup(header.fetch("kid"))
    return failure("key_unavailable") if lookup.unavailable?
    return failure("invalid_id_token") unless lookup.found?

    public_key = lookup.key

    payload, = JWT.decode(id_token, public_key, true, decode_options)
    return failure("invalid_id_token") unless valid_claims?(payload)

    Result.new(success: true, payload: payload, error: nil)
  rescue JWT::DecodeError, JWT::VerificationError, OpenSSL::PKey::PKeyError, ArgumentError, TypeError
    failure("invalid_id_token")
  end

  private

  attr_reader :id_token, :client_id, :realm, :issuer, :expected_nonce, :jwks_client, :expected_max_age,
              :expected_resource_type

  def require_string(value, name)
    return value if value.is_a?(String) && value.present?

    raise ArgumentError, "#{name} must be a nonblank string"
  end

  def require_realm(value)
    normalized = value.to_s
    return normalized if RESOURCE_TYPE_BY_REALM.key?(normalized)

    raise ArgumentError, "unsupported RP realm"
  end

  def validate_resource_type!
    return if RESOURCE_TYPE_BY_REALM.fetch(realm) == expected_resource_type

    raise ArgumentError, "resource type is not registered for the RP realm"
  end

  def validate_cell_binding!
    cell = RpCellBinding.for_client(client_id)
    return if cell.realm == realm

    raise ArgumentError, "client_id is not registered for the RP realm"
  end

  def normalize_max_age(value)
    return if value.nil?

    normalized = value.is_a?(Integer) ? value : Integer(value, 10)
    raise ArgumentError, "expected_max_age must not be negative" if normalized.negative?

    normalized
  rescue TypeError, ArgumentError
    raise ArgumentError, "expected_max_age must be a nonnegative integer"
  end

  def valid_header?(header)
    return false unless header.is_a?(Hash)
    return false unless header["alg"] == ALGORITHM && header["typ"] == TOKEN_TYPE
    return false unless header["kid"].is_a?(String) && header["kid"].present?
    return false if (header.keys.map(&:to_s) & %w(crit jku jwk x5u x5c zip)).present?

    true
  end

  def decode_options
    {
      algorithms: [ALGORITHM],
      required_claims: REQUIRED_CLAIMS,
      leeway: CLOCK_SKEW_LEEWAY_SECONDS,
      verify_expiration: true,
      verify_not_before: true,
      verify_iat: { leeway: CLOCK_SKEW_LEEWAY_SECONDS },
      verify_iss: true,
      iss: issuer,
      verify_aud: true,
      aud: client_id,
    }
  end

  def valid_claims?(payload)
    return false unless payload.is_a?(Hash)
    return false unless REQUIRED_CLAIMS.all? { |claim| payload.key?(claim) }
    return false unless string_claims_valid?(payload)
    return false unless integer_time_claims_valid?(payload)
    return false unless payload["aud"] == [client_id]
    return false unless payload["iss"] == issuer
    return false unless payload["typ"] == TOKEN_TYPE
    return false unless payload["act"] == expected_resource_type
    return false unless secure_equal?(payload["nonce"], expected_nonce)
    return false unless authentication_time_valid?(payload)

    true
  end

  def string_claims_valid?(payload)
    %w(iss sub nonce jti sid typ act).all? do |claim|
      payload[claim].is_a?(String) && payload[claim].present?
    end
  end

  def integer_time_claims_valid?(payload)
    %w(exp nbf iat).all? { |claim| payload[claim].is_a?(Integer) }
  end

  def authentication_time_valid?(payload)
    raw = payload["auth_time"]
    return expected_max_age.nil? if raw.nil?
    return false unless raw.is_a?(Numeric) && raw.finite?
    return false if raw > Time.current.to_f + CLOCK_SKEW_LEEWAY_SECONDS
    return true if expected_max_age.nil?

    raw >= Time.current.to_f - expected_max_age - CLOCK_SKEW_LEEWAY_SECONDS
  end

  def secure_equal?(actual, expected)
    actual = actual.to_s
    expected = expected.to_s
    return false unless actual.bytesize == expected.bytesize

    ActiveSupport::SecurityUtils.secure_compare(actual, expected)
  end

  def failure(error)
    Result.new(success: false, payload: nil, error: error)
  end
end
