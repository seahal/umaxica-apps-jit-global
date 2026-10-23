# typed: false
# frozen_string_literal: true

require "jwt"

# The RP's OIDC `state`: an ES384 JWS signed with the RP's own `oidc_client:<namespace>` key
# (D-149, D-150, D-151; `adr/rp-oidc-state-and-return-target.md`). It carries the path-only
# `target_link_uri` and the `jti` that keys this browser's single pending entry. Signed, not
# encrypted. Never carries `sid`, `code_verifier` or session secrets.
module OidcStateJwt
  module_function

  TOKEN_TYPE = "umaxica-oidc-state+jwt"
  AUDIENCE_SUFFIX = "#oidc-state"
  TTL = 30.minutes
  VERSION = 1
  CLOCK_SKEW_LEEWAY_SECONDS = 30
  REQUIRED_CLAIMS = %w(iss aud jti iat exp v).freeze

  Verification =
    Data.define(:valid, :jti, :target_link_uri, :reason) do
      def valid? = valid
    end

  def issue(client_id:, target_link_uri:, now: Time.current, jti: SecureRandom.uuid)
    payload = {
      "iss" => client_id.to_s,
      "aud" => audience_for(client_id),
      "jti" => jti,
      "iat" => now.to_i,
      "exp" => (now + TTL).to_i,
      "v" => VERSION,
    }
    payload["target_link_uri"] = target_link_uri if target_link_uri.present?
    [JitSecurityJwtKeyring.encode(payload, typ: TOKEN_TYPE, issuer_id: issuer_id_for(client_id)), jti]
  end

  def verify(client_id:, token:)
    _payload, header = JWT.decode(token.to_s, nil, false)
    return refused("invalid_header") unless header.is_a?(Hash) && header["alg"] == "ES384" &&
      header["typ"] == TOKEN_TYPE && header["kid"].is_a?(String)

    key = JitSecurityJwtRegistry.public_key_for(issuer_id_for(client_id), header["kid"])
    return refused("unknown_key") unless key

    payload, = JWT.decode(
      token.to_s, key, true,
      algorithms: ["ES384"], required_claims: REQUIRED_CLAIMS,
      verify_iss: true, iss: client_id.to_s, verify_aud: true, aud: audience_for(client_id),
      verify_expiration: true, verify_iat: { leeway: CLOCK_SKEW_LEEWAY_SECONDS }, leeway: 0,
    )
    return refused("unsupported_version") unless payload["v"] == VERSION

    Verification.new(valid: true, jti: payload["jti"].to_s, target_link_uri: payload["target_link_uri"], reason: nil)
  rescue JWT::DecodeError, JitSecurityJwtRegistry::ConfigurationError, ArgumentError, TypeError
    refused("invalid_token")
  end

  def audience_for(client_id) = "#{client_id}#{AUDIENCE_SUFFIX}"

  def issuer_id_for(client_id)
    namespace = OidcClientRegistry.jwt_namespace_for(client_id)
    raise JitSecurityJwtRegistry::ConfigurationError, "no OIDC client key namespace" if namespace.blank?

    "oidc_client:#{namespace}"
  end

  def refused(reason) = Verification.new(valid: false, jti: nil, target_link_uri: nil, reason:)
  private_class_method :audience_for, :issuer_id_for, :refused
end
