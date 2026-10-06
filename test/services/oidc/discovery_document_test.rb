# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcDiscoveryDocumentTest < ActiveSupport::TestCase
  test "builds app surface discovery from the issuer contract" do
    document = OidcDiscoveryDocument.for_resource_type("client")

    assert_equal OidcIssuer.for_resource_type("client"), document.fetch(:issuer)
    assert_equal "#{document.fetch(:issuer)}/oauth/authorize", document.fetch(:authorization_endpoint)
    assert_equal "#{document.fetch(:issuer)}/oauth/token", document.fetch(:token_endpoint)
    assert_equal "#{document.fetch(:issuer)}/oauth/userinfo", document.fetch(:userinfo_endpoint)
    assert_equal "#{document.fetch(:issuer)}/.well-known/jwks.json", document.fetch(:jwks_uri)
    assert_equal "#{document.fetch(:issuer)}/oidc/logout", document.fetch(:end_session_endpoint)
    assert_equal ["code"], document.fetch(:response_types_supported)
    assert_equal %w(authorization_code refresh_token), document.fetch(:grant_types_supported)
    assert_equal %w(private_key_jwt client_secret_post none), document.fetch(:token_endpoint_auth_methods_supported)
    assert_equal ["ES384"], document.fetch(:token_endpoint_auth_signing_alg_values_supported)
    assert_equal ["S256"], document.fetch(:code_challenge_methods_supported)
    assert document.fetch(:backchannel_logout_supported)
    assert document.fetch(:backchannel_logout_session_supported)
    assert_not document.key?(:frontchannel_logout_supported)
    assert_not document.key?(:frontchannel_logout_session_supported)
    assert_not document.key?(:redirect_uris_supported)
    assert_not document.key?(:loopback_redirect_uris_supported)
  end

  # `ri` is a localization hint, not part of the OIDC contract. The issuer must
  # be a bare https origin (no query/fragment) and no advertised endpoint may
  # carry `ri`, regardless of any regional request context.
  test "issuer and endpoints never carry ri or a query/fragment" do
    %w(client visitor operator).each do |resource_type|
      document = OidcDiscoveryDocument.for_resource_type(resource_type)
      issuer = URI.parse(document.fetch(:issuer))

      assert_nil issuer.query, "#{resource_type} issuer must not include a query"
      assert_nil issuer.fragment, "#{resource_type} issuer must not include a fragment"
      assert_includes %w(http https), issuer.scheme

      endpoint_keys = %i(
        authorization_endpoint token_endpoint userinfo_endpoint jwks_uri
        revocation_endpoint end_session_endpoint
      )
      endpoint_keys.each do |key|
        endpoint = document.fetch(key)

        assert_not_includes endpoint, "ri=", "#{resource_type} #{key} must not carry ri"
        assert_not_includes endpoint, "?", "#{resource_type} #{key} must not carry a query string"
      end
    end
  end
end
