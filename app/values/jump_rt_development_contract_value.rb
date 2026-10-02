# typed: false
# frozen_string_literal: true

require "uri"
require "jit_security_jwt_jwks"

class JumpRtDevelopmentContractValue < Data.define(:issuer_origin, :jwks_uri, :return_origin, :production_keys)
  Error = Class.new(StandardError)

  def self.from_source(namespace:, source:, production_origins:)
    prefix = "JUMP_DEVELOPMENT_#{namespace}"
    issuer_origin = source.fetch("#{prefix}_ISSUER_ORIGIN")
    jwks_uri = source.fetch("#{prefix}_JWKS_URI")
    return_origin = source.fetch("#{prefix}_RETURN_ORIGIN")
    production_keyset = source.fetch("#{prefix}_PRODUCTION_PUBLIC_KEYSET")
    {
      "#{prefix}_ISSUER_ORIGIN" => issuer_origin, "#{prefix}_JWKS_URI" => jwks_uri,
      "#{prefix}_RETURN_ORIGIN" => return_origin, "#{prefix}_PRODUCTION_PUBLIC_KEYSET" => production_keyset,
      "PUBLIC_JUMP_GATEWAY_URL" => source.fetch("PUBLIC_JUMP_GATEWAY_URL"),
      "JWT_DEVELOPMENT_#{namespace}_ACTIVE_KID" => source.value("JWT_DEVELOPMENT_#{namespace}_ACTIVE_KID"),
      "JWT_DEVELOPMENT_#{namespace}_PRIVATE_KEY" => source.value("JWT_DEVELOPMENT_#{namespace}_PRIVATE_KEY"),
      "JWT_DEVELOPMENT_#{namespace}_PUBLIC_KEYSET" => source.value("JWT_DEVELOPMENT_#{namespace}_PUBLIC_KEYSET"),
    }.each do |name, value|
      raise Error, "#{name} is required for public development Jump issuance" if value.blank?
    end
    unless source.fetch("PUBLIC_JUMP_GATEWAY_URL") == "https://jump.umaxica.net"
      raise Error, "development Jump requires PUBLIC_JUMP_GATEWAY_URL=https://jump.umaxica.net"
    end

    uri = URI.parse(issuer_origin)
    host = uri.hostname.to_s.downcase.delete_suffix(".")
    unless uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil? && uri.path.empty? &&
        uri.query.nil? && uri.fragment.nil? && uri.port == 443 && issuer_origin == "https://#{host}" &&
        host.end_with?(".#{namespace.split('_').last.downcase}") &&
        !host.end_with?(".localhost", ".local", ".internal") &&
        !production_origins.include?(issuer_origin) &&
        !host.match?(/\A(?:www\.jp|jpx|palm\.jp|log|edit)\.umaxica\./)
      raise Error, "#{prefix}_ISSUER_ORIGIN must be a distinct public HTTPS origin in its surface TLD"
    end
    unless jwks_uri == "#{issuer_origin}/.well-known/jwks.json"
      raise Error, "#{prefix}_JWKS_URI must be issuer/.well-known/jwks.json"
    end
    unless return_origin == issuer_origin
      raise Error, "#{prefix}_RETURN_ORIGIN must be the public issuer origin"
    end
    production_keys = JitSecurityJwtJwks.parse_public_collection(production_keyset)
    raise Error, "#{prefix}_PRODUCTION_PUBLIC_KEYSET must contain production public keys" if production_keys.empty?
    if JitSecurityJwtJwks.parse_public_collection(source.value("JWT_DEVELOPMENT_#{namespace}_PUBLIC_KEYSET")).empty?
      raise Error, "JWT_DEVELOPMENT_#{namespace}_PUBLIC_KEYSET must contain public keys"
    end
    new(issuer_origin: issuer_origin.freeze, jwks_uri: jwks_uri.freeze, return_origin: return_origin.freeze,
        production_keys: production_keys.values.map { |jwk| jwk.transform_values(&:freeze).freeze }.freeze)
  rescue URI::InvalidURIError, JitSecurityJwtJwks::Error => e
    raise Error, "#{namespace} development Jump contract is invalid: #{e.class.name}"
  end
  public_class_method :from_source
end
