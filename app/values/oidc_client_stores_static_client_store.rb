# typed: false
# frozen_string_literal: true

module OidcClientStoresStaticClientStore
  LOOPBACK_HOST_TOKENS = %w(localhost 127.0.0.1 ::1).freeze
  private_constant :LOOPBACK_HOST_TOKENS

  module_function

  def clients
    first_party_browser_rp_clients
      .freeze
  end

  # First-party Browser RP clients use independent audiences, keys, callbacks, and RP sessions.
  def first_party_browser_rp_clients
    FIRST_PARTY_RP_SPECS.to_h { |client_id, spec| [client_id, face_rp_client(**spec)] }
  end

  FIRST_PARTY_RP_SPECS = {
    "core-app" => {
      env_key: "PUBLIC_CORE_SERVICE_URL",
      resource_type: "client",
      aud: "core-app",
      name: "Core App RP",
      jwt_namespace: "CORE_APP",
    },
    "core-com" => {
      env_key: "PUBLIC_CORE_CORPORATE_URL",
      resource_type: "visitor",
      aud: "core-com",
      name: "Core Com RP",
      jwt_namespace: "CORE_COM",
    },
    "core-org" => {
      env_key: "PUBLIC_CORE_STAFF_URL",
      resource_type: "operator",
      aud: "core-org",
      name: "Core Org RP",
      jwt_namespace: "CORE_ORG",
    },
    "warp-app" => {
      env_key: "PUBLIC_WARP_SERVICE_URL",
      default_host: "warp.app.localhost",
      resource_type: "client",
      aud: "warp-app",
      name: "Warp App RP",
      jwt_namespace: "WARP_APP",
    },
    "warp-com" => {
      env_key: "PUBLIC_WARP_CORPORATE_URL",
      default_host: "warp.com.localhost",
      resource_type: "visitor",
      aud: "warp-com",
      name: "Warp Com RP",
      jwt_namespace: "WARP_COM",
    },
    "warp-org" => {
      env_key: "PUBLIC_WARP_STAFF_URL",
      default_host: "warp.org.localhost",
      resource_type: "operator",
      aud: "warp-org",
      name: "Warp Org RP",
      jwt_namespace: "WARP_ORG",
    },
    "edit-org" => {
      env_key: "PUBLIC_EDIT_STAFF_URL",
      default_host: "edit.org.localhost",
      resource_type: "operator",
      aud: "edit-org",
      name: "Edit Org RP",
      jwt_namespace: "EDIT_ORG",
    },
    "palm-app" => {
      env_key: "PUBLIC_PALM_SERVICE_URL",
      resource_type: "client",
      aud: "palm-app",
      name: "Palm App RP",
      jwt_namespace: "PALM_APP",
      backchannel_logout: false,
    },
    "tech-org" => {
      env_key: %w(PUBLIC_TECH_STAFF_URL PRIVATE_TECH_STAFF_URL),
      resource_type: "operator",
      aud: "tech-org",
      name: "Tech Org RP",
      jwt_namespace: "TECH_ORG",
      backchannel_logout: false,
      required_operator_capability: OperatorCapabilityGrant::TECH_ACCESS,
    },
    "base-app-ww" => {
      env_key: "BASE_SERVICE_URL",
      resource_type: "client",
      aud: "base-app-ww",
      name: "Base App Self RP",
      jwt_namespace: "BASE_RP_APP_WW",
    },
    "base-com-ww" => {
      env_key: "BASE_CORPORATE_URL",
      resource_type: "visitor",
      aud: "base-com-ww",
      name: "Base Com Self RP",
      jwt_namespace: "BASE_RP_COM_WW",
    },
    "base-org-ww" => {
      env_key: "BASE_STAFF_URL",
      resource_type: "operator",
      aud: "base-org-ww",
      name: "Base Org Self RP",
      jwt_namespace: "BASE_RP_ORG_WW",
    },
  }.freeze

  def face_rp_client(env_key:, resource_type:, aud:, name:, jwt_namespace:, default_host: nil,
                     callback_path: AuthBoundaryAuthorityMap::CANONICAL_RP_CALLBACK_PATH,
                     sign_out_path: AuthBoundaryAuthorityMap::CANONICAL_RP_SIGN_OUT_PATH,
                     backchannel_logout: true, required_operator_capability: nil)
    {
      redirect_uris_by_realm: {
        resource_type => build_redirect_uris(env_key, default_host, path: callback_path),
      },
      post_logout_redirect_uris: build_post_logout_redirect_uris(
        env_key, default_host, path: sign_out_path,
      ),
      backchannel_logout_uris: backchannel_logout ? build_logout_uris(env_key, "backchannel/logout", default_host) : [],
      backchannel_logout_session_required: backchannel_logout,
      aud: aud,
      resource_type: resource_type,
      name: name,
      allowed_scopes: OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      token_endpoint_auth_method: "private_key_jwt",
      jwt_namespace: jwt_namespace,
      required_operator_capability: required_operator_capability,
    }
  end

  # default_host is only consulted for env keys boot_host_for does not map; keys it maps resolve
  # from boot config and must not carry a literal default that can drift from the real host.
  def build_redirect_uris(env_key, default_host = nil, path: "/oidc/callback")
    configured_hosts_for(env_key, default_host).map do |host|
      protocol = (Rails.env.production? || public_host?(host)) ? "https" : "http"
      port_suffix = (Rails.env.production? || public_host?(host)) ? "" : ":3000"
      "#{protocol}://#{host}#{port_suffix}#{path}"
    end
  end

  def build_post_logout_redirect_uris(env_key, default_host = nil,
                                      path: AuthBoundaryAuthorityMap::CANONICAL_RP_SIGN_OUT_PATH)
    configured_hosts_for(env_key, default_host).flat_map do |host|
      protocol = (Rails.env.production? || public_host?(host)) ? "https" : "http"
      port_suffix = (Rails.env.production? || public_host?(host)) ? "" : ":3000"
      RequestContextContract.allowed_regions.map do |region|
        "#{protocol}://#{host}#{port_suffix}#{path}?ri=#{region}"
      end
    end
  end

  def build_logout_uris(env_key, endpoint, default_host = nil)
    configured_hosts_for(env_key, default_host).map do |host|
      protocol = (Rails.env.production? || public_host?(host)) ? "https" : "http"
      port_suffix = (Rails.env.production? || public_host?(host)) ? "" : ":3000"
      "#{protocol}://#{host}#{port_suffix}/oidc/#{endpoint}"
    end
  end

  def public_host?(host)
    normalized_host = URI.parse("//#{host}").host.to_s

    normalized_host.present? &&
      LOOPBACK_HOST_TOKENS.none? { |token| normalized_host.include?(token) }
  rescue URI::InvalidURIError
    false
  end

  def configured_hosts_for(env_keys, default_host = nil)
    hosts = []
    Array(env_keys).each do |env_key|
      env_host = ENV[env_key]
      hosts << env_host if env_host.present?
      hosts << boot_host_for(env_key, default_host)
    end
    hosts.map! { |host| normalize_host(host) }
    hosts.uniq!
    hosts
  end

  def boot_host_for(env_key, default_host = nil)
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    host =
      case env_key
      when "PUBLIC_AUTH_SERVICE_URL", "PRIVATE_AUTH_SERVICE_URL" then hosts.sign_service.to_s
      when "PUBLIC_AUTH_STAFF_URL", "PRIVATE_AUTH_STAFF_URL" then hosts.sign_staff.to_s
      when "PUBLIC_AUTH_CORPORATE_URL", "PRIVATE_AUTH_CORPORATE_URL" then hosts.sign_corporate.to_s
      when "BASE_SERVICE_URL" then hosts.base_service.to_s
      when "BASE_STAFF_URL" then hosts.base_staff.to_s
      when "BASE_CORPORATE_URL" then hosts.base_corporate.to_s
      when "PUBLIC_WARP_SERVICE_URL" then hosts.warp_service.to_s
      when "PUBLIC_WARP_STAFF_URL" then hosts.warp_staff.to_s
      when "PUBLIC_WARP_CORPORATE_URL" then hosts.warp_corporate.to_s
      when "PUBLIC_CORE_SERVICE_URL", "CORE_SERVICE_URL" then hosts.core_service.to_s
      when "PUBLIC_CORE_STAFF_URL", "CORE_STAFF_URL" then hosts.core_staff.to_s
      when "PUBLIC_CORE_CORPORATE_URL", "CORE_CORPORATE_URL" then hosts.core_corporate.to_s
      when "PUBLIC_PALM_SERVICE_URL" then hosts.palm_service.to_s
      when "PUBLIC_TECH_STAFF_URL", "PRIVATE_TECH_STAFF_URL" then hosts.tech_staff.to_s
      else
        raise KeyError, "No boot host mapping for #{env_key} and no default host given" if default_host.blank?

        default_host
      end

    normalize_host(host)
  end

  def normalize_host(host)
    parsed_host = URI.parse(host.to_s).host if host.to_s.include?("://")
    parsed_host.presence || URI.parse("//#{host}").host.to_s.presence || host.to_s
  rescue URI::InvalidURIError
    host.to_s
  end

  private_class_method :first_party_browser_rp_clients, :face_rp_client, :build_redirect_uris,
                       :build_post_logout_redirect_uris,
                       :build_logout_uris, :public_host?, :configured_hosts_for, :boot_host_for,
                       :normalize_host
end
