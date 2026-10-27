# typed: false
# frozen_string_literal: true

module OutboundHttp
  # Server-to-server calls from one first-party surface to another (OIDC token and UserInfo, the
  # Avatar, Membership, Org admin and Publishing authorities) reach this same Rails process. In local
  # development the public names resolve to this container (compose network aliases) but HTTPS is
  # terminated by Cloudflare Tunnel, not here, so the call goes to the local HTTP port. Production
  # keeps the public HTTPS URL unchanged.
  module LocalBackChannel
    module_function

    def url(public_url)
      return public_url unless Rails.env.local?

      uri = URI.parse(public_url)
      return public_url unless uri.is_a?(URI::HTTP) && first_party_host?(uri.host)

      uri.scheme = "http"
      uri.port = local_port
      uri.to_s
    rescue URI::InvalidURIError
      public_url
    end

    # HTTPS is required except for the exact local form `url` produces.
    def require_https?(url)
      return true unless Rails.env.local?

      uri = URI.parse(url)
      !(uri.scheme == "http" && first_party_host?(uri.host) && uri.port == local_port && uri.userinfo.blank?)
    rescue URI::InvalidURIError
      true
    end

    def first_party_host?(host)
      hosts = Rails.configuration.x.boot_config.fetch(:hosts)
      [
        hosts.acme_service, hosts.acme_corporate, hosts.acme_staff,
        hosts.base_service, hosts.base_corporate, hosts.base_staff,
        hosts.visa_service, hosts.visa_corporate, hosts.visa_staff,
      ].map { |configured| configured.host.to_s.downcase }.include?(host.to_s.downcase)
    end

    def local_port
      Integer(ENV.fetch("PORT"), exception: false) || 3000
    end
  end
end
