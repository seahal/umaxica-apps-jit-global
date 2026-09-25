# typed: false
# frozen_string_literal: true

module JumpRtSurface
  module_function

  def issuer_origin(namespace)
    JitSecurityJwtRegistry.surface(namespace).issuer
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
