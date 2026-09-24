# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcClientRegistryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "find returns a first-party client config as visitor account" do
    client = OidcClientRegistry.find("core-app")

    assert_not_nil client
    assert_equal "core-app", client.client_id
    assert_equal "core-app", client.aud
    assert client.redirect_uris.any? { |uri| uri.end_with?("/sign/callback") }
  end

  test "each first-party RP registers a callback on its own surface" do
    AuthBoundaryAuthorityMap.first_party_rp_client_ids.each do |client_id|
      client = OidcClientRegistry.find!(client_id)

      assert client.redirect_uris.any? { |uri| uri.end_with?("/sign/callback") },
             "#{client_id} has no registered canonical callback"
      assert_equal [client.resource_type], client.redirect_uris_by_realm.keys
    end
  end

  test "each first-party RP registers a canonical post logout URI" do
    AuthBoundaryAuthorityMap.first_party_rp_client_ids.each do |client_id|
      client = OidcClientRegistry.find!(client_id)

      assert client.post_logout_redirect_uris.any? { |uri| uri.end_with?("/sign/out") },
             "#{client_id} has no registered canonical post logout URI"
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
