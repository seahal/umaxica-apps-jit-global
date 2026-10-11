# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcSevenFirstPartyRpIsolationTest < ActiveSupport::TestCase
  test "seven first-party browser RPs have isolated client, audience, keys, and redirects" do
    ids = AuthBoundaryAuthorityMap.first_party_rp_client_ids
    clients = ids.map { |client_id| OidcClientRegistry.find!(client_id) }

    assert_equal 7, clients.size
    assert_equal ids, clients.map(&:client_id)
    assert_equal ids.size, clients.map(&:aud).uniq.size
    assert_equal ids.size, clients.map(&:jwt_namespace).uniq.size
    assert_equal ids.size, clients.map { |client| client.redirect_uris.sort }.uniq.size
    clients.each do |client|
      assert_predicate client, :private_key_jwt_client?
      assert_includes %w(client visitor operator), client.resource_type
      assert_predicate client.redirect_uris, :present?
    end

    edit = OidcClientRegistry.find!("edit-org")
    core_org = OidcClientRegistry.find!("core-org")
    side_org = OidcClientRegistry.find!("side-org")

    assert_equal "operator", edit.resource_type
    assert_not_equal core_org.redirect_uris, edit.redirect_uris
    assert_not_equal side_org.redirect_uris, edit.redirect_uris
    assert_not_equal core_org.jwt_namespace, edit.jwt_namespace
  end

  test "a first-party RP redirect is rejected for a different registered client" do
    side = OidcClientRegistry.find!("side-app")

    assert_raises(OidcClientRegistry::InvalidRedirectUri) do
      OidcAuthorizeRequestResolver.call(
        params: {
          response_type: "code",
          client_id: "core-app",
          redirect_uri: side.redirect_uris.first,
          code_challenge: "challenge",
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
