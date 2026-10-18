# typed: false
# frozen_string_literal: true

require "jwt"

# Verifies an OpenID Connect Back-Channel Logout Token for one RP cell (R5-WU10, one.md 6.4).
#
# Strict, separate from the Access and ID token verifiers: ES384 from the OP public JWKS only,
# `typ` logout+jwt, exact issuer and audience (this client), iat/exp within leeway, a JTI, a `sid`,
# the back-channel logout event, and NO `nonce` (a nonce-bearing token is an ID Token replayed as a
# logout). Keys and URLs never come from the token.
class OidcOpLogoutTokenVerifier
  Result =
    Data.define(:success, :payload) do
      def success? = success
    end

  ALGORITHM = "ES384"
  TOKEN_TYPE = "logout+jwt"
  EVENT = "http://schemas.openid.net/event/backchannel-logout"
  REQUIRED_CLAIMS = %w(iss aud iat exp jti sid events).freeze
  CLOCK_SKEW_LEEWAY_SECONDS = 30
  MAX_LIFETIME_SECONDS = 300

  def initialize(logout_token:, client_id:, issuer:, jwks_client:)
    @logout_token = logout_token
    @client_id = client_id
    @issuer = issuer
    @jwks_client = jwks_client
  end

  public

  def call
    return failure if logout_token.blank?

    _payload, header = JWT.decode(logout_token, nil, false)
    return failure unless valid_header?(header)

    key = jwks_client.public_key_for(header.fetch("kid"))
    return failure unless key

    payload, = JWT.decode(
      logout_token, key, true,
      algorithms: [ALGORITHM], required_claims: REQUIRED_CLAIMS, leeway: CLOCK_SKEW_LEEWAY_SECONDS,
      verify_iat: true, verify_iss: true, iss: issuer, verify_aud: true, aud: client_id, verify_expiration: true,
    )
    valid_claims?(payload) ? Result.new(success: true, payload:) : failure
  rescue JWT::DecodeError, OpenSSL::PKey::PKeyError, ArgumentError, KeyError, TypeError
    failure
  end

  private

  attr_reader :logout_token, :client_id, :issuer, :jwks_client

  def valid_header?(header)
    header.is_a?(Hash) && header["alg"] == ALGORITHM && header["typ"] == TOKEN_TYPE &&
      header["kid"].is_a?(String) && header["kid"].present? &&
      (header.keys.map(&:to_s) & %w(crit jku jwk x5u x5c zip)).empty?
  end

  def valid_claims?(payload)
    return false if payload.key?("nonce")
    return false unless Array(payload["aud"]) == [client_id]
    return false unless payload["events"].is_a?(Hash) && payload["events"][EVENT].is_a?(Hash)
    return false unless payload["sid"].is_a?(String) && payload["sid"].present?
    return false unless payload["jti"].is_a?(String) && payload["jti"].present?

    payload["exp"].to_i - payload["iat"].to_i <= MAX_LIFETIME_SECONDS
  end

  def failure
    Result.new(success: false, payload: nil)
  end
end
