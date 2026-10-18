# typed: false
# frozen_string_literal: true

require "jwt"

class OidcOpAccessTokenVerifier
  Result =
    Data.define(:success, :payload, :error) do
      def success? = success
    end

  ALGORITHM = "ES384"
  TOKEN_TYPE = "at+jwt"
  REQUIRED_CLAIMS = %w(
    iss aud exp nbf iat sub sid client_id jti scope umx_contract_epoch authn_ctx
  ).freeze
  FORBIDDEN_CLAIMS = %w(scp typ act).freeze
  RESOURCE_TYPE_BY_REALM = { "app" => "client", "com" => "visitor", "org" => "operator" }.freeze
  CLOCK_SKEW_LEEWAY_SECONDS = 30

  def initialize(access_token:, client_id:, realm:, issuer:, audience:, contract_epoch:, jwks_client:,
                 expected_authentication_context: nil)
    @access_token = access_token
    @client_id = require_string(client_id, "client_id")
    @realm = require_realm(realm)
    @issuer = require_string(issuer, "issuer")
    @audience = require_string(audience, "audience")
    @contract_epoch = ContractEpochValue.coerce(contract_epoch)
    @jwks_client = jwks_client
    @expected_authentication_context = expected_authentication_context
    validate_cell_binding!
  end

  public

  def call
    return failure("missing_token") if access_token.blank?

    _unverified_payload, header = JWT.decode(access_token, nil, false)
    return failure("invalid_header") unless valid_header?(header)

    public_key = jwks_client.public_key_for(header.fetch("kid"))
    return failure("invalid_token") unless public_key

    payload, = JWT.decode(access_token, public_key, true, decode_options)
    return failure("invalid_token") unless valid_claims?(payload)

    Result.new(success: true, payload: payload, error: nil)
  rescue JWT::DecodeError, JWT::VerificationError, OpenSSL::PKey::PKeyError, ArgumentError, TypeError
    failure("invalid_token")
  end

  private

  attr_reader :access_token, :client_id, :realm, :issuer, :audience, :contract_epoch, :jwks_client,
              :expected_authentication_context

  def require_string(value, name)
    return value if value.is_a?(String) && value.present?

    raise ArgumentError, "#{name} must be a nonblank string"
  end

  def require_realm(value)
    normalized = value.to_s
    return normalized if RESOURCE_TYPE_BY_REALM.key?(normalized)

    raise ArgumentError, "unsupported RP realm"
  end

  def validate_cell_binding!
    cell = RpCellBinding.for_client(client_id)
    return if cell.realm == realm

    raise ArgumentError, "client_id is not registered for the RP realm"
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
      verify_exp: true,
      verify_nbf: true,
      verify_iat: true,
      verify_iss: true,
      iss: issuer,
      verify_aud: true,
      aud: audience,
    }
  end

  def valid_claims?(payload)
    return false unless payload.is_a?(Hash)
    return false unless REQUIRED_CLAIMS.all? { |claim| payload.key?(claim) }
    return false if FORBIDDEN_CLAIMS.any? { |claim| payload.key?(claim) }
    return false unless string_claims_valid?(payload)
    return false unless integer_time_claims_valid?(payload)
    return false unless payload["aud"] == [audience]
    return false unless payload["iss"] == issuer && payload["client_id"] == client_id
    return false unless payload["umx_contract_epoch"].is_a?(Integer) && payload["umx_contract_epoch"] == contract_epoch
    return false unless AuthenticationContextValue::KEYS.include?(payload[AuthenticationContextValue::CLAIM])
    return false if expected_authentication_context &&
      payload[AuthenticationContextValue::CLAIM] != expected_authentication_context
    return false unless resource_scope_matches?(payload)

    true
  end

  def string_claims_valid?(payload)
    %w(iss sub sid client_id jti scope authn_ctx).all? do |claim|
      payload[claim].is_a?(String) && payload[claim].present?
    end
  end

  def integer_time_claims_valid?(payload)
    %w(exp nbf iat).all? { |claim| payload[claim].is_a?(Integer) }
  end

  # The realm is already fixed by the exact same-realm issuer and the client's cell binding.
  # OP-exchanged tokens carry the authorized OIDC scopes only, so a `domain:<type>` scope is
  # optional; when one is present it must name this realm's actor type.
  def resource_scope_matches?(payload)
    scoped_type = SecurityJwtRfc9068AccessTokenProfile.resource_type_from_scope(payload)
    has_domain_scope =
      SecurityJwtRfc9068AccessTokenProfile.parse_scopes(payload).any? do |scope|
        scope.start_with?(SecurityJwtRfc9068AccessTokenProfile::RESOURCE_TYPE_SCOPE_PREFIX)
      end
    return true unless has_domain_scope

    scoped_type == RESOURCE_TYPE_BY_REALM.fetch(realm)
  end

  def failure(error)
    Result.new(success: false, payload: nil, error: error)
  end
end
