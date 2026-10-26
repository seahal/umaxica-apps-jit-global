# frozen_string_literal: true

require "test_helper"

# D-172 S-2: stop records go with their roots, children first, never before every participant is final.
class OpAuthorityStopPurgerTest < ActiveSupport::TestCase
  fixtures :clients

  setup do
    @client = clients(:one)
    @root = ClientToken.create!(authentication_epoch: 0, user: @client)
    @grant = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: @root, client_device_session: @root.device_session, device_session_id: @root.device_session_id,
      oidc_client_id: "core-app-jp", oidc_scope: "openid", oidc_jti: SecureRandom.uuid, last_used_at: Time.current,
      refresh_token_expires_at: 1.day.from_now,
    )
    @stop = OpAuthorityStopCommitter.stop_root(
      root: @root, cause: "browser_logout", principal_public_id: @client.public_id, authority_evidence_ref: "test",
      browser_binding: "browser-1",
    ).stop
  end

  test "a stop with a pending participant holds its root" do
    assert_equal [@root.id], OpAuthorityStopPurger.release_roots!(realm: "app", root_ids: [@root.id])
    assert OpAppAuthorityStop.exists?(@stop.id)
  end

  test "a stop whose participants are final is deleted with its children and releases the root" do
    @root.reload.update_columns(purge_eligible_at: @root.discard_at)
    OpAppAuthorityStopParticipant.where(stop_id: @stop.id).find_each do |participant|
      participant.record_delivery_result!(outcome: :acknowledged)
    end

    assert_equal [OpAuthorityStopReference.participant_status_id("acknowledged")],
                 OpAppAuthorityStopParticipant.where(stop_id: @stop.id).pluck(:status_id).uniq
    assert_operator ClientToken.database_now, :>=, @root.purge_eligible_at

    assert_empty OpAuthorityStopPurger.release_roots!(realm: "app", root_ids: [@root.id])
    assert_not OpAppAuthorityStop.exists?(@stop.id)
    assert_not OpAppAuthorityStopRootTarget.exists?(stop_id: @stop.id)
    assert_not OpAppAuthorityStopBrowserLogout.exists?(stop_id: @stop.id)
  end

  test "an all-roots stop stays until every target root reaches its own retention deadline" do
    first_root = ClientToken.create!(authentication_epoch: 0, user: @client)
    second_root = ClientToken.create!(authentication_epoch: 0, user: @client)
    first_grant = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: first_root, client_device_session: first_root.device_session,
      device_session_id: first_root.device_session_id,
      oidc_client_id: "core-app-jp", oidc_scope: "openid", oidc_jti: SecureRandom.uuid,
      last_used_at: Time.current, refresh_token_expires_at: 1.day.from_now,
    )
    second_grant = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: second_root, client_device_session: second_root.device_session,
      device_session_id: second_root.device_session_id, oidc_client_id: "warp-app-jp", oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, last_used_at: Time.current, refresh_token_expires_at: 1.day.from_now,
    )
    stop = OpAuthorityStopCommitter.stop_principal(
      realm: "app", roots: [first_root, second_root], cause: "identity_stop",
      principal_public_id: @client.public_id, authority_evidence_ref: "multi-root", cutoff_epoch: 1,
    ).stop
    first_root.reload.update_columns(purge_eligible_at: first_root.discard_at)
    second_root.reload.update_columns(purge_eligible_at: second_root.discard_at + 1.hour)
    OpAppAuthorityStopParticipant.where(stop_id: stop.id).find_each do |participant|
      participant.record_delivery_result!(outcome: :acknowledged)
    end

    assert_equal [OpAuthorityStopReference.participant_status_id("acknowledged")],
                 OpAppAuthorityStopParticipant.where(stop_id: stop.id).pluck(:status_id).uniq
    assert_operator ClientToken.database_now, :>=, first_root.purge_eligible_at
    assert_operator second_root.purge_eligible_at, :>, ClientToken.database_now

    assert_equal [first_root.id], OpAuthorityStopPurger.release_roots!(realm: "app", root_ids: [first_root.id])
    assert OpAppAuthorityStop.exists?(stop.id)

    second_root.reload.update_columns(purge_eligible_at: second_root.discard_at)

    assert_operator ClientToken.database_now, :>=, second_root.purge_eligible_at

    assert_empty OpAuthorityStopPurger.release_roots!(realm: "app", root_ids: [first_root.id])
    assert_not OpAppAuthorityStop.exists?(stop.id)
    assert_not OpAppAuthorityStopGrantTarget.exists?(stop_id: stop.id, grant_id: first_grant.id)
    assert_not OpAppAuthorityStopGrantTarget.exists?(stop_id: stop.id, grant_id: second_grant.id)
  end

  test "no root ids release nothing" do
    assert_empty OpAuthorityStopPurger.release_roots!(realm: "app", root_ids: [])
    assert OpAppAuthorityStop.exists?(@stop.id)
  end
end
