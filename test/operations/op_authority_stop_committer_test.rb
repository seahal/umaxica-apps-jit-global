# frozen_string_literal: true

require "test_helper"

# WU-16 (two.md 5.8 v2, D-119, D-123, D-172, D-173): the one OP authority-stop primitive.
class OpAuthorityStopCommitterTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  fixtures :clients

  setup do
    @client = clients(:one)
    @root = ClientToken.create!(authentication_epoch: 0, user: @client)
    @grants =
      %w(core-app-jp warp-app-jp).map do |client_id|
        OpAppGrant.create!(
          authentication_epoch: 0,
          client_token: @root, client_device_session: @root.device_session, device_session_id: @root.device_session_id,
          oidc_client_id: client_id, oidc_scope: "openid", oidc_jti: SecureRandom.uuid, last_used_at: Time.current,
          refresh_token_expires_at: 1.day.from_now,
        )
      end
  end

  test "a root stop revokes the root and every grant and records targets, participants and the receipt" do
    result = OpAuthorityStopCommitter.stop_root(
      root: @root, cause: "browser_logout", principal_public_id: @client.public_id,
      authority_evidence_ref: "test", browser_binding: "browser-1",
    )
    stop = result.stop

    assert_not_predicate result, :replayed?
    assert_predicate @root.reload, :revoked?
    @grants.each { |grant| assert_not_nil grant.reload.revoked_at }
    assert_equal %w(browser_logout root), [stop.cause_name, OpAuthorityStopReference::SCOPES.key(stop.scope_id)]
    assert_equal [@client.public_id, "app"], [stop.principal_public_id, stop.realm]
    assert_equal [@root.id], OpAppAuthorityStopRootTarget.where(stop_id: stop.id).map(&:root_id)
    assert_equal @grants.map(&:id).sort, OpAppAuthorityStopGrantTarget.where(stop_id: stop.id).map(&:grant_id).sort
    participants = OpAppAuthorityStopParticipant.where(stop_id: stop.id).order(:client_id)

    assert_equal %w(core-app-jp warp-app-jp), participants.map(&:client_id)
    assert_equal @grants.map(&:public_id).sort, participants.map(&:sid).sort
    participants.each do |participant|
      assert_equal OpAuthorityStopReference.participant_status_id("pending"), participant.status_id
      assert_equal OidcClientStoresStaticClientStore.backchannel_logout_uri(participant.client_id),
                   participant.endpoint_identity
      assert_operator participant.deadline_at, :>, participant.next_attempt_at
    end
    assert_equal Digest::SHA256.digest(result.receipt_nonce),
                 OpAppAuthorityStopBrowserLogout.find_by!(stop_id: stop.id).receipt_nonce_digest
    assert_not OpAppAuthorityStopEpochCutoff.exists?(stop_id: stop.id)
  end

  test "the stop enqueues delivery after its commit" do
    assert_enqueued_with(job: OpOutboxDispatchJob) do
      OpAuthorityStopCommitter.stop_root(
        root: @root, cause: "browser_logout", principal_public_id: @client.public_id,
        authority_evidence_ref: "test",
      )
    end
  end

  test "a re-run of the same stop returns the stored stop and writes nothing again" do
    first = OpAuthorityStopCommitter.stop_root(
      root: @root, cause: "browser_logout", principal_public_id: @client.public_id,
      authority_evidence_ref: "test",
    )
    second = OpAuthorityStopCommitter.stop_root(
      root: @root, cause: "browser_logout", principal_public_id: @client.public_id,
      authority_evidence_ref: "test",
    )

    assert_predicate second, :replayed?
    assert_equal first.stop.id, second.stop.id
    assert_nil second.receipt_nonce
    assert_equal 1, OpAppAuthorityStop.count
    assert_equal 2, OpAppAuthorityStopParticipant.count
  end

  test "an already revoked root is not stopped again" do
    OpAuthorityStopCommitter.stop_root(
      root: @root, cause: "browser_logout", principal_public_id: @client.public_id,
      authority_evidence_ref: "test",
    )
    other = OpAuthorityStopCommitter.stop_grant(
      grant: @grants.first, cause: "token_revocation", principal_public_id: @client.public_id,
      authority_evidence_ref: "test",
    )

    assert_not_predicate other, :stopped?
    assert_equal 1, OpAppAuthorityStop.count
  end

  test "a grant stop ends only that grant and keeps the root and sibling grants" do
    result = OpAuthorityStopCommitter.stop_grant(
      grant: @grants.first, cause: "refresh_reuse", principal_public_id: @client.public_id,
      authority_evidence_ref: "test",
    )

    assert_equal "refresh_reuse", result.stop.cause_name
    assert_not_nil @grants.first.reload.revoked_at
    assert_nil @grants.last.reload.revoked_at
    assert_not_predicate @root.reload, :revoked?
    assert_equal [@grants.first.id], OpAppAuthorityStopGrantTarget.where(stop_id: result.stop.id).map(&:grant_id)
    assert_empty OpAppAuthorityStopRootTarget.where(stop_id: result.stop.id)
    assert_equal 1, OpAppAuthorityStopParticipant.where(stop_id: result.stop.id).count
  end

  test "a principal stop records its cutoff and every revoked root; zero roots is a recorded stop" do
    second_root = ClientToken.create!(authentication_epoch: 0, user: @client)
    result = OpAuthorityStopCommitter.stop_principal(
      realm: "app", roots: [@root, second_root], cause: "identity_stop", principal_public_id: @client.public_id,
      authority_evidence_ref: "event-1", cutoff_epoch: 1,
    )

    assert_equal [@root.id, second_root.id].sort,
                 OpAppAuthorityStopRootTarget.where(stop_id: result.stop.id).map(&:root_id).sort
    assert_equal 1, OpAppAuthorityStopEpochCutoff.find_by!(stop_id: result.stop.id).cutoff_epoch
    empty = OpAuthorityStopCommitter.stop_principal(
      realm: "app", roots: [], cause: "administrative", principal_public_id: @client.public_id,
      authority_evidence_ref: "event-2", cutoff_epoch: 2,
    )

    assert_predicate empty, :stopped?
    assert_empty OpAppAuthorityStopRootTarget.where(stop_id: empty.stop.id)
  end

  test "a stop without an established principal or evidence is refused before any write" do
    assert_raises(OpAuthorityStopCommitter::Refused) do
      OpAuthorityStopCommitter.stop_root(
        root: @root, cause: "browser_logout", principal_public_id: "", authority_evidence_ref: "test",
      )
    end
    assert_raises(OpAuthorityStopCommitter::Refused) do
      OpAuthorityStopCommitter.stop_root(
        root: @root, cause: "browser_logout", principal_public_id: @client.public_id, authority_evidence_ref: "",
      )
    end
    assert_raises(OpAuthorityStopCommitter::Refused) do
      OpAuthorityStopCommitter.stop_root(
        root: @root, cause: "browser_logout", principal_public_id: @client.public_id,
        authority_evidence_ref: "x" * 129,
      )
    end
    assert_raises(KeyError) do
      OpAuthorityStopCommitter.stop_root(
        root: @root, cause: "session_limit", principal_public_id: @client.public_id,
        authority_evidence_ref: "test",
      )
    end
    assert_not_predicate @root.reload, :revoked?
    assert_equal 0, OpAppAuthorityStop.count
  end

  test "cause and scope must match the accepted authority-stop matrix" do
    assert_raises(ArgumentError) do
      OpAuthorityStopCommitter.stop_root(
        root: @root, cause: "refresh_reuse", principal_public_id: @client.public_id,
        authority_evidence_ref: "test",
      )
    end
    assert_raises(ArgumentError) do
      OpAuthorityStopCommitter.stop_grant(
        grant: @grants.first, cause: "browser_logout", principal_public_id: @client.public_id,
        authority_evidence_ref: "test",
      )
    end
    assert_raises(ArgumentError) do
      OpAuthorityStopCommitter.stop_principal(
        realm: "app", roots: [], cause: "browser_logout", principal_public_id: @client.public_id,
        authority_evidence_ref: "test", cutoff_epoch: 1,
      )
    end
    assert_raises(ArgumentError) do
      OpAuthorityStopCommitter.stop_principal(
        realm: "app", roots: [], cause: "identity_stop", principal_public_id: @client.public_id,
        authority_evidence_ref: "test", cutoff_epoch: 0,
      )
    end

    assert_not_predicate @root.reload, :revoked?
    assert_equal 0, OpAppAuthorityStop.count
  end

  test "only a browser logout carries a browser binding" do
    assert_raises(ArgumentError) do
      OpAuthorityStopCommitter.stop_root(
        root: @root, cause: "revoke_others", principal_public_id: @client.public_id,
        authority_evidence_ref: "test", browser_binding: "browser-1",
      )
    end
    assert_raises(OpAuthorityStopCommitter::Refused) do
      OpAuthorityStopCommitter.stop_root(
        root: @root, cause: "browser_logout", principal_public_id: @client.public_id,
        authority_evidence_ref: "test", browser_binding: " ",
      )
    end
  end
end
