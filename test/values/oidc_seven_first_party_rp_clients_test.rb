# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcSevenFirstPartyRpClientsTest < ActiveSupport::TestCase
  setup do
    OidcClientRegistry::CLIENTS_CACHE.set(nil)
  end

  test "registers seven first-party RPs with unique ids keys and callback paths" do
    AuthBoundaryAuthorityMap.first_party_rp_client_ids.each do |client_id|
      client = OidcClientRegistry.find!(client_id)

      assert_equal client_id, client.client_id
      assert_equal client_id, client.aud
      assert_predicate client, :private_key_jwt_client?
      assert client.redirect_uris.any? { |uri| uri.end_with?("/sign/callback") },
             "#{client_id} missing /sign/callback"
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

    assert_equal 7, namespaces.uniq.size
    assert_equal(
      %w(CORE_APP CORE_COM CORE_ORG SIDE_APP SIDE_COM SIDE_ORG EDIT_ORG),
      namespaces,
    )
    assert_equal 7, AuthBoundaryAuthorityMap.first_party_rp_client_ids.size
    assert_predicate AuthBoundaryAuthorityMap, :unique_client_ids?
    assert_predicate AuthBoundaryAuthorityMap, :no_overlap_with_deprecated_ids?
  end

  test "only the explicitly retained core-next migration client remains findable" do
    assert_predicate OidcClientRegistry.find("core-next-rp"), :present?
    %w(sign-rp base-rails-rp side-rails-rp).each do |client_id|
      assert_nil OidcClientRegistry.find(client_id), client_id
    end
  end
end
