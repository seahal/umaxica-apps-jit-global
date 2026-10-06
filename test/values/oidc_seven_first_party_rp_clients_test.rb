# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcSevenFirstPartyRpClientsTest < ActiveSupport::TestCase
  setup do
    OidcClientRegistry::CLIENTS_CACHE.set(nil)
  end

  test "registers first-party RPs with unique ids keys and callback paths" do
    AuthBoundaryAuthorityMap.first_party_rp_client_ids.each do |client_id|
      client = OidcClientRegistry.find!(client_id)

      assert_equal client_id, client.client_id
      assert_equal client_id, client.aud
      assert_predicate client, :private_key_jwt_client?
      assert client.redirect_uris.any? { |uri| uri.end_with?("/oidc/callback") },
             "#{client_id} missing /oidc/callback"
      assert client.post_logout_redirect_uris.any? { |uri| uri.end_with?("/sign/out") },
             "#{client_id} missing /sign/out"
      assert_predicate(
        JitSecurityJwtRegistry.private_key_for("oidc_client:#{client.jwt_namespace}"),
        :present?,
        "#{client_id} missing private key for #{client.jwt_namespace}",
      )
    end

    namespaces =
      AuthBoundaryAuthorityMap.first_party_rp_client_ids.map do |client_id|
        OidcClientRegistry.find!(client_id).jwt_namespace
      end

    assert_equal 10, namespaces.uniq.size
    assert_equal(
      %w(CORE_APP CORE_COM CORE_ORG WARP_APP WARP_COM WARP_ORG EDIT_ORG BASE_RP_APP_WW BASE_RP_COM_WW
         BASE_RP_ORG_WW),
      namespaces,
    )
    assert_equal 10, AuthBoundaryAuthorityMap.first_party_rp_client_ids.size
    assert_predicate AuthBoundaryAuthorityMap, :unique_client_ids?
    assert_predicate AuthBoundaryAuthorityMap, :no_overlap_with_deprecated_ids?
  end

  test "retired shared browser client ids are rejected" do
    retired_shared_client_id = ["core", "next-rp"].join("-")

    assert_nil OidcClientRegistry.find(retired_shared_client_id)
    %w(sign-rp base-rails-rp).each do |client_id|
      assert_nil OidcClientRegistry.find(client_id), client_id
    end
  end
end
