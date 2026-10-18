# frozen_string_literal: true

require "test_helper"

class OpLogoutCommitterTest < ActiveSupport::TestCase
  fixtures :clients

  setup do
    @client = clients(:one)
    @root = ClientToken.create!(user: @client)
    @grants =
      %w(core-app-jp warp-app-jp).map do |client_id|
        OpAppGrant.create!(
          client_token: @root, client_device_session: @root.device_session, device_session_id: @root.device_session_id,
          oidc_client_id: client_id, oidc_scope: "openid", oidc_jti: SecureRandom.uuid, last_used_at: Time.current,
          refresh_token_expires_at: 1.day.from_now,
        )
      end
  end

  test "one OP commit revokes the root and every grant and records flow, participants, receipt and outbox" do
    result = commit

    assert_not_predicate result, :replayed?
    assert_predicate @root.reload, :revoked?
    @grants.each { |grant| assert_not_nil grant.reload.revoked_at }
    flow = result.flow

    assert_equal [@root.public_id, "app"], [flow.target_root_ref, flow.realm]
    assert_not_nil flow.op_revoked_at
    participants = OpAppLogoutFlowParticipant.where(logout_flow_id: flow.id).order(:client_id)

    assert_equal %w(core-app-jp warp-app-jp), participants.map(&:client_id)
    assert_equal @grants.map(&:public_id).sort, participants.map(&:sid).sort
    participants.each do |participant|
      assert_equal OidcClientStoresStaticClientStore.backchannel_logout_uri(participant.client_id),
                   participant.endpoint_identity
    end
    assert_equal 2, OpAppOutboxEvent.where(logout_flow_participant_id: participants.map(&:id)).count
    receipt = OpAppLogoutReceipt.find_by!(logout_flow_id: flow.id)

    assert_equal Digest::SHA256.digest(result.receipt_nonce), receipt.nonce_digest
  end

  test "a retry with the same idempotency key rereads the committed outcome" do
    first = commit
    second = commit

    assert_predicate second, :replayed?
    assert_equal first.flow.id, second.flow.id
    assert_nil second.receipt_nonce
    assert_equal 1, OpAppLogoutFlow.count
  end

  test "logout is established without any RP acknowledgement" do
    result = commit

    assert_equal 0,
                 OpAppLogoutFlowParticipant.where(logout_flow_id: result.flow.id).where.not(acknowledged_at: nil).count
    assert_predicate @root.reload, :revoked?
  end

  test "blank idempotency or browser binding is refused before any write" do
    assert_raises(ArgumentError) { commit(idempotency_key: "") }
    assert_raises(ArgumentError) { commit(browser_binding: "") }
    assert_not_predicate @root.reload, :revoked?
  end

  private

  def commit(idempotency_key: "logout-1", browser_binding: "browser-1")
    OpLogoutCommitter.call(
      realm: "app", root_token: @root, idempotency_key:, browser_binding:, audit_ref: "audit-1",
    )
  end
end
