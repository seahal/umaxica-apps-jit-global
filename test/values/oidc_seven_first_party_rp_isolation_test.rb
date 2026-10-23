# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcSevenFirstPartyRpIsolationTest < ActiveSupport::TestCase
  test "first-party browser RPs have isolated client, audience, keys, and redirects" do
    ids = AuthBoundaryAuthorityMap.first_party_rp_client_ids
    clients = ids.map { |client_id| OidcClientRegistry.find!(client_id) }

    assert_equal 12, clients.size
    assert_equal ids, clients.map(&:client_id)
    assert_equal ids.size, clients.map(&:aud).uniq.size
    assert_equal ids.size, clients.map(&:jwt_namespace).uniq.size
    assert_equal ids.size, clients.map { |client| client.redirect_uris.sort }.uniq.size
    clients.each do |client|
      assert_predicate client, :private_key_jwt_client?
      assert_includes %w(client visitor operator), client.resource_type
      assert_predicate client.redirect_uris, :present?
    end

    edit = OidcClientRegistry.find!("edit-org-ww")
    core_org = OidcClientRegistry.find!("core-org-jp")
    warp_org = OidcClientRegistry.find!("warp-org-jp")

    assert_equal "operator", edit.resource_type
    assert_not_equal core_org.redirect_uris, edit.redirect_uris
    assert_not_equal warp_org.redirect_uris, edit.redirect_uris
    assert_not_equal core_org.jwt_namespace, edit.jwt_namespace

    palm = OidcClientRegistry.find!("palm-app-jp")

    assert_equal "client", palm.resource_type
    assert_equal "palm-app-jp", palm.aud
    assert_not_equal core_org.redirect_uris, palm.redirect_uris
    assert_not_equal core_org.jwt_namespace, palm.jwt_namespace

    tech = OidcClientRegistry.find!("tech-org-ww")

    assert_equal "operator", tech.resource_type
    assert_equal "tech-org-ww", tech.aud
    assert_equal OperatorCapabilityGrant::TECH_ACCESS, tech.required_operator_capability
    assert_not_equal edit.redirect_uris, tech.redirect_uris
    assert_not_equal edit.jwt_namespace, tech.jwt_namespace
  end

  test "a first-party RP redirect is rejected for a different registered client" do
    warp = OidcClientRegistry.find!("warp-app-jp")

    assert_raises(OidcClientRegistry::InvalidRedirectUri) do
      OidcAuthorizeRequestResolver.call(
        params: {
          response_type: "code",
          client_id: "core-app-jp",
          redirect_uri: warp.redirect_uris.first,
          code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
          code_challenge_method: "S256",
          state: "state",
          nonce: "nonce",
          scope: "openid profile",
        },
        resource: nil,
        resource_type: "client",
      )
    end
  end
end
