# frozen_string_literal: true

module ConfigValues
  JumpGatewayValues = Data.define(:origin, :jwks_uri, :audience, :ttl_seconds, :revoked_kids)
end

ConfigValuesJumpGatewayValues = ConfigValues::JumpGatewayValues

class << ConfigValues::JumpGatewayValues
  MAX_TTL_SECONDS = 30
  JWKS_PATH = "/.well-known/jwks.json"

  def build(env:, production:)
    public_origin = env.fetch("PUBLIC_JUMP_GATEWAY_URL", nil)
    legacy_origin = env.fetch("JUMP_GATEWAY_URL", nil)
    raw_origin =
      if production
        public_origin || legacy_origin || raise(KeyError, 'key not found: "PUBLIC_JUMP_GATEWAY_URL"')
      else
        public_origin || legacy_origin || "https://jump.umaxica.net"
      end

    origin = ConfigValues.build(raw_origin, allow_localhost: !production)
    derived_jwks_uri = "#{origin}#{JWKS_PATH}"
    raw_jwks = env.fetch("PUBLIC_JUMP_GATEWAY_JWKS_URL", nil) || env.fetch("JUMP_GATEWAY_JWKS_URL", nil)
    jwks_uri = derived_jwks_uri
    if raw_jwks.present?
      if production && raw_jwks != derived_jwks_uri
        raise ArgumentError, "JUMP_GATEWAY_JWKS_URL must equal #{derived_jwks_uri}"
      end

      jwks_uri = raw_jwks
    end
    ttl_seconds = Integer(env.fetch("JUMP_RT_TTL_SECONDS", MAX_TTL_SECONDS.to_s), 10)
    unless ttl_seconds.between?(1, MAX_TTL_SECONDS)
      raise ArgumentError, "JUMP_RT_TTL_SECONDS must be between 1 and #{MAX_TTL_SECONDS}"
    end

    audience = env.fetch("PUBLIC_JUMP_GATEWAY_AUDIENCE", nil) || env.fetch("JUMP_GATEWAY_AUDIENCE", nil) || origin.to_s
    revoked_kids =
      env.fetch("JUMP_RETURN_REVOKED_KIDS", "").to_s.split(",").each_with_object([]) do |kid, memo|
        stripped = kid.strip
        memo << stripped unless stripped.empty?
      end.freeze
    ConfigValues::JumpGatewayValues.new(origin, jwks_uri, audience, ttl_seconds, revoked_kids).freeze
  end
end
