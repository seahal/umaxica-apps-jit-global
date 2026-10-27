# frozen_string_literal: true

require "test_helper"

# End to end: the OP commits a logout, signs a Logout Token for the participant, and the RP cell's
# back-channel endpoint verifies it against the OP's published JWKS and tombstones the sid.
class RpBackchannelLogoutReceiverTest < ActionDispatch::IntegrationTest
  fixtures :clients

  setup do
    https!
    host! URI.parse(ENV.fetch("PUBLIC_CORE_SERVICE_URL")).host || ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    root = ClientToken.create!(authentication_epoch: 0, user: clients(:one))
    @grant = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: root, client_device_session: root.device_session, device_session_id: root.device_session_id,
      oidc_client_id: "core-app-jp", oidc_scope: "openid", oidc_jti: SecureRandom.uuid, last_used_at: Time.current,
      refresh_token_expires_at: 1.day.from_now,
    )
    OpAuthorityStopCommitter.stop_root(
      root:, cause: "browser_logout", principal_public_id: clients(:one).public_id, authority_evidence_ref: "test",
    )
    @participant = OpAppAuthorityStopParticipant.sole
    @local = RpCallbackCommitter.call(
      cell: RpCellBinding.fetch("rp_core_app"), issuer: @participant.issuer, subject: "subject-a",
      sid: @participant.sid, absolute_expires_at: 1.hour.from_now,
    ).session
  end

  test "a signed OP Logout Token tombstones the sid and revokes the local session, then answers 200" do
    post "/oidc/closures", params: { logout_token: OpLogoutTokenIssuer.call(participant: @participant) }

    assert_response :ok
    assert_not_nil RpCoreAppOpSessionBinding.find_by!(sid: @grant.public_id).revoked_at
    assert_not_nil @local.reload.revoked_at
  end

  test "a valid browserless logout without cookies or User-Agent ends its named local session" do
    post "/oidc/closures", params: { logout_token: OpLogoutTokenIssuer.call(participant: @participant) },
                           headers: { "HTTP_USER_AGENT" => nil, "HTTP_COOKIE" => nil }

    assert_nil request.get_header("HTTP_USER_AGENT")
    assert_empty request.cookies
    assert_response :ok
    assert_not_nil @local.reload.revoked_at
    assert_not_nil RpCoreAppOpSessionBinding.find_by!(sid: @participant.sid).revoked_at
    assert_equal 1, RpCoreAppEventReceipt.count
  end

  test "a delayed logout for an old sid leaves a newer sign-in session active" do
    newer_session = RpCallbackCommitter.call(
      cell: RpCellBinding.fetch("rp_core_app"), issuer: @participant.issuer, subject: "subject-a",
      sid: "newer-sid", absolute_expires_at: 1.hour.from_now,
    ).session

    post "/oidc/closures", params: { logout_token: OpLogoutTokenIssuer.call(participant: @participant) }

    assert_response :ok
    assert_not_nil @local.reload.revoked_at
    assert_predicate newer_session.reload, :active?
    assert_nil RpCoreAppOpSessionBinding.find_by!(sid: "newer-sid").revoked_at
  end

  test "a logout that arrives before callback enrollment leaves a tombstone for that sid" do
    other_root = ClientToken.create!(authentication_epoch: 0, user: clients(:one))
    other_grant = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: other_root, client_device_session: other_root.device_session,
      device_session_id: other_root.device_session_id,
      oidc_client_id: "core-app-jp", oidc_scope: "openid", oidc_jti: SecureRandom.uuid,
      last_used_at: Time.current, refresh_token_expires_at: 1.day.from_now,
    )
    OpAuthorityStopCommitter.stop_root(
      root: other_root, cause: "browser_logout", principal_public_id: clients(:one).public_id,
      authority_evidence_ref: "callback-race",
    )
    participant = OpAppAuthorityStopParticipant.find_by!(grant_id: other_grant.id)

    post "/oidc/closures", params: { logout_token: OpLogoutTokenIssuer.call(participant: participant) }
    late_callback = RpCallbackCommitter.call(
      cell: RpCellBinding.fetch("rp_core_app"), issuer: participant.issuer, subject: "late-subject",
      sid: participant.sid, absolute_expires_at: 1.hour.from_now,
    )

    assert_response :ok
    assert_equal :revoked, late_callback.outcome
    binding = RpCoreAppOpSessionBinding.find_by!(sid: participant.sid)

    assert_not_nil binding.revoked_at
    assert_nil binding.identity_binding_id
  end

  test "a redelivered token for a committed event still answers 200" do
    token = OpLogoutTokenIssuer.call(participant: @participant)
    2.times do
      post "/oidc/closures", params: { logout_token: token }

      assert_response :ok
    end
    assert_equal 1, RpCoreAppEventReceipt.count
  end

  test "nonce missing or wrong events and absent sid and sub are refused without session changes" do
    original = JWT.decode(OpLogoutTokenIssuer.call(participant: @participant), nil, false).first
    invalid = [
      original.merge("nonce" => "unexpected"),
      original.except("events"),
      original.merge("events" => { "wrong-event" => {} }),
      original.except("sid", "sub"),
    ]
    invalid.each do |claims|
      token = JitSecurityJwtKeyring.encode(
        claims, typ: OpLogoutTokenIssuer::TOKEN_TYPE,
                issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
      )
      post "/oidc/closures", params: { logout_token: token }

      assert_response :bad_request
      assert_nil @local.reload.revoked_at
      assert_nil RpCoreAppOpSessionBinding.find_by!(sid: @grant.public_id).revoked_at
      assert_equal 0, RpCoreAppEventReceipt.count
    end
  end

  test "an unsigned or foreign-audience token is refused with 400 and changes nothing" do
    post "/oidc/closures", params: { logout_token: "not-a-jwt" }

    assert_response :bad_request
    @participant.update_columns(client_id: "warp-app-jp")
    post "/oidc/closures", params: { logout_token: OpLogoutTokenIssuer.call(participant: @participant) }

    assert_response :bad_request
    assert_nil @local.reload.revoked_at
  end
end
