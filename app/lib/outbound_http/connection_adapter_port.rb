# typed: false
# frozen_string_literal: true

require "faraday/net_http"
require "ipaddr"
require "socket"

module OutboundHttp
  # A Faraday Net::HTTP adapter that pins a public DNS answer for one request. This is used for
  # server-to-server calls to registered public endpoints where checking DNS before Faraday opens
  # the socket would leave a rebinding window.
  class ConnectionAdapterPort < Faraday::Adapter::NetHttp
    BLOCKED_IPV4_NETWORKS = %w(
      0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12
      192.0.0.0/24 192.0.2.0/24 192.88.99.0/24 192.168.0.0/16 198.18.0.0/15
      198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4 168.63.129.16/32
    ).map { |network| IPAddr.new(network) }.freeze
    GLOBAL_IPV6_NETWORK = IPAddr.new("2000::/3")
    BLOCKED_IPV6_NETWORKS = %w(
      2001::/23 2001:db8::/32 2002::/16 3fff::/20 64:ff9b::/96 64:ff9b:1::/48
    ).map { |network| IPAddr.new(network) }.freeze

    def initialize(app = nil, require_public_address:, **, &)
      @require_public_address = require_public_address
      super(app, **, &)
    end

    public

    def net_http_connection(env)
      return super unless @require_public_address
      raise Connection::InsecureEndpointError, "public endpoint cannot use an HTTP proxy" if env[:request][:proxy]

      uri = env[:url]
      host = uri.hostname
      if host.blank? || uri.userinfo.present? || uri.fragment.present?
        raise Connection::InsecureEndpointError, "registered public endpoint is malformed"
      end

      port = uri.port || ((uri.scheme == "https") ? 443 : 80)
      addresses = Addrinfo.getaddrinfo(host, port, nil, :STREAM).map(&:ip_address)
      addresses.uniq!
      if addresses.empty? || addresses.any? { |address| blocked_address?(address) }
        raise Connection::InsecureEndpointError, "registered public endpoint resolved to a non-public address"
      end

      http = Net::HTTP.new(host, port, nil)
      http.ipaddr = addresses.first
      http
    rescue SocketError => e
      raise Faraday::ConnectionFailed, e
    rescue IPAddr::InvalidAddressError
      raise Connection::InsecureEndpointError, "registered public endpoint resolved to an invalid address"
    end

    private

    def blocked_address?(value)
      address = IPAddr.new(value)
      if address.ipv4?
        BLOCKED_IPV4_NETWORKS.any? { |network| network.include?(address) }
      else
        # IPAddr provides include? but not the ActiveSupport exclude? method.
        return true unless GLOBAL_IPV6_NETWORK.include?(address)

        BLOCKED_IPV6_NETWORKS.any? { |network| network.include?(address) }
      end
    end
  end
end
