# typed: false
# frozen_string_literal: true

# Delivers a signed Logout Token to one registered RP back-channel endpoint (R5-WU10, one.md 7.6).
# The endpoint comes from the frozen client registration recorded on the outbox row. The connection
# pins a public DNS result for the request, and redirects are never followed. Only HTTP 200 is an
# acknowledgement; OpOutboxDispatchJob classifies every other response.
class OidcBackchannelLogoutClient
  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 3

  class << self
    public

    # Returns :acknowledged, or an error code String for the outbox retry record.
    def call(endpoint:, logout_token:)
      uri = URI.parse(endpoint)
      connection = OutboundHttp::Connection.build(
        url: uri, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT, require_https: true,
        require_public_address: true,
      )
      response = connection.post(uri, { logout_token: })
      (response.status.to_i == 200) ? :acknowledged : "http_#{response.status.to_i}"
    rescue Faraday::Error
      "transport_failure"
    rescue OutboundHttp::Connection::InsecureEndpointError, URI::InvalidURIError
      "invalid_endpoint"
    end
  end
end
