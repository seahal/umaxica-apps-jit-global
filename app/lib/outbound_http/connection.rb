# typed: false
# frozen_string_literal: true

require "faraday"

module OutboundHttp
  # Single construction point for the application's hand-written outbound HTTP
  # requests. Every call site went through Net::HTTP directly before this, and
  # four of them set no timeout at all, so a hung upstream held a request thread
  # for the stdlib default of sixty seconds on the sign-in and bot-check paths.
  #
  # Timeouts are required keyword arguments rather than defaults: a caller that
  # forgets one must fail at construction instead of silently inheriting a
  # transport default (`generic/no-silent-fallback.mdc`).
  module Connection
    # Faraday wraps SocketError, SystemCallError, the Net::HTTP timeouts, and
    # OpenSSL::SSL::SSLError into its own hierarchy, so a call site rescuing the
    # stdlib classes would no longer see them. Rescue this instead.
    NETWORK_ERRORS = [Faraday::Error].freeze

    class InsecureEndpointError < StandardError; end

    # `require_https` has no default on purpose. Most callers reach fixed HTTPS
    # provider endpoints, but OidcBackchannelLogoutDeliveryJob posts to
    # registry-supplied relying-party URIs whose scheme is decided by the
    # registration, so the policy has to be stated per call site rather than
    # assumed here.
    #
    # `write_timeout` is genuinely optional: only the Google JWKS fetch pins one.
    def self.build(url:, open_timeout:, read_timeout:, require_https:, write_timeout: nil)
      # Faraday mutates the URI it is handed (Faraday::Connection#url_prefix=
      # assigns #path on it). Call sites legitimately pass a shared class
      # constant -- JitSecurityTurnstileVerifier::VERIFY_URI is frozen, others
      # are merely shared -- so build always works on a private copy: a frozen
      # constant would otherwise raise FrozenError, and a shared mutable one
      # would be rewritten under other threads.
      uri = (url.is_a?(URI::Generic) ? url.dup : URI.parse(url.to_s))
      raise InsecureEndpointError, "outbound HTTP endpoint must be HTTPS" if require_https && !uri.is_a?(URI::HTTPS)

      Faraday.new(url: uri) do |builder|
        builder.request(:url_encoded)
        # No follow_redirects: OidcBackchannelLogoutDeliveryJob posts to an
        # allowlisted destination, and following a redirect off that list would
        # reintroduce the SSRF the allowlist exists to prevent.
        builder.adapter(default_adapter)
        builder.options.open_timeout = open_timeout
        builder.options.timeout = read_timeout
        builder.options.write_timeout = write_timeout if write_timeout
      end
    end

    # Faraday.default_adapter is deliberately left alone: the OmniAuth, OAuth2,
    # and openid_connect gem chain shares that global, and reassigning it would
    # change their transport as a side effect of this application's own calls.
    def self.default_adapter
      :net_http
    end
  end
end
