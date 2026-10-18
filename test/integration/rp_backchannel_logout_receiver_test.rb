# frozen_string_literal: true

require "test_helper"

# End to end: the OP commits a logout, signs a Logout Token for the participant, and the RP cell's
# back-channel endpoint verifies it against the OP's published JWKS and tombstones the sid.
class RpBackchannelLogoutReceiverTest < ActionDispatch::IntegrationTest
  fixtures :clients

  setup do
    https!
    host! URI.parse(ENV.fetch("PUBLIC_CORE_SERVICE_URL")).host || ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    root = ClientToken.create!(user: clients(:one))
    @grant = OpAppGrant.create!(
      client_token: root, client_device_session: root.device_session, device_session_id: root.device_session_id,
      oidc_client_id: "core-app-jp", oidc_scope: "openid", oidc_jti: SecureRandom.uuid, last_used_at: Time.current,
      refresh_token_expires_at: 1.day.from_now,
    )
    OpLogoutCommitter.call(realm: "app", root_token: root, idempotency_key: "k", browser_binding: "b", audit_ref: "a")
    @participant = OpAppLogoutFlowParticipant.sole
    @local = RpCallbackCommitter.call(
      cell: RpCellBinding.fetch("rp_core_app"), issuer: @participant.issuer, subject: "subject-a",
      sid: @participant.sid, absolute_expires_at: 1.hour.from_now, contract_epoch: 1,
    ).session
  end

  test "a signed OP Logout Token tombstones the sid and revokes the local session, then answers 200" do
    post "/oidc/backchannel-logout", params: { logout_token: OpLogoutTokenIssuer.call(participant: @participant) }

    assert_response :ok
    assert_not_nil RpCoreAppOpSessionBinding.find_by!(sid: @grant.public_id).revoked_at
    assert_not_nil @local.reload.revoked_at
  end

  test "a redelivered token for a committed event still answers 200" do
    token = OpLogoutTokenIssuer.call(participant: @participant)
    2.times do
      post "/oidc/backchannel-logout", params: { logout_token: token }

      assert_response :ok
    end
    assert_equal 1, RpCoreAppEventReceipt.count
  end

  test "an unsigned or foreign-audience token is refused with 400 and changes nothing" do
    post "/oidc/backchannel-logout", params: { logout_token: "not-a-jwt" }

    assert_response :bad_request
    @participant.update_columns(client_id: "warp-app-jp")
    post "/oidc/backchannel-logout", params: { logout_token: OpLogoutTokenIssuer.call(participant: @participant) }

    assert_response :bad_request
    assert_nil @local.reload.revoked_at
  end
end
