# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcClientRegistryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "find returns a first-party client config as visitor account" do
    client = OidcClientRegistry.find("core-app-jp")

    assert_not_nil client
    assert_equal "core-app-jp", client.client_id
    assert_equal "core-app-jp", client.aud
    assert client.redirect_uris.any? { |uri| uri.end_with?("/oidc/callback") }
  end

  test "each first-party RP registers a callback on its own surface" do
    AuthBoundaryAuthorityMap.first_party_rp_client_ids.each do |client_id|
      client = OidcClientRegistry.find!(client_id)

      assert client.redirect_uris.any? { |uri| uri.end_with?("/oidc/callback") },
             "#{client_id} has no registered canonical callback"
      assert_equal [client.resource_type], client.redirect_uris_by_realm.keys
    end
  end

  test "each first-party RP registers only the noun completion path" do
    AuthBoundaryAuthorityMap.first_party_rp_client_ids.each do |client_id|
      client = OidcClientRegistry.find!(client_id)
      registered_paths = client.post_logout_redirect_uris.map { |uri| URI.parse(uri).path }.uniq

      assert_equal ["/sign/out/completion"], registered_paths, client_id

      client.post_logout_redirect_uris.each do |registered_uri|
        legacy_uri = URI.parse(registered_uri)
        legacy_uri.path = "/sign/out"

        assert_not OidcClientRegistry.valid_post_logout_redirect_uri?(
          client_id: client_id,
          uri: legacy_uri.to_s,
          resource_type: client.resource_type,
        ), "#{client_id} accepts the retired /sign/out return URI"
      end
    end
  end

  test "find returns nil for unknown client" do
    client = OidcClientRegistry.find("unknown-client")

    assert_nil client
  end

  test "find! raises for unknown client" do
    assert_raises(OidcClientRegistry::ClientNotFound) do
      OidcClientRegistry.find!("unknown-client")
    end
  end

  private
end
