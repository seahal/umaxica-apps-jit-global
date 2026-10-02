# typed: false
# frozen_string_literal: true

module JumpRtSurface
  module_function

  # Jump RT issuer capability is exactly these thirteen logical namespaces. It is deliberately
  # separate from JitSecurityJwtRegistry::SURFACE_NAMESPACES, which also carries non-Jump issuers.
  # Each issuer identity comes from the existing public surface setting; there is no Jump-specific
  # issuer-origin setting.
  ISSUER_ORIGIN_ENV = {
    "AUTH_APP" => "PUBLIC_AUTH_SERVICE_URL",
    "AUTH_COM" => "PUBLIC_AUTH_CORPORATE_URL",
    "AUTH_ORG" => "PUBLIC_AUTH_STAFF_URL",
    "BASE_APP" => "PUBLIC_BASE_SERVICE_URL",
    "BASE_COM" => "PUBLIC_BASE_CORPORATE_URL",
    "BASE_ORG" => "PUBLIC_BASE_STAFF_URL",
    "CORE_APP" => "PUBLIC_CORE_SERVICE_URL",
    "CORE_COM" => "PUBLIC_CORE_CORPORATE_URL",
    "CORE_ORG" => "PUBLIC_CORE_STAFF_URL",
    "WARP_APP" => "PUBLIC_WARP_SERVICE_URL",
    "WARP_COM" => "PUBLIC_WARP_CORPORATE_URL",
    "WARP_ORG" => "PUBLIC_WARP_STAFF_URL",
    "PALM_APP" => "PUBLIC_PALM_SERVICE_URL",
  }.freeze
  ISSUER_NAMESPACES = ISSUER_ORIGIN_ENV.keys.freeze

  JWKS_PATH = "/.well-known/jwks.json"

  # The issuer origin is also the Jump return origin for the namespace. Rails.env plays no part: the
  # identity is whatever PUBLIC_* origin publishes this instance's active signing key in its JWKS.
  def issuer_origin(namespace, env: ENV)
    name = ISSUER_ORIGIN_ENV.fetch(normalize_namespace(namespace))
    raise JumpRtConfigurationError, "#{name} is required for Jump issuance" unless env.key?(name)

    raw = env.fetch(name).to_s
    candidate = raw.match?(%r{\A[a-z][a-z0-9+.-]*://}i) ? raw : "https://#{raw}"
    begin
      ConfigValues.public_https_origin(candidate)
    rescue ArgumentError => e
      raise JumpRtConfigurationError, "#{name} must be a public HTTPS origin for Jump: #{e.message}"
    end
  end

  def issuer_jwks_uri(namespace, env: ENV)
    "#{issuer_origin(namespace, env: env)}#{JWKS_PATH}"
  end

  # Acme is Base-hosted and issues through the Base or Auth controller that owns the request; Edit
  # is a receiver only. Neither has a Jump issuer namespace.
  def namespace_for_controller(controller_class_name)
    service =
      case controller_class_name.to_s
      when /\AAuth::/ then "AUTH"
      when /\ACore::/ then "CORE"
      when /\AWarp::/ then "WARP"
      when /\ABase::/ then "BASE"
      when /\APalm::/ then "PALM"
      end
    surface =
      case controller_class_name.to_s
      when /\A\w+::App::/ then "APP"
      when /\A\w+::Com::/ then "COM"
      when /\A\w+::Org::/ then "ORG"
      end
    if service.nil? || surface.nil?
      raise JumpRtConfigurationError,
            "No Jump RT issuer namespace is configured for controller #{controller_class_name.inspect}"
    end

    normalize_namespace("#{service}_#{surface}")
  end

  def normalize_namespace(namespace)
    value = namespace.to_s.upcase
    unless ISSUER_ORIGIN_ENV.key?(value)
      raise JumpRtConfigurationError, "unsupported Jump RT issuer surface: #{namespace.inspect}"
    end

    value
  end

  def normalize_host(host)
    host.to_s.strip.sub(/\Ahttps?:\/\//, "").split("/").first
  end
end
