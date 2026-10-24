# frozen_string_literal: true

# Builds the same server-side end-session hint that an OIDC callback stores for a first-party RP.
module OidcRpLogoutHintHelper
  private

  def store_oidc_rp_logout_hint!(grant, resource, client)
    hint_class =
      case grant
      when OpAppGrant then OpAppGrantLogoutHint
      when OpComGrant then OpComGrantLogoutHint
      when OpOrgGrant then OpOrgGrantLogoutHint
      else raise ArgumentError, "unsupported RP grant: #{grant.class.name}"
      end
    resource_type = OidcIssuer.resource_type_for_client(client)
    hint_class.create!(
      grant:,
      id_token: OidcIdTokenIssuer.call(
        resource:, client:, nonce: grant.oidc_nonce, issued_at: Time.current,
        expires_at: 10.minutes.from_now,
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
        issuer: OidcIssuer.for_resource_type(resource_type),
        subject: OidcSubject.for(resource, resource_type:), sid: grant.public_id,
        auth_time: grant.oidc_auth_time,
      ),
    )
  end

  def assert_visa_end_session_redirect(query, location, client_id:, region:)
    client = OidcClientRegistry.find!(client_id)
    expected_redirect_uri =
      client.post_logout_redirect_uris.find do |uri|
        Rack::Utils.parse_nested_query(URI.parse(uri).query.to_s)["ri"] == region.to_s
      end

    assert_equal OidcIssuer.host_for_client(client), location.host
    assert_equal "/oidc/logout", location.path
    assert_equal client_id, query.fetch("client_id")
    assert_predicate query["id_token_hint"], :present?
    assert_predicate query["state"], :present?
    assert_equal expected_redirect_uri, query.fetch("post_logout_redirect_uri")
    assert_nil query["logout_challenge"]
  end
end
