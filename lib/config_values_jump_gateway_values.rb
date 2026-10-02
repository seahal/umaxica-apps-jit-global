# frozen_string_literal: true

module ConfigValues
  # PUBLIC_JUMP_GATEWAY_URL is the only Jump gateway setting: the browser-facing Jump origin. The
  # gateway JWKS URI and the Jump RT audience are derived from its normalized origin so they cannot
  # drift from it. Rails has no private network path to Jump, so no PRIVATE_* counterpart exists
  # (adr/jump-directed-rails-handoff-contract.md).
  JumpGatewayValues =
    Data.define(:origin, :ttl_seconds, :revoked_kids) do
      def jwks_uri = "#{origin}#{ConfigValues::JumpGatewayValues::JWKS_PATH}"

      def audience = origin
    end
end

ConfigValuesJumpGatewayValues = ConfigValues::JumpGatewayValues

class << ConfigValues::JumpGatewayValues
  MAX_TTL_SECONDS = 30
  GATEWAY_URL_ENV = "PUBLIC_JUMP_GATEWAY_URL"
  REMOVED_ENV = %w(
    JUMP_GATEWAY_URL PUBLIC_JUMP_GATEWAY_JWKS_URL JUMP_GATEWAY_JWKS_URL
    PUBLIC_JUMP_GATEWAY_AUDIENCE JUMP_GATEWAY_AUDIENCE
  ).freeze

  def build(env:)
    REMOVED_ENV.each do |name|
      next unless env.key?(name)

      raise ArgumentError, "#{name} was removed; configure only #{GATEWAY_URL_ENV} (JWKS and audience are derived)"
    end
    raise ArgumentError, "#{GATEWAY_URL_ENV} is required" unless env.key?(GATEWAY_URL_ENV)

    origin =
      begin
        ConfigValues.public_https_origin(env.fetch(GATEWAY_URL_ENV))
      rescue ArgumentError => e
        raise ArgumentError, "#{GATEWAY_URL_ENV} must be a public HTTPS root origin: #{e.message}"
      end
    ttl_seconds = Integer(env.fetch("JUMP_RT_TTL_SECONDS", MAX_TTL_SECONDS.to_s), 10)
    unless ttl_seconds.between?(1, MAX_TTL_SECONDS)
      raise ArgumentError, "JUMP_RT_TTL_SECONDS must be between 1 and #{MAX_TTL_SECONDS}"
    end

    revoked_kids =
      env.fetch("JUMP_RETURN_REVOKED_KIDS", "").to_s.split(",").each_with_object([]) do |kid, memo|
        stripped = kid.strip
        memo << stripped unless stripped.empty?
      end.freeze
    ConfigValues::JumpGatewayValues.new(origin.freeze, ttl_seconds, revoked_kids).freeze
  end
end

ConfigValues::JumpGatewayValues::JWKS_PATH = "/.well-known/jwks.json"
