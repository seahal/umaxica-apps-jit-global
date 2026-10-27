# frozen_string_literal: true

require "test_helper"

class AcceptanceWu02ClientAssertionAudienceTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  REALMS = [
    { surface: :app, client_id: "core-app-jp", resource_type: "client", base_namespace: "BASE_APP" },
    { surface: :com, client_id: "core-com-jp", resource_type: "visitor", base_namespace: "BASE_COM" },
    { surface: :org, client_id: "core-org-jp", resource_type: "operator", base_namespace: "BASE_ORG" },
  ].freeze

  test "A02-5: token endpoint rejects retired www client assertion audiences in every realm" do
    REALMS.each do |realm|
      client = OidcClientRegistry.find!(realm.fetch(:client_id))
      host!(visa_host_for_test_surface(realm.fetch(:surface)))
      https!
      retired_endpoint = "#{JitSecurityJwtRegistry.surface(realm.fetch(:base_namespace)).issuer}/oauth/token"
      assertion = OidcClientAssertionJwt.issue(client_id: client.client_id, token_url: retired_endpoint)

      post "/oauth/token", params: {
        grant_type: "authorization_code",
        code: "unused-authorization-code",
        redirect_uri: client.redirect_uris_by_realm.fetch(realm.fetch(:resource_type)).first,
        client_id: client.client_id,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: assertion,
        code_verifier: SecureRandom.urlsafe_base64(32),
      }

      assert_response :bad_request
      assert_equal "invalid_client", response.parsed_body.fetch("error"), realm.fetch(:surface).to_s
    end
  end
end
