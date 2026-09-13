# typed: false
# frozen_string_literal: true

require "jwt"
require "jit_security_jwt_issuer_builder"
require "jit_security_jwt_key_source"
require "jit_security_jwt_jwk"

module JitSecurityJwtRegistry
  module_function

  ALGORITHM = JitSecurityJwtJwk::ALGORITHM
  CURVE = JitSecurityJwtJwk::CURVE
  REQUIRED_JWK_FIELDS = JitSecurityJwtJwk::REQUIRED_PUBLIC_FIELDS
  PRIVATE_JWK_FIELDS = JitSecurityJwtJwk::PRIVATE_FIELDS
  SURFACE_NAMESPACES = %w(
    SIGN_APP SIGN_COM SIGN_ORG
    ACME_APP ACME_COM ACME_ORG
    CORE_APP CORE_COM CORE_ORG
    BASE_APP BASE_COM BASE_ORG
  ).freeze
  OIDC_CLIENT_NAMESPACES = %w(
    SIGN_APP SIGN_COM SIGN_ORG
    ACME_APP ACME_COM ACME_ORG
    CORE_APP CORE_COM CORE_ORG
    BASE_APP BASE_COM BASE_ORG
  ).freeze
  SURFACE_ISSUER_ORIGINS = {
    "SIGN_APP" => "https://log.umaxica.app",
    "SIGN_COM" => "https://log.umaxica.com",
    "SIGN_ORG" => "https://log.umaxica.org",
    "ACME_APP" => "https://www.umaxica.app",
    "ACME_COM" => "https://www.umaxica.com",
    "ACME_ORG" => "https://www.umaxica.org",
    "CORE_APP" => "https://jpx.umaxica.app",
    "CORE_COM" => "https://jpx.umaxica.com",
    "CORE_ORG" => "https://jpx.umaxica.org",
    "BASE_APP" => "https://www.umaxica.app",
    "BASE_COM" => "https://www.umaxica.com",
    "BASE_ORG" => "https://www.umaxica.org",
  }.freeze

  ConfigurationError = Class.new(StandardError)

  DEFAULT_KID = "default"
  AUTH_AUDIENCE_ENV_NAMES = %w(
    AUTH_JWT_CLIENT_AUDIENCES AUTH_JWT_VISITOR_AUDIENCES AUTH_JWT_OPERATOR_AUDIENCES
  ).freeze
  # Development convenience only; every non-local environment must configure
  # the jump gateway explicitly.
  LOCAL_JUMP_GATEWAY_AUDIENCE = "https://jump.umaxica.net"

  # kid substrings that mark non-production / throwaway signing material. Such a
  # kid must never appear outside local Rails environments: it means dev/test/
  # fixture keys (often ephemeral, auto-generated under tmp/ by the local keyset
  # installer) are being published as if they were deployable keys.
  RESERVED_ENV_KID_PATTERN =
    /\b(?:development|test|local|fixture|sample|example|dummy|staging)\b/i

  def configure!
    records = build_issuers
    validate!(records)
    # rubocop:disable ThreadSafety/ClassInstanceVariable
    @issuers = records
    # rubocop:enable ThreadSafety/ClassInstanceVariable
  rescue ConfigurationError => e
    Rails.logger.fatal(
      "jwt.registry.configuration_invalid error_class=#{e.class.name} reason=#{e.message.inspect}",
    )
    raise
  end

  def reload!
    configure!
  end

  def issuer(id)
    issuers.fetch(id.to_s)
  rescue KeyError
    raise ConfigurationError, "unknown JWT issuer registry id: #{id.inspect}"
  end

  def surface(namespace)
    issuer("surface:#{normalize_namespace(namespace)}")
  end

  def oidc_client(namespace)
    issuer("oidc_client:#{normalize_oidc_client_namespace(namespace)}")
  end

  def auth = issuer("auth")

  def preference = issuer("preference")

  def issuers
    # rubocop:disable ThreadSafety/ClassInstanceVariable
    @issuers ||= configure!
    # rubocop:enable ThreadSafety/ClassInstanceVariable
  end

  def private_key_for(id, kid = nil)
    record = issuer(id)
    key = record.keys.fetch((kid || record.current_kid).to_s, nil)
    key&.private_key
  end

  def public_key_for(id, kid)
    issuer(id).public_key_for(kid)
  end

  def jwks_for(id)
    issuer(id).jwks
  end

  def parse_header(token)
    _payload, header = JWT.decode(token, nil, false)
    header || {}
  rescue JWT::DecodeError
    {}
  end

  def normalize_namespace(namespace)
    value = namespace.to_s.upcase
    raise ConfigurationError,
          "unsupported JWT issuer namespace: #{namespace.inspect}" unless SURFACE_NAMESPACES.include?(value)

    value
  end

  def build_issuers
    source = JitSecurityJwtKeySource.new
    records = {}
    auth_audiences = AUTH_AUDIENCE_ENV_NAMES.flat_map { |name| source.csv(name) }
    auth_audiences.uniq!
    records["auth"] = build_keyset_issuer(
      source: source,
      id: "auth",
      private_keyset_name: :AUTH_JWT_PRIVATE_KEYSET,
      public_keyset_name: :AUTH_JWT_PUBLIC_KEYSET,
      active_kid: source.fetch("AUTH_JWT_ACTIVE_KID", nil),
      issuer: source.fetch("AUTH_JWT_ISSUER", nil),
      audiences: auth_audiences.freeze,
      revoked_kids: source.csv("AUTH_JWT_REVOKED_KIDS"),
    )
    records["preference"] = build_keyset_issuer(
      source: source,
      id: "preference",
      private_keyset_name: :PREFERENCE_JWT_PRIVATE_KEYSET,
      public_keyset_name: :PREFERENCE_JWT_PUBLIC_KEYSET,
      active_kid: source.fetch("PREFERENCE_JWT_ACTIVE_KID", nil),
      issuer: source.fetch("PREFERENCE_JWT_ISSUER", nil),
      audiences: preference_hosts_from_boot_config,
      revoked_kids: source.csv("PREFERENCE_JWT_REVOKED_KIDS"),
    )

    SURFACE_NAMESPACES.each do |namespace|
      records["surface:#{namespace}"] = build_surface_issuer(namespace, source: source)
    end
    OIDC_CLIENT_NAMESPACES.each do |namespace|
      records["oidc_client:#{namespace}"] = build_oidc_client_issuer(namespace, source: source)
    end

    records.freeze
  end

  def build_keyset_issuer(source:, id:, private_keyset_name:, public_keyset_name:, active_kid:, issuer:,
                          audiences:, revoked_kids:)
    JitSecurityJwtIssuerBuilder.build_keyset_issuer(
      id: id,
      private_keyset: source.value(private_keyset_name),
      private_keyset_source: private_keyset_name,
      public_keyset: source.value(public_keyset_name),
      public_keyset_source: public_keyset_name,
      active_kid: active_kid,
      issuer: issuer,
      audiences: audiences,
      revoked_kids: revoked_kids,
    )
  rescue JitSecurityJwtIssuerBuilder::Error => e
    raise ConfigurationError, e.message
  end

  def build_surface_issuer(namespace, source:)
    JitSecurityJwtIssuerBuilder.build_surface_issuer(
      namespace: namespace,
      active_kid: source.value("JWT_#{namespace}_ACTIVE_KID"),
      private_key: source.value("JWT_#{namespace}_PRIVATE_KEY"),
      private_key_source: "JWT_#{namespace}_PRIVATE_KEY",
      public_keyset: source.value("JWT_#{namespace}_PUBLIC_KEYSET"),
      public_keyset_source: "JWT_#{namespace}_PUBLIC_KEYSET",
      revoked_kids: source.csv("JWT_#{namespace}_REVOKED_KIDS"),
      issuer: surface_issuer_origin(namespace),
      audiences: [jump_gateway_audience(source)].freeze,
    )
  rescue JitSecurityJwtIssuerBuilder::Error => e
    raise ConfigurationError, e.message
  end

  def build_oidc_client_issuer(namespace, source:)
    JitSecurityJwtIssuerBuilder.build_surface_issuer_record(
      namespace: namespace,
      id: "oidc_client:#{namespace}",
      active_kid: source.value("OIDC_CLIENT_#{namespace}_ACTIVE_KID"),
      private_key: source.value("OIDC_CLIENT_#{namespace}_PRIVATE_KEY"),
      private_key_source: "OIDC_CLIENT_#{namespace}_PRIVATE_KEY",
      public_keyset: source.fetch("OIDC_CLIENT_#{namespace}_PUBLIC_KEYSET", nil),
      public_keyset_source: "OIDC_CLIENT_#{namespace}_PUBLIC_KEYSET",
      revoked_kids: source.csv("OIDC_CLIENT_#{namespace}_REVOKED_KIDS"),
      issuer: "oidc_client:#{namespace.downcase}",
      audiences: ["oidc-token-endpoint"].freeze,
    )
  rescue JitSecurityJwtIssuerBuilder::Error => e
    raise ConfigurationError, e.message
  end

  def jump_gateway_audience(source)
    configured = source.fetch("PUBLIC_JUMP_GATEWAY_URL", nil).presence || source.fetch("JUMP_GATEWAY_URL", nil).presence
    return configured if configured
    return LOCAL_JUMP_GATEWAY_AUDIENCE if Rails.env.local?

    raise ConfigurationError, "PUBLIC_JUMP_GATEWAY_URL is required outside local environments"
  end

  # An empty list is left for `validate_record_metadata!` to reject, so a
  # preference keyring without configured surface hosts fails at boot instead
  # of signing tokens for a guessed audience.
  def preference_hosts_from_boot_config
    boot_config =
      begin
        Rails.configuration.x.boot_config
      rescue NoMethodError
        nil
      end
    hosts = boot_config&.fetch(:hosts, nil)
    return [] unless hosts

    values =
      %i(base_service base_corporate base_staff).filter_map do |key|
        host = hosts.public_send(key)
        host&.to_s
      end
    values.freeze
  end

  def validate!(records = issuers)
    records.each_value { |record| validate_record!(record) }
    validate_global_kid_uniqueness!(records)
    true
  end

  def validate_record!(record)
    return if record.current_kid.blank? && record.keys.empty?

    validate_record_metadata!(record)
    validate_active_key!(record)
    validate_record_keys!(record)
  end

  def validate_record_metadata!(record)
    raise ConfigurationError, "#{record.id} issuer is missing" if record.issuer.blank?
    raise ConfigurationError, "#{record.id} audiences are missing" if record.audiences.blank?
    raise ConfigurationError, "#{record.id} active kid is missing" if record.current_kid.blank?
    if enforce_public_key_hygiene? && reserved_env_kid?(record.current_kid)
      raise ConfigurationError, "#{record.id} active kid must not contain reserved environment markers"
    end
    return unless insecure_default_kid?(record.current_kid)

    raise ConfigurationError, "#{record.id} active kid must not be #{DEFAULT_KID.inspect}"

  end

  def validate_active_key!(record)
    unless record.keys.key?(record.current_kid)
      raise ConfigurationError, "#{record.id} active key #{record.current_kid.inspect} is missing"
    end
    if record.revoked_kids.include?(record.current_kid)
      raise ConfigurationError, "#{record.id} active key #{record.current_kid.inspect} is revoked"
    end

    current = record.keys.fetch(record.current_kid)
    raise ConfigurationError, "#{record.id} active private key is missing" if current.private_key.nil?
    return if record.jwks.fetch(:keys).any? { |jwk| jwk.fetch("kid") == record.current_kid }

    raise ConfigurationError, "#{record.id} active key #{record.current_kid.inspect} is missing from JWKS"

  end

  def validate_record_keys!(record)
    record.keys.each_value do |key|
      if enforce_public_key_hygiene? && reserved_env_kid?(key.kid)
        raise ConfigurationError, "#{record.id}:#{key.kid} must not contain reserved environment markers"
      end

      validate_public_jwk!(key.public_jwk, source: "#{record.id}:#{key.kid}")
      raise ConfigurationError, "#{record.id}:#{key.kid} has invalid key state #{key.state.inspect}" unless %w(
        active grace retired revoked
      ).include?(key.state)
    end
  end

  def validate_global_kid_uniqueness!(records = issuers)
    seen = {}
    records.each_value do |record|
      record.keys.each_key do |kid|
        previous = seen[kid]
        next if previous && previous != record.id && insecure_default_kid_allowed?(kid)
        if previous && previous != record.id
          raise ConfigurationError,
                "duplicate JWT kid #{kid.inspect} in #{previous} and #{record.id}"
        end

        seen[kid] = record.id
      end
    end
  end

  def validate_public_jwk!(jwk, source:)
    JitSecurityJwtJwk.validate_public!(jwk)
  rescue JitSecurityJwtJwk::Error => e
    raise ConfigurationError, "#{source} #{e.message}"
  end

  def export_public_jwk(key, kid:)
    JitSecurityJwtJwk.export_public(key, kid: kid)
  end

  def surface_issuer_origin(namespace)
    SURFACE_ISSUER_ORIGINS.fetch(namespace)
  end

  def normalize_oidc_client_namespace(namespace)
    value = namespace.to_s.upcase
    unless OIDC_CLIENT_NAMESPACES.include?(value)
      raise ConfigurationError,
            "unsupported OIDC client JWT namespace: #{namespace.inspect}"
    end

    value
  end

  def insecure_default_kid?(kid)
    kid.to_s == DEFAULT_KID && !insecure_default_kid_allowed?(kid)
  end

  def insecure_default_kid_allowed?(kid)
    kid.to_s == DEFAULT_KID && Rails.env.local? && ENV["JWT_ALLOW_INSECURE_DEFAULT_KID"] == "1"
  end

  # True when dev/test/fixture signing material must be rejected. Local
  # development and test are allowed to mint local keys; every non-local Rails
  # environment must provide deployable key identifiers.
  def enforce_public_key_hygiene?
    !Rails.env.local?
  end

  def reserved_env_kid?(kid)
    RESERVED_ENV_KID_PATTERN.match?(kid.to_s)
  end
end
