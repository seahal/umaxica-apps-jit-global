# frozen_string_literal: true

require "test_helper"

class AcceptanceWu02IssuerConsistencyTest < ActiveSupport::TestCase
  fixtures :clients, :visitors, :operators

  test "A02-4: discovery, ID Token, authorization response and Logout Token agree per realm" do
    realms = [
      ["client", "app", clients(:one), ClientToken, OpAppGrant, OpAppAuthorityStopParticipant, :user, :client_token],
      ["visitor", "com", visitors(:reserved_visitor), VisitorToken, OpComGrant, OpComAuthorityStopParticipant,
       :visitor, :visitor_token,],
      ["operator", "org", operators(:one), OperatorToken, OpOrgGrant, OpOrgAuthorityStopParticipant,
       :staff, :operator_token,],
    ]
    realms.each do |resource_type, realm, actor, root_class, grant_class, participant_class, owner_key, root_key|
      client = OidcClientRegistry.find!("core-#{realm}-jp")
      root = root_class.create!(:authentication_epoch => 0, owner_key => actor)
      grant = grant_class.create!(
        :authentication_epoch => 0, root_key => root, :oidc_client_id => client.client_id,
        :oidc_scope => "openid", :oidc_jti => SecureRandom.uuid, :oidc_nonce => SecureRandom.hex(16),
        :refresh_token_expires_at => 1.hour.from_now,
      )
      issuer = OidcDiscoveryDocument.for_resource_type(resource_type).fetch(:issuer)
      token = OidcIdTokenIssuer.call(resource: actor, client: client, nonce: grant.oidc_nonce, sid: grant.public_id)
      id_result = OidcIdTokenVerifier.call(
        id_token: token, client_id: client.client_id, resource_type: resource_type,
        expected_nonce: grant.oidc_nonce, issuer: issuer,
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
      )

      assert_predicate id_result, :success?, realm
      assert_equal issuer, id_result.payload.fetch("iss"), realm
      callback = OidcAuthorizeCoordinator.error_redirect_url(
        redirect_uri: client.redirect_uris_by_realm.fetch(resource_type).first,
        resource_type: resource_type, error: "access_denied", state: "state",
      )

      assert_equal issuer, Rack::Utils.parse_nested_query(URI.parse(callback).query).fetch("iss"), realm
      success_callback = OidcAuthorizeCoordinator.rp_redirect_url(
        redirect_uri: client.redirect_uris_by_realm.fetch(resource_type).first, resource_type: resource_type,
        response_params: [["code", "test-code"], ["state", "state"]],
      )

      assert_equal issuer, Rack::Utils.parse_nested_query(URI.parse(success_callback).query).fetch("iss"), realm
      OpAuthorityStopCommitter.stop_root(
        root: root, cause: "browser_logout", principal_public_id: actor.public_id, authority_evidence_ref: "a02-4",
      )
      participant = participant_class.find_by!(grant_id: grant.id)
      logout_token = OpLogoutTokenIssuer.call(participant: participant, realm: realm)
      jwks = JitSecurityJwtRegistry.jwks_for(OidcIssuer.jwt_issuer_id_for_resource_type(resource_type)).to_json
      logout_result = OidcOpLogoutTokenVerifier.new(
        logout_token: logout_token, client_id: client.client_id, issuer: issuer,
        jwks_client: OidcOpJwksClient.new(
          jwks_uri: "https://#{realm}.example.test/jwks", fetcher: -> { jwks }, clock: -> { Time.current },
        ),
      ).call

      assert_predicate logout_result, :success?, realm
      assert_equal issuer, logout_result.payload.fetch("iss"), realm
    end
  end
end
