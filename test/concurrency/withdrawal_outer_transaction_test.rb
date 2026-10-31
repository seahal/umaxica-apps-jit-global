# frozen_string_literal: true

require "test_helper"
require "timeout"

class WithdrawalOuterTransactionTest < ActiveSupport::TestCase
  include AuthorityStopCleanup

  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "withdrawal start records its start time after waiting for the actor lock" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    occurrences = ClientOccurrence.where(event_type: "withdrawal.requested")
      .where("context ->> 'subject_public_id' = ?", actor.public_id)
    ready = Queue.new
    worker = nil
    observed_at = nil

    Client.transaction do
      actor.lock!
      worker =
        Thread.new do
          Client.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
            ready << connection.select_value("SELECT pg_backend_pid()").to_i
            WithdrawalLifecycle.start!(actor: Client.find(actor.id))
          end
        end
      pid = Timeout.timeout(10) { ready.pop }
      Timeout.timeout(10) do
        loop do
          blocked =
            Client.uncached do
              Client.lease_connection.select_value("SELECT cardinality(pg_blocking_pids(#{Integer(pid)})) > 0")
            end
          break if blocked

          Thread.pass
        end
      end
      observed_at = Client.database_now
    end

    Timeout.timeout(10) { worker.value }
    flow = ClientWithdrawalFlow.find_by!(client_id: actor.id)

    assert_operator flow.began_at, :>=, observed_at
  ensure
    worker&.join(10)
    occurrences&.delete_all
    ClientWithdrawalFlow.where(client_id: actor.id).destroy_all if actor
    actor&.delete
  end

  %i(commit rollback).product(%i(joined savepoint)).each do |outcome, nesting|
    test "withdrawal recovery inside #{nesting} waits for outer #{outcome}" do
      past = Client.database_now - 2.days
      actor = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
        withdrawal_started_at: past, deactivated_at: past, discard_at: past, purge_eligible_at: 29.days.from_now,
      )
      flow = ClientWithdrawalFlow.create!(
        client: actor, status_id: ClientWithdrawalFlowStatus::DISCARDED, began_at: past, discard_at: Float::INFINITY,
      )
      privacy_request = ClientPrivacyRequest.create!(
        client: actor, status_id: ClientPrivacyRequestStatus::RECEIVED, request_kind: "erasure", jurisdiction: "jp",
        request_source: "self_service", received_at: past, response_due_at: 30.days.from_now,
      )
      occurrences = ClientOccurrence.where(event_type: ["withdrawal.recovered", "privacy_erasure.cancelled"])
        .where("context ->> 'subject_public_id' = ?", actor.public_id)

      Client.transaction do
        if nesting == :savepoint
          Client.transaction(requires_new: true) { WithdrawalLifecycle.recover!(actor:) }
        else
          WithdrawalLifecycle.recover!(actor:)
        end

        assert_equal ClientPrivacyRequestStatus::CANCELLED, privacy_request.reload.status_id
        assert_predicate flow.reload, :withdrawal_recovered?
        assert_empty occurrences
        raise ActiveRecord::Rollback if outcome == :rollback
      end

      assert_equal outcome == :commit, flow.reload.withdrawal_recovered?
      assert_equal outcome == :commit, privacy_request.reload.status_id == ClientPrivacyRequestStatus::CANCELLED
      assert_equal (outcome == :commit) ? 2 : 0, occurrences.count
    ensure
      occurrences&.delete_all
      ClientPrivacyRequest.where(id: privacy_request.id).delete_all if privacy_request
      flow&.destroy!
      actor&.delete
    end
  end

  %i(commit rollback).product(%i(joined savepoint)).each do |outcome, nesting|
    test "withdrawal start inside #{nesting} waits for outer #{outcome}" do
      actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
      occurrences = ClientOccurrence.where(event_type: "withdrawal.requested")
        .where("context ->> 'subject_public_id' = ?", actor.public_id)

      Client.transaction do
        if nesting == :savepoint
          Client.transaction(requires_new: true) { WithdrawalLifecycle.start!(actor:) }
        else
          WithdrawalLifecycle.start!(actor:)
        end

        assert_equal 1, ClientWithdrawalFlow.where(client_id: actor.id).count
        assert_empty occurrences
        raise ActiveRecord::Rollback if outcome == :rollback
      end

      assert_equal (outcome == :commit) ? 1 : 0, ClientWithdrawalFlow.where(client_id: actor.id).count
      assert_equal (outcome == :commit) ? 1 : 0, occurrences.count
    ensure
      occurrences&.delete_all
      ClientWithdrawalFlow.where(client_id: actor.id).destroy_all if actor
      actor&.delete
    end
  end

  %i(commit rollback).product(%i(joined savepoint)).each do |outcome, nesting|
    test "withdrawal suspension inside #{nesting} waits for outer #{outcome}" do
      actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
      root = ClientToken.create!(user: actor, authentication_epoch: 0)
      device_id = root.device_session_id
      flow = ClientWithdrawalFlow.create!(
        client: actor, status_id: ClientWithdrawalFlowStatus::REQUESTED,
        began_at: Client.database_now,
      )
      occurrences = ClientOccurrence.where(event_type: "withdrawal.deactivated")
        .where("context ->> 'subject_public_id' = ?", actor.public_id)
      event_id = nil
      transition =
        lambda do
          WithdrawalLifecycle.suspend!(actor: actor)
          event_id = AppIdentityAuthenticationEvent.find_by!(actor_ref: actor.id.to_s).event_id
        end

      Client.transaction do
        if nesting == :savepoint
          Client.transaction(requires_new: true) { transition.call }
        else
          transition.call
        end

        assert_not OpAppInboundEventReceipt.exists?(event_id:)
        assert_not_predicate root.reload, :revoked?
        assert_empty occurrences
        raise ActiveRecord::Rollback if outcome == :rollback
      end

      assert_equal outcome == :commit, OpAppInboundEventReceipt.exists?(event_id:)
      assert_equal outcome == :commit, root.reload.revoked?
      assert_equal outcome == :commit, actor.reload.deactivated_at.present?
      assert_equal outcome == :commit, flow.reload.withdrawal_discarded?
      assert_equal (outcome == :commit) ? 1 : 0, occurrences.count
    ensure
      delete_authority_stops_for!(realm: "app", root_ids: [root&.id])
      OpAppInboundEventReceipt.where(event_id:).delete_all if event_id
      AppIdentityAuthenticationEvent.where(actor_ref: actor.id.to_s).delete_all if actor
      occurrences&.delete_all
      flow&.destroy!
      root&.delete
      ClientDeviceSession.where(id: device_id).delete_all if device_id
      actor&.delete
    end
  end

  %i(commit rollback).product(%i(joined savepoint)).each do |outcome, nesting|
    test "withdrawal termination inside #{nesting} waits for outer #{outcome}" do
      actor_id = SecureRandom.random_number(1 << 60) + 1_000_000_000
      if ClientNotificationRecord.exists?(user_id: actor_id) || AvatarAssignment.exists?(user_id: actor_id)
        raise ArgumentError, "synthetic actor ID collides with existing cross-database children"
      end

      past = Client.database_now - 10.days
      actor = Client.create!(
        id: actor_id, security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
        withdrawal_started_at: past, deactivated_at: past, discard_at: past, withdrawn_at: past,
        purge_eligible_at: 21.days.from_now,
      )
      root = ClientToken.create!(user: actor, authentication_epoch: 0)
      device_id = root.device_session_id
      flow = ClientWithdrawalFlow.create!(
        client: actor, status_id: ClientWithdrawalFlowStatus::DISCARDED, began_at: past, discard_at: Float::INFINITY,
      )
      occurrences = ClientOccurrence.where(event_type: "withdrawal.terminated")
        .where("context ->> 'subject_public_id' = ?", actor.public_id)
      event_id = nil
      transition =
        lambda do
          WithdrawalLifecycle.terminate!(actor: actor)
          event_id = AppIdentityAuthenticationEvent.find_by!(actor_ref: actor.id.to_s).event_id
        end

      Client.transaction do
        if nesting == :savepoint
          Client.transaction(requires_new: true) { transition.call }
        else
          transition.call
        end

        assert_not OpAppInboundEventReceipt.exists?(event_id:)
        assert_not_predicate root.reload, :revoked?
        assert_empty occurrences
        raise ActiveRecord::Rollback if outcome == :rollback
      end

      assert_equal outcome == :commit, OpAppInboundEventReceipt.exists?(event_id:)
      assert_equal outcome == :commit, root.reload.revoked?
      assert_equal outcome == :commit, actor.reload.terminated_at.present?
      assert_equal outcome == :commit, flow.reload.withdrawal_terminated?
      assert_equal (outcome == :commit) ? 1 : 0, occurrences.count
    ensure
      delete_authority_stops_for!(realm: "app", root_ids: [root&.id])
      OpAppInboundEventReceipt.where(event_id:).delete_all if event_id
      AppIdentityAuthenticationEvent.where(actor_ref: actor.id.to_s).delete_all if actor
      occurrences&.delete_all
      flow&.destroy!
      root&.delete
      ClientDeviceSession.where(id: device_id).delete_all if device_id
      actor&.delete
    end
  end
end
