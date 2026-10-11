# typed: false
# frozen_string_literal: true

require "base64"
require "openssl"
require "json"
require "jit_security_jwt_registry"

module JitSecurityJwtKeyring
  module_function

  def active_kid(issuer_id = "auth")
    JitSecurityJwtRegistry.issuer(issuer_id).current_kid ||
      raise(JitSecurityJwtRegistry::ConfigurationError, "#{issuer_id} active kid is not configured")
  end

  def private_key_for_active(issuer_id = "auth")
    private_key_for(active_kid(issuer_id), issuer_id: issuer_id)
  end

  def public_key_for_active(issuer_id = "auth")
    public_key_for(active_kid(issuer_id), issuer_id: issuer_id)
  end

  def private_key_for(kid, issuer_id: "auth")
    JitSecurityJwtRegistry.private_key_for(issuer_id, kid)
  end

  def public_key_for(kid, issuer_id: "auth")
    JitSecurityJwtRegistry.public_key_for(issuer_id, kid)
  end

  # The JOSE `typ` is always supplied by the caller; it is never derived from
  # payload claims, so no token family can type itself through its body.
  def encode(payload, typ:, issuer_id: "auth")
    raise ArgumentError, "JOSE typ is required" if typ.blank?

    kid = active_kid(issuer_id)
    pk = private_key_for(kid, issuer_id: issuer_id)
    raise JitSecurityJwtRegistry::ConfigurationError, "Missing private key for kid: #{kid}" if pk.nil?

    JWT.encode(payload, pk, "ES384", { kid: kid, alg: "ES384", typ: typ })
  end

  def parse_header(token)
    JitSecurityJwtRegistry.parse_header(token)
  end

  def parse_keyset(raw)
    return {} if raw.blank?

    parsed = JSON.parse(raw)
    return parsed if parsed.is_a?(Hash)

    {}
  rescue JSON::ParserError
    {}
  end

  def decode_key(base64_der)
    return nil if base64_der.blank?

    OpenSSL::PKey::EC.new(Base64.decode64(base64_der))
  rescue OpenSSL::PKey::PKeyError
    nil
  end
end
