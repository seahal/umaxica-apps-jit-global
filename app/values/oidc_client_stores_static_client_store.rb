# typed: false
# frozen_string_literal: true

module OidcClientStoresStaticClientStore
  LOOPBACK_HOST_TOKENS = %w(localhost 127.0.0.1 ::1).freeze
  private_constant :LOOPBACK_HOST_TOKENS

  module_function

  def clients
    sign_and_browser_rp_clients.merge(native_and_content_rp_clients).freeze
  end

  def sign_and_browser_rp_clients
    {
      "sign-rp" => sign_rp_client,
      "base-rails-rp" => base_rails_rp_client,
      "side-rails-rp" => side_rails_rp_client,
      "core-next-rp" => core_next_rp_client,
    }
  end

  def native_and_content_rp_clients
    {
      "app-ios-rp" => native_rp_client(["umaxica://oidc/callback"], "App iOS RP"),
      "app-android-rp" => native_rp_client(["com.umaxica.app:/oidc/callback"], "App Android RP"),
    }.merge(content_surface_rp_clients)
  end

  def sign_rp_client
    {
      redirect_uris_by_realm: {
        "client" => build_redirect_uris("PUBLIC_AUTH_SERVICE_URL") + build_redirect_uris("PRIVATE_AUTH_SERVICE_URL"),
        "operator" => build_redirect_uris("PUBLIC_AUTH_STAFF_URL") + build_redirect_uris("PRIVATE_AUTH_STAFF_URL"),
        "visitor" => build_redirect_uris("PUBLIC_AUTH_CORPORATE_URL") +
          build_redirect_uris("PRIVATE_AUTH_CORPORATE_URL"),
      },
      post_logout_redirect_uris: build_post_logout_redirect_uris("PUBLIC_AUTH_SERVICE_URL") +
        build_post_logout_redirect_uris("PRIVATE_AUTH_SERVICE_URL") +
        build_post_logout_redirect_uris("PUBLIC_AUTH_STAFF_URL") +
        build_post_logout_redirect_uris("PRIVATE_AUTH_STAFF_URL") +
        build_post_logout_redirect_uris("PUBLIC_AUTH_CORPORATE_URL") +
        build_post_logout_redirect_uris("PRIVATE_AUTH_CORPORATE_URL"),
      backchannel_logout_uris: build_logout_uris("PUBLIC_AUTH_SERVICE_URL", "backchannel/logout") +
        build_logout_uris("PRIVATE_AUTH_SERVICE_URL", "backchannel/logout") +
        build_logout_uris("PUBLIC_AUTH_STAFF_URL", "backchannel/logout") +
        build_logout_uris("PRIVATE_AUTH_STAFF_URL", "backchannel/logout") +
        build_logout_uris("PUBLIC_AUTH_CORPORATE_URL", "backchannel/logout") +
        build_logout_uris("PRIVATE_AUTH_CORPORATE_URL", "backchannel/logout"),
      backchannel_logout_session_required: true,
      aud: "sign-rp",
      resource_type: "client",
      name: "Sign RP",
      allowed_scopes: OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      token_endpoint_auth_method: "private_key_jwt",
      jwt_namespace: "SIGN_APP",
    }
  end

  def base_rails_rp_client
    {
      redirect_uris_by_realm: {
        "client" => build_redirect_uris("BASE_SERVICE_URL", "www.app.localhost") +
          build_redirect_uris("SIDE_SERVICE_URL", "wide.app.localhost"),
        "operator" => build_redirect_uris("BASE_STAFF_URL", "www.org.localhost") +
          build_redirect_uris("SIDE_STAFF_URL", "wide.org.localhost"),
        "visitor" => build_redirect_uris("BASE_CORPORATE_URL", "www.com.localhost") +
          build_redirect_uris("SIDE_CORPORATE_URL", "wide.com.localhost"),
      },
      post_logout_redirect_uris: build_post_logout_redirect_uris(
        "BASE_SERVICE_URL", "www.app.localhost", path: "/lobby",
      ) +
        build_post_logout_redirect_uris("BASE_STAFF_URL", "www.org.localhost", path: "/lobby") +
        build_post_logout_redirect_uris("BASE_CORPORATE_URL", "www.com.localhost", path: "/lobby") +
        build_post_logout_redirect_uris("SIDE_SERVICE_URL", "wide.app.localhost") +
        build_post_logout_redirect_uris("SIDE_STAFF_URL", "wide.org.localhost") +
        build_post_logout_redirect_uris("SIDE_CORPORATE_URL", "wide.com.localhost"),
      aud: "base-rails-rp",
      resource_type: "client",
      name: "Base Rails RP",
      allowed_scopes: OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      token_endpoint_auth_method: "private_key_jwt",
      jwt_namespace: "BASE_APP",
    }
  end

  def side_rails_rp_client
    {
      redirect_uris_by_realm: {
        "client" => build_redirect_uris("SIDE_SERVICE_URL", "wide.app.localhost"),
        "operator" => build_redirect_uris("SIDE_STAFF_URL", "wide.org.localhost"),
        "visitor" => build_redirect_uris("SIDE_CORPORATE_URL", "wide.com.localhost"),
      },
      post_logout_redirect_uris: build_post_logout_redirect_uris("SIDE_SERVICE_URL", "wide.app.localhost") +
        build_post_logout_redirect_uris("SIDE_STAFF_URL", "wide.org.localhost") +
        build_post_logout_redirect_uris("SIDE_CORPORATE_URL", "wide.com.localhost"),
      backchannel_logout_uris: build_logout_uris("SIDE_SERVICE_URL", "backchannel/logout", "wide.app.localhost") +
        build_logout_uris("SIDE_STAFF_URL", "backchannel/logout", "wide.org.localhost") +
        build_logout_uris("SIDE_CORPORATE_URL", "backchannel/logout", "wide.com.localhost"),
      backchannel_logout_session_required: true,
      aud: "side-rails-rp",
      resource_type: "client",
      name: "Side Rails RP",
      allowed_scopes: OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      token_endpoint_auth_method: "private_key_jwt",
      jwt_namespace: "BASE_APP",
    }
  end

  def core_next_rp_client
    {
      redirect_uris_by_realm: {
        "client" => build_redirect_uris("PUBLIC_CORE_SERVICE_URL"),
        "operator" => build_redirect_uris("PUBLIC_CORE_STAFF_URL"),
        "visitor" => build_redirect_uris("PUBLIC_CORE_CORPORATE_URL"),
      },
      post_logout_redirect_uris: build_post_logout_redirect_uris("PUBLIC_CORE_SERVICE_URL") +
        build_post_logout_redirect_uris("PUBLIC_CORE_STAFF_URL") +
        build_post_logout_redirect_uris("PUBLIC_CORE_CORPORATE_URL"),
      backchannel_logout_uris: build_logout_uris("PUBLIC_CORE_SERVICE_URL", "backchannel/logout") +
        build_logout_uris("PUBLIC_CORE_STAFF_URL", "backchannel/logout") +
        build_logout_uris("PUBLIC_CORE_CORPORATE_URL", "backchannel/logout"),
      backchannel_logout_session_required: true,
      aud: "core-next-rp",
      resource_type: "client",
      name: "Core Next RP",
      allowed_scopes: OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      token_endpoint_auth_method: "private_key_jwt",
      jwt_namespace: "CORE_APP",
    }
  end

  def native_rp_client(redirect_uris, name)
    {
      redirect_uris: redirect_uris,
      aud: "palm-api",
      resource_type: "client",
      name: name,
      allowed_scopes: OidcClientRegistry::PALM_ALLOWED_SCOPES,
      token_endpoint_auth_method: "none",
    }
  end

  def content_surface_rp_clients
    {
      "docs_app" => content_rp_client(
        "DOCS_SERVICE_URL", "docs.app.localhost", "umaxica-docs-app", "client",
        "Docs App",
      ),
      "docs_org" => content_rp_client(
        "DOCS_STAFF_URL", "docs.org.localhost", "umaxica-docs-org", "operator",
        "Docs Org",
      ),
      "docs_com" => content_rp_client(
        "DOCS_CORPORATE_URL", "docs.com.localhost", "umaxica-docs-com", "visitor", "Docs Com",
      ),
      "news_app" => content_rp_client(
        "NEWS_SERVICE_URL", "news.app.localhost", "umaxica-news-app", "client",
        "News App",
      ),
      "news_org" => content_rp_client(
        "NEWS_STAFF_URL", "news.org.localhost", "umaxica-news-org", "operator",
        "News Org",
      ),
      "news_com" => content_rp_client(
        "NEWS_CORPORATE_URL", "news.com.localhost", "umaxica-news-com", "visitor", "News Com",
      ),
      "help_app" => content_rp_client(
        "HELP_SERVICE_URL", "help.app.localhost", "umaxica-help-app", "client",
        "Help App",
      ),
      "help_org" => content_rp_client(
        "HELP_STAFF_URL", "help.org.localhost", "umaxica-help-org", "operator",
        "Help Org",
      ),
      "help_com" => content_rp_client(
        "HELP_CORPORATE_URL", "help.com.localhost", "umaxica-help-com", "visitor", "Help Com",
      ),
    }
  end

  def content_rp_client(env_key, default_host, aud, resource_type, name)
    {
      redirect_uris: build_redirect_uris(env_key, default_host),
      aud: aud,
      resource_type: resource_type,
      name: name,
      allowed_scopes: OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
    }
  end

  # default_host is only consulted for env keys boot_host_for does not map; keys it maps resolve
  # from boot config and must not carry a literal default that can drift from the real host.
  def build_redirect_uris(env_key, default_host = nil)
    configured_hosts_for(env_key, default_host).map do |host|
      protocol = (Rails.env.production? || public_host?(host)) ? "https" : "http"
      port_suffix = (Rails.env.production? || public_host?(host)) ? "" : ":3000"
      "#{protocol}://#{host}#{port_suffix}/oidc/callback"
    end
  end

  def build_post_logout_redirect_uris(env_key, default_host = nil, path: "/sign/out/complete")
    configured_hosts_for(env_key, default_host).map do |host|
      protocol = (Rails.env.production? || public_host?(host)) ? "https" : "http"
      port_suffix = (Rails.env.production? || public_host?(host)) ? "" : ":3000"
      "#{protocol}://#{host}#{port_suffix}#{path}"
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

  def configured_hosts_for(env_key, default_host = nil)
    hosts = [
      ENV.fetch(env_key, nil).presence,
      boot_host_for(env_key, default_host),
    ].compact
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
      when "SIDE_SERVICE_URL" then hosts.side_service.to_s
      when "SIDE_STAFF_URL" then hosts.side_staff.to_s
      when "SIDE_CORPORATE_URL" then hosts.side_corporate.to_s
      when "PUBLIC_CORE_SERVICE_URL", "CORE_SERVICE_URL" then hosts.core_service.to_s
      when "PUBLIC_CORE_STAFF_URL", "CORE_STAFF_URL" then hosts.core_staff.to_s
      when "PUBLIC_CORE_CORPORATE_URL", "CORE_CORPORATE_URL" then hosts.core_corporate.to_s
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

  private_class_method :build_redirect_uris, :build_post_logout_redirect_uris, :build_logout_uris,
                       :public_host?, :configured_hosts_for, :boot_host_for, :normalize_host
end
