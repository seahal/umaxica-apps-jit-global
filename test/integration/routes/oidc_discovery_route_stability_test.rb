# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Guards that every path advertised in the OIDC discovery document resolves in
# the Rails router for the corresponding surface host.  A route rename that
# updates visa.rb but not OidcIssuer - or vice versa - will fail here before
# any RP ever tries to use the stale URL.
#
# This test is the bridge between:
#   - test/services/oidc/discovery_document_test.rb  (content structure)
#   - test/integration/routes/base_authority_route_contract_test.rb  (literal authority paths)
class OidcDiscoveryRouteStabilityTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  SURFACES = [
    { resource_type: "client" },
    { resource_type: "visitor" },
    { resource_type: "operator" },
  ].freeze

  # HTTP method for each discovery document endpoint key.
  # Matches the HTTP methods registered in config/routes/visa.rb.
  ENDPOINT_ROUTE_METHODS = {
    authorization_endpoint: :get,
    token_endpoint: :post,
    userinfo_endpoint: :get,
    jwks_uri: :get,
    revocation_endpoint: :post,
    end_session_endpoint: :get,
  }.freeze

  SURFACES.each do |surface|
    ENDPOINT_ROUTE_METHODS.each do |key, http_method|
      test "#{surface[:resource_type]} discovery #{key} resolves in Rails router" do
        document = OidcDiscoveryDocument.for_resource_type(surface[:resource_type])
        endpoint_url = document.fetch(key)

        result = Rails.application.routes.recognize_path(
          endpoint_url,
          method: http_method,
        )

        assert_predicate result[:controller], :present?,
                         "#{surface[:resource_type]} #{key} URL #{endpoint_url.inspect} must resolve"
      end
    end

    test "#{surface[:resource_type]} discovery issuer host matches configured Visa host" do
      hosts = Rails.configuration.x.boot_config.fetch(:hosts)
      host = {
        "client" => hosts.visa_service.host,
        "visitor" => hosts.visa_corporate.host,
        "operator" => hosts.visa_staff.host,
      }.fetch(surface.fetch(:resource_type))
      document = OidcDiscoveryDocument.for_resource_type(surface[:resource_type])
      issuer_host = URI.parse(document.fetch(:issuer)).host

      assert_equal host, issuer_host,
                   "#{surface[:resource_type]} issuer host must equal the configured Visa surface host"
    end

    test "#{surface[:resource_type]} all discovery endpoint URLs share the issuer as prefix" do
      document = OidcDiscoveryDocument.for_resource_type(surface[:resource_type])
      issuer = document.fetch(:issuer)

      ENDPOINT_ROUTE_METHODS.each_key do |key|
        endpoint = document.fetch(key)

        assert endpoint.start_with?(issuer),
               "#{surface[:resource_type]} #{key} (#{endpoint}) must be prefixed by issuer (#{issuer})"
      end
    end
  end
end
