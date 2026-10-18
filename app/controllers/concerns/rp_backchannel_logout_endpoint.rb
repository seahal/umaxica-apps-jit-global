# typed: false
# frozen_string_literal: true

# POST /oidc/backchannel-logout on one RP cell (R5-WU10, one.md sections 6.4/7.6).
#
# Server-to-server: no browser session, cookie or CSRF token takes part; authenticity is the OP's
# signature on the Logout Token, checked against the realm OP's public JWKS from fixed
# configuration. 200 is returned only after the cell commit (receipt + tombstone + session
# revocation); a duplicate committed event is also 200; a persistence failure is a retryable 503.
module RpBackchannelLogoutEndpoint
  extend ActiveSupport::Concern

  public

  def create
    cell = RpCellBinding.fetch(self.class.const_get(:RP_CELL_CONNECTION, false))
    resource_type = { "app" => "client", "com" => "visitor", "org" => "operator" }.fetch(cell.realm)
    issuer = OidcIssuer.for_resource_type(resource_type)
    verification = OidcOpLogoutTokenVerifier.new(
      logout_token: params[:logout_token].to_s, client_id: cell.client_id, issuer:,
      jwks_client: OidcOpJwksClient.new(jwks_uri: "#{issuer}/.well-known/jwks.json"),
    ).call
    response.headers["Cache-Control"] = "no-store"
    return head(:bad_request) unless verification.success?

    RpCellSessionRevoker.call(cell:, payload: verification.payload)
    head :ok
  rescue ActiveRecord::ActiveRecordError
    head :service_unavailable
  end
end
