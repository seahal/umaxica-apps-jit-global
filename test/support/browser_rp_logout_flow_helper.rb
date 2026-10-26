# frozen_string_literal: true

require_relative "oidc_rp_logout_hint_helper"

# Exercises the current Visa confirmation and RP-cell receiver path. Callers provide an APP Root
# Session, its actor, a Core RP grant, and the Visa / Core / Warp hosts.
module BrowserRpLogoutFlowHelper
  include OidcRpLogoutHintHelper

  private

  def create_rp_session(client_id, root_token: @root_token)
    client = OidcClientRegistry.find!(client_id)
    grant = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: root_token,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    store_oidc_rp_logout_hint!(grant, grant.client_token.actor_record, client)
    grant
  end

  def sign_out_globally
    host!(@visa_host)
    https!
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = visa_authority_access_token

    get(
      visa_app_oidc_logout_path(ri: "jp"), params: {
        client_id: @core_session.oidc_client_id,
        id_token_hint: @core_session.logout_hint.id_token,
      },
    )

    assert_response :success
    assert_not_predicate @root_token.reload, :revoked?

    post(
      visa_app_oidc_logout_confirmation_path(ri: "jp"), headers: {
        "Origin" => "https://#{@visa_host}",
        "Sec-Fetch-Site" => "same-origin",
      },
    )

    assert_response :see_other
  end

  def create_local_warp_session!(grant)
    client = OidcClientRegistry.find!("warp-app-jp")
    RpCallbackCommitter.call(
      cell: RpCellBinding.fetch("rp_warp_app"),
      issuer: OidcIssuer.for_client(client),
      subject: OidcSubject.for(@user, resource_type: "client"),
      sid: grant.public_id,
      absolute_expires_at: 1.hour.from_now,
    ).session
  end

  def deliver_warp_backchannel_logout!(grant)
    participant = OpAppAuthorityStopParticipant.find_by!(client_id: "warp-app-jp", sid: grant.public_id)
    host!(URI.parse(participant.endpoint_identity).host)
    https!
    post("/oidc/closures", params: { logout_token: OpLogoutTokenIssuer.call(participant: participant) })

    assert_response :ok
  end

  def visa_authority_access_token(root_token: @root_token, user: @user)
    AuthenticationToken.encode(
      user,
      host: @visa_host,
      session_public_id: root_token.device_session_record.public_id,
      oidc_sid: root_token.device_session_record.public_id,
      oidc_jti: root_token.oidc_jti,
      resource_type: "client",
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
      authentication_context: root_token.authentication_context_value.to_s,
    )
  end

  def warp_credentials(rp_session)
    client = OidcClientRegistry.find!("warp-app-jp")
    access = AuthenticationTokenService.encode(
      @user,
      host: @warp_host,
      resource_type: "client",
      session_public_id: @root_token.public_id,
      base_session_public_id: @root_token.public_id,
      oidc_sid: rp_session.public_id,
      oidc_jti: rp_session.oidc_jti,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(client),
      audiences: [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      subject: OidcSubject.for(@user, resource_type: "client"),
      client_id: client.client_id,
    )
    [access, rp_session.issue_refresh_token!]
  end
end
