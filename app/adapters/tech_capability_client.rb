# typed: false
# frozen_string_literal: true

# Tech RP client for the org authority's capability decision (R5-WU11, one.md 4.2/6.4).
#
# Every request asks the authority again; there is no positive cache. Any transport failure,
# non-200, malformed body or missing assertion is a denial (fail closed).
class TechCapabilityClient
  CLIENT_ID = "tech-org-ww"
  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 3

  class << self
    public

    def allowed?(access_token:)
      return false if access_token.blank?

      base_origin = Rails.configuration.x.boot_config.fetch(:hosts).base_for_resource_type("operator")
      endpoint = "#{base_origin}/api/v0/tech-capability-checks"
      assertion = OidcClientAssertionJwt.issue(client_id: CLIENT_ID, token_url: endpoint)
      return false if assertion.blank?

      uri = URI.parse(endpoint)
      connection = OutboundHttp::Connection.build(
        url: uri, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT, require_https: true,
      )
      response = connection.post(uri, { access_token:, client_assertion: assertion })
      return false unless response.status.to_i == 200

      body = JSON.parse(response.body.to_s)
      body.is_a?(Hash) && body["allowed"] == true
    rescue Faraday::Error, JSON::ParserError, URI::InvalidURIError, OutboundHttp::Connection::InsecureEndpointError
      false
    end
  end
end
