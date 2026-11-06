# typed: false
# frozen_string_literal: true

require "jwt"
require "digest"

class OidcOpIdTokenVerifier
  Result =
    Data.define(:success, :payload, :error, :detail) do
      # `detail` names the failed check for operators and never carries token or claim values. Callers
      # keep branching on `error` alone, so it cannot become an oracle in a response.
      def initialize(success:, payload:, error:, detail: nil) = super

      def success? = success
    end

  ALGORITHM = "ES384"
  TOKEN_TYPE = "id-token+jwt"
  REQUIRED_CLAIMS = %w(iss aud exp nbf iat sub nonce jti sid typ act).freeze
  RESOURCE_TYPE_BY_REALM = { "app" => "client", "org" => "operator" }.freeze
  CLOCK_SKEW_LEEWAY_SECONDS = 30

  def initialize(id_token:, client_id:, realm:, issuer:, expected_nonce: nil, expected_nonce_digest: nil, jwks_client:,
                 expected_max_age: nil, expected_resource_type: nil)
    @id_token = id_token
    @client_id = require_string(client_id, "client_id")
    @realm = require_realm(realm)
    @issuer = require_string(issuer, "issuer")
    nonce_expectation_count = [expected_nonce, expected_nonce_digest].count { |value| !value.nil? }
    raise ArgumentError, "provide exactly one nonce expectation" unless nonce_expectation_count == 1

    @expected_nonce = require_string(expected_nonce, "expected_nonce") unless expected_nonce.nil?
    @expected_nonce_digest = require_digest(expected_nonce_digest) unless expected_nonce_digest.nil?
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
    return failure("invalid_header", detail: "header") unless valid_header?(header)
    # D-144: no refetch for a token that names another issuer.
    unless unverified_payload.is_a?(Hash) && unverified_payload["iss"] == issuer
      return failure("invalid_id_token", detail: "issuer")
    end

    lookup = jwks_client.lookup(header.fetch("kid"))
    return failure("key_unavailable", detail: "jwks_unavailable") if lookup.unavailable?
    return failure("invalid_id_token", detail: "kid_not_found") unless lookup.found?

    public_key = lookup.key

    payload, = JWT.decode(id_token, public_key, true, decode_options)
    claim_failure = failed_claim_check(payload)
    return failure("invalid_id_token", detail: claim_failure) if claim_failure

    Result.new(success: true, payload: payload, error: nil)
  rescue JWT::DecodeError, JWT::VerificationError, OpenSSL::PKey::PKeyError, ArgumentError, TypeError => e
    failure("invalid_id_token", detail: e.class.name)
  end

  private

  attr_reader :id_token, :client_id, :realm, :issuer, :expected_nonce, :expected_nonce_digest,
              :jwks_client, :expected_max_age, :expected_resource_type

  def require_digest(value)
    return value if value.is_a?(String) && value.match?(/\A[0-9a-f]{64}\z/)

    raise ArgumentError, "expected_nonce_digest must be a lowercase SHA-256 digest"
  end

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

  def failed_claim_check(payload)
    return "payload_shape" unless payload.is_a?(Hash)
    return "required_claims" unless REQUIRED_CLAIMS.all? { |claim| payload.key?(claim) }
    return "string_claims" unless string_claims_valid?(payload)
    return "time_claims" unless integer_time_claims_valid?(payload)
    return "aud" unless payload["aud"] == [client_id]
    return "iss" unless payload["iss"] == issuer
    return "typ" unless payload["typ"] == TOKEN_TYPE
    return "act" unless payload["act"] == expected_resource_type
    return "nonce" unless nonce_valid?(payload["nonce"])
    return "auth_time" unless authentication_time_valid?(payload)

    nil
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

  def nonce_valid?(value)
    return false unless value.is_a?(String) && value.present?

    expected = expected_nonce_digest || expected_nonce
    actual = expected_nonce_digest ? Digest::SHA256.hexdigest(value) : value
    secure_equal?(actual, expected)
  end

  def failure(error, detail: nil)
    Result.new(success: false, payload: nil, error: error, detail: detail)
  end
end
