# typed: false
# frozen_string_literal: true

require "jwt"
require "json"
require "jit_security_jwt_jwk"
require "jit_security_jwt_registry"

module JitSecurityJwtJwksService
  module_function

  REQUIRED_JWK_FIELDS = JitSecurityJwtJwk::REQUIRED_PUBLIC_FIELDS
  PRIVATE_JWK_FIELDS = JitSecurityJwtJwk::PRIVATE_FIELDS

  def jwk_set(namespace = nil)
    return JitSecurityJwtRegistry.jwks_for("auth") if namespace.blank?

    JitSecurityJwtRegistry.jwks_for("surface:#{JitSecurityJwtRegistry.normalize_namespace(namespace)}")
  end

  def normalized_public_jwk(entry)
    JitSecurityJwtJwk.normalize_public(entry)
  rescue JitSecurityJwtJwk::Error
    nil
  end
end
