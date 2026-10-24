# typed: false
# frozen_string_literal: true

module OidcIssuer
  LOOPBACK_HOST_TOKENS = %w(localhost 127.0.0.1 ::1).freeze

  module_function

  def for_client(client)
    for_resource_type(resource_type_for_client(client))
  end

  def for_resource_type(resource_type)
    absolute_url(host_for_resource_type(resource_type))
  end

  def jwks_uri(resource_type)
    "#{for_resource_type(resource_type)}/.well-known/jwks.json"
  end

  def authorization_endpoint(resource_type)
    "#{for_resource_type(resource_type)}/oauth/authorize"
  end

  def token_endpoint(resource_type)
    "#{for_resource_type(resource_type)}/oauth/token"
  end

  # R5-WU08 read-only Refresh delivery recovery endpoint of the realm OP.
  def refresh_delivery_query_endpoint(resource_type)
    "#{for_resource_type(resource_type)}/oauth/refresh-deliveries/query"
  end

  def userinfo_endpoint(resource_type)
    "#{for_resource_type(resource_type)}/oauth/userinfo"
  end

  def revocation_endpoint(resource_type)
    "#{for_resource_type(resource_type)}/oauth/revoke"
  end

  def end_session_endpoint(resource_type)
    "#{for_resource_type(resource_type)}/oidc/logout"
  end

  def host_for_client(client)
    host_for_resource_type(resource_type_for_client(client))
  end

  def host_for_resource_type(resource_type)
    boot_hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    case resource_type.to_s
    when "operator", "staff"
      host_component(boot_hosts.visa_staff)
    when "visitor", "customer"
      host_component(boot_hosts.visa_corporate)
    else
      host_component(boot_hosts.visa_service)
    end
  end

  def jwt_issuer_id_for_client(client)
    jwt_issuer_id_for_resource_type(resource_type_for_client(client))
  end

  def jwt_issuer_id_for_resource_type(resource_type)
    namespace =
      case resource_type.to_s
      when "operator", "staff" then "VISA_ORG"
      when "visitor", "customer" then "VISA_COM"
      else "VISA_APP"
      end

    "surface:#{namespace}"
  end

  def resource_type_for_client(client)
    case client.resource_type.to_s
    when "operator", "staff" then "operator"
    when "visitor", "customer" then "visitor"
    else "client"
    end
  end

  def absolute_url(host_or_url)
    normalized = host_or_url.to_s.strip
    return normalized.delete_suffix("/") if normalized.match?(%r{\Ahttps?://})

    "#{scheme_for(normalized)}://#{normalized}#{port_suffix_for(normalized)}"
  end

  def scheme_for(host)
    (Rails.env.production? || public_host?(host)) ? "https" : "http"
  end

  def port_suffix_for(host)
    return "" if Rails.env.production? || public_host?(host)
    return "" if host.include?(":")

    ":3000"
  end

  def public_host?(host)
    normalized_host = URI.parse("//#{host}").host.to_s
    normalized_host.present? &&
      LOOPBACK_HOST_TOKENS.none? { |token| normalized_host.include?(token) }
  rescue URI::InvalidURIError
    false
  end

  def host_component(value)
    raw = value.to_s.strip
    return raw if raw.blank?

    parsed = URI.parse(raw)
    return parsed.host if parsed.host.present?

    raw.delete_prefix("//")
  rescue URI::InvalidURIError
    raw.delete_prefix("https://").delete_prefix("http://")
  end
end
