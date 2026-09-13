# typed: false
# frozen_string_literal: true

# Environment-driven JWT configuration shared by every auth surface.
#
# Previously lived as a nested module inside `AuthenticationBase`.
# Extracted so the 3,000-line AuthenticationBase concern shrinks toward a single
# responsibility, while existing callers that reference
# `AuthenticationJwtConfiguration` keep working via the
# backward-compatibility alias defined in `AuthenticationBase`.
module AuthenticationJwtConfiguration
  VALID_RESOURCE_TYPES = %w(client operator visitor).freeze

  def self.leeway_seconds
    SecurityJwtRfc9068AccessTokenProfile::CLOCK_SKEW_LEEWAY_SECONDS
  end

  # `iss` names the authorization server, not the token subtype, so every
  # resource type shares one issuer per environment.
  def self.issuer
    ENV.fetch("AUTH_JWT_ISSUER")
  end

  def self.client_id(resource_type)
    normalized_resource_type = normalize_resource_type(resource_type)
    raise ArgumentError, "unsupported auth resource type: #{resource_type.inspect}" if normalized_resource_type.nil?

    ENV.fetch("AUTH_JWT_#{normalized_resource_type.upcase}_CLIENT_ID")
  end

  # Audience is a resource-type boundary: a visitor token must not validate where
  # an operator token is expected. Falling back to a single shared literal when
  # the environment is unset silently collapses that boundary for every resource
  # type at once, so the missing configuration is named instead. `issuer` above
  # already fails this way.
  def self.audiences(resource_type = nil)
    normalized_resource_type = normalize_resource_type(resource_type)
    if normalized_resource_type.nil?
      raise ArgumentError, "unsupported auth resource type: #{resource_type.inspect}"
    end

    env_key = "AUTH_JWT_#{normalized_resource_type.upcase}_AUDIENCES"
    audiences = parse_audiences(ENV.fetch(env_key), env_key:)
    SecurityJwtRfc9068AccessTokenProfile.assert_production_identifiers!(audiences, label: env_key)
    assert_distinct_audiences!(normalized_resource_type, audiences)
    audiences
  end

  # Boot-time check so a production process with an incomplete or
  # non-production auth token configuration refuses to start instead of
  # failing on the first request that mints or verifies a token.
  def self.validate!
    SecurityJwtRfc9068AccessTokenProfile.assert_production_identifiers!([issuer], label: "AUTH_JWT_ISSUER")
    VALID_RESOURCE_TYPES.each do |resource_type|
      audiences(resource_type)
      client_id(resource_type)
    end
    true
  end

  def self.private_key
    JitSecurityJwtKeyring.private_key_for_active
  end

  def self.public_key
    JitSecurityJwtKeyring.public_key_for_active
  end

  public_class_method :leeway_seconds, :issuer, :client_id, :audiences, :validate!, :private_key, :public_key

  def self.parse_audiences(raw, env_key:)
    values = raw.split(",").map(&:strip)
    values.reject!(&:empty?)
    values.uniq!
    raise KeyError, "#{env_key} is set but contains no audience" if values.empty?

    values
  end
  private_class_method :parse_audiences

  def self.assert_distinct_audiences!(resource_type, audiences)
    VALID_RESOURCE_TYPES.excluding(resource_type).each do |other_type|
      other_key = "AUTH_JWT_#{other_type.upcase}_AUDIENCES"
      other = parse_audiences(ENV.fetch(other_key), env_key: other_key)
      overlap = audiences & other
      next if overlap.empty?

      raise ArgumentError, "JWT audiences overlap between #{resource_type} and #{other_type}: #{overlap.join(", ")}"
    end
  end
  private_class_method :assert_distinct_audiences!

  def self.normalize_resource_type(resource_type)
    return nil if resource_type.blank?

    normalized = resource_type.to_s
    return normalized if VALID_RESOURCE_TYPES.include?(normalized)

    nil
  end
  private_class_method :normalize_resource_type
end
