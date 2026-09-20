# typed: false
# frozen_string_literal: true

require "json"
require "jit_security_jwt_jwk"

module JitSecurityJwtJwks
  module_function

  Error = Class.new(StandardError)

  def parse_public_collection(raw)
    return {} if raw.blank?

    entries = public_entries(JSON.parse(raw))
    entries.each_with_object({}) do |entry, acc|
      jwk = JitSecurityJwtJwk.normalize_public(entry)
      acc[jwk.fetch("kid")] = jwk
    end
  rescue JSON::ParserError => e
    raise Error, "contains invalid JSON: #{e.message}"
  rescue JitSecurityJwtJwk::Error => e
    raise Error, e.message
  end

  def public_entries(parsed)
    case parsed
    when Array
      parsed
    when Hash
      keys = parsed["keys"]
      raise Error, "must be a JWK Set object with keys array" unless keys.is_a?(Array)

      keys
    else
      raise Error, "must be a JWK Set JSON object or array"
    end
  end

  private_class_method :public_entries
end
