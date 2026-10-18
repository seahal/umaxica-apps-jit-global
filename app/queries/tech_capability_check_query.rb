# typed: false
# frozen_string_literal: true

# OP-side Tech capability decision (R5-WU11, one.md sections 4.2/6.4).
#
# The Tech RP proves itself with a private_key_jwt assertion bound to this exact endpoint and
# presents the Operator's current Access JWT. The decision is made here, by the org authority, from
# writer-current state only: the Access JWT must authenticate for the Tech client, its sid must be a
# live Tech grant, and the real Operator must hold tech.access right now. Every failure denies; no
# result is cached, so a check that starts after a revoke commit denies.
class TechCapabilityCheckQuery
  CLIENT_ID = "tech-org-ww"

  class << self
    public

    # Returns true only for an explicit, current allow.
    def call(access_token:, client_assertion:, endpoint_uri:, host:)
      return false unless OidcClientRegistry.authenticate_assertion(
        CLIENT_ID, client_assertion,
        token_url: endpoint_uri,
      )

      auth = OidcAccessTokenAuthenticator.call(
        access_token:, resource_type: "operator", host:, authorization_scheme: "Bearer",
      )
      return false unless auth.success? && auth.payload["client_id"] == CLIENT_ID
      return false unless live_tech_grant?(auth.payload["sid"])

      TechAccessPolicy.new(auth.resource, user: auth.resource).apply(:show?)
    rescue ActiveRecord::ActiveRecordError
      false
    end

    private

    def live_tech_grant?(sid)
      return false if sid.blank?

      OpBaseOrgRecord.connected_to(role: :writing) do
        grant = OpOrgGrant.find_by(public_id: sid, oidc_client_id: CLIENT_ID)
        grant.present? && grant.active?
      end
    end
  end
end
