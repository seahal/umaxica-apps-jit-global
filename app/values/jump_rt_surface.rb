# typed: false
# frozen_string_literal: true

module JumpRtSurface
  module_function

  # The external Jump gateway verifies an inbound rt against the JWKS published at its `iss`
  # (adr/secure-jump-link-redirector.md), so a Jump rt `iss` is the origin whose
  # `/.well-known/jwks.json` publishes the namespace's signing key -- not the registry's surface
  # issuer. The two differ for SIGN_*: the registry carries the logical ceremony issuer
  # `https://log.umaxica.*`, which serves no JWKS, while the SIGN_* keys are published by the Auth
  # hosts. Those origins come from the boot host registry, never from the request.
  #
  # Every other namespace's registry issuer is already its JWKS publication origin.
  AUTH_ISSUING_HOSTS = {
    "SIGN_APP" => :sign_service,
    "SIGN_COM" => :sign_corporate,
    "SIGN_ORG" => :sign_staff,
  }.freeze

  def issuer_origin(namespace)
    namespace = normalize_namespace(namespace)
    host_key = AUTH_ISSUING_HOSTS[namespace]
    return JitSecurityJwtRegistry.surface(namespace).issuer if host_key.nil?

    Rails.configuration.x.boot_config.fetch(:hosts).public_send(host_key).to_s
  end

  def namespace_for_controller(controller_class_name)
    service =
      case controller_class_name.to_s
      when /\A(?:Auth|Sign)::/ then "SIGN"
      when /\AAcme::/ then "ACME"
      when /\ACore::/ then "CORE"
      when /\AWarp::/ then "WARP"
      when /\ABase::/ then "BASE"
      end
    surface =
      case controller_class_name.to_s
      when /::App::/ then "APP"
      when /::Com::/ then "COM"
      when /::Org::/ then "ORG"
      end
    if service.blank? || surface.blank?
      raise JumpRtConfigurationError,
            "No Jump RT issuer namespace is configured for controller #{controller_class_name.inspect}"
    end

    "#{service}_#{surface}"
  end

  def normalize_namespace(namespace)
    value = namespace.to_s.upcase
    unless JitSecurityJwtRegistry::SURFACE_NAMESPACES.include?(value)
      raise JumpRtConfigurationError, "unsupported Jump RT issuer surface: #{namespace.inspect}"
    end

    value
  end

  def normalize_host(host)
    host.to_s.strip.sub(/\Ahttps?:\/\//, "").split("/").first
  end
end
