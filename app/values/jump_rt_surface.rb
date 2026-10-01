# typed: false
# frozen_string_literal: true

module JumpRtSurface
  module_function

  def issuer_origin(namespace)
    if Rails.env.development?
      raise JumpRtConfigurationError,
            "Development Jump issuance requires an approved public issuer, JWKS, signing kid and gateway trust contract"
    end

    JitSecurityJwtRegistry.surface(normalize_namespace(namespace)).issuer
  end

  def namespace_for_controller(controller_class_name)
    service =
      case controller_class_name.to_s
      when /\AAuth::/ then "AUTH"
      when /\AAcme::/ then "ACME"
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
    if service.blank? || surface.blank?
      raise JumpRtConfigurationError,
            "No Jump RT issuer namespace is configured for controller #{controller_class_name.inspect}"
    end

    normalize_namespace("#{service}_#{surface}")
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
