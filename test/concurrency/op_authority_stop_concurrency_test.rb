# frozen_string_literal: true

require "test_helper"
require "timeout"

# WU-15/16: real independent OP writer connections serialize both stop idempotency and outbox leases.
class OpAuthorityStopConcurrencyTest < ActiveSupport::TestCase
  include AuthorityStopCleanup

  self.use_transactional_tests = false
  fixtures :clients

  setup do
    @client = clients(:one)
    @root = ClientToken.create!(authentication_epoch: 0, user: @client)
    @grant = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: @root, client_device_session: @root.device_session,
      device_session_id: @root.device_session_id,
      oidc_client_id: "core-app-jp", oidc_scope: "openid", oidc_jti: SecureRandom.uuid,
      last_used_at: Time.current, refresh_token_expires_at: 1.day.from_now,
    )
    ActiveRecord::Base.connection_handler.clear_active_connections!
  end

  teardown do
    delete_authority_stops_for!(realm: "app", root_ids: [@root&.id], grant_ids: [@grant&.id])
    device_session_id = @root&.device_session_id
    OpAppGrant.where(id: @grant&.id).delete_all
    ClientToken.where(id: @root&.id).delete_all
    ClientDeviceSession.where(id: device_session_id).delete_all if device_session_id
  end

  test "two independent requests with the same idempotency key commit one root stop" do
    first_ready = Queue.new
    second_ready = Queue.new
    release_first = Queue.new
    first_thread =
      Thread.new do
        OpBaseAppRecord.connection_pool.with_connection do |connection|
          result =
            OpBaseAppRecord.transaction do
              committed = OpAuthorityStopCommitter.stop_root(
                root: ClientToken.find(@root.id), cause: "browser_logout",
                principal_public_id: @client.public_id, authority_evidence_ref: "same-event",
              )
              first_ready << [connection.select_value("SELECT pg_backend_pid()"), committed]
              release_first.pop
              committed
            end
          result
        end
      end
    first_pid, first_result = Timeout.timeout(10) { first_ready.pop }
    second_thread =
      Thread.new do
        OpBaseAppRecord.connection_pool.with_connection do |connection|
          # Let the test observe transaction-level serialization even when the local two-second
          # request lock timeout would otherwise expire before the main test thread can release it.
          connection.execute("SET lock_timeout = '10s'")
          second_ready << connection.select_value("SELECT pg_backend_pid()")
          OpAuthorityStopCommitter.stop_root(
            root: ClientToken.find(@root.id), cause: "browser_logout",
            principal_public_id: @client.public_id, authority_evidence_ref: "same-event",
          )
        end
      end
    second_pid = Timeout.timeout(10) { second_ready.pop }

    assert_not_equal first_pid, second_pid
    Timeout.timeout(10) do
      loop do
        wait_type =
          OpBaseAppRecord.uncached do
            OpBaseAppRecord.lease_connection.select_value(
              "SELECT wait_event_type FROM pg_stat_activity WHERE pid = #{Integer(second_pid)}",
            )
          end
        break if wait_type == "Lock"

        Thread.pass
      end
    end
    release_first << true
    second_result = Timeout.timeout(10) { second_thread.value }
    first_thread.value

    assert_predicate first_result, :stopped?
    assert_not_predicate first_result, :replayed?
    assert_predicate second_result, :replayed?
    assert_equal first_result.stop.id, second_result.stop.id
    assert_equal 1, OpAppAuthorityStop.where(id: first_result.stop.id).count
    assert_equal [@root.id], OpAppAuthorityStopRootTarget.where(stop_id: first_result.stop.id).pluck(:root_id)
    assert_equal [@grant.id], OpAppAuthorityStopParticipant.where(stop_id: first_result.stop.id).pluck(:grant_id)
  ensure
    release_first << true if release_first
    first_thread&.join(10)
    second_thread&.join(10)
  end

  %w(app org).product(%i(commit rollback)).each do |realm, first_outcome|
    test "#{realm} concurrent identity stop delivery after first #{first_outcome} is idempotent" do
      if realm == "org"
        operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
        org_root = OperatorToken.create!(authentication_epoch: 0, staff: operator)
        org_grant = OpOrgGrant.create!(
          authentication_epoch: 0, operator_token: org_root, oidc_client_id: "core-org-jp",
          oidc_scope: "openid", oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.day.from_now,
        )
      end
      actor = (realm == "app") ? @client : operator
      root = (realm == "app") ? @root : org_root
      grant = (realm == "app") ? @grant : org_grant
      event_class = (realm == "app") ? AppIdentityAuthenticationEvent : OrgIdentityAuthenticationEvent
      op_record = (realm == "app") ? OpBaseAppRecord : OpBaseOrgRecord
      receipt_model = (realm == "app") ? OpAppInboundEventReceipt : OpOrgInboundEventReceipt
      stop_model = OpAuthorityStopCommitter.stop_class(realm)
      event = event_class.create!(
        event_id: SecureRandom.uuid, actor_ref: actor.id.to_s, realm:, cutoff_epoch: 1,
        reason: "withdrawal_suspend", scope: "all_sessions", committed_at: Time.current,
      )
      inserted = Queue.new
      release = Queue.new
      ready = Queue.new
      start = Queue.new
      first = second = nil
      observer =
        lambda do |_name, _start, _finish, _id, payload|
          next unless Thread.current == first
          next unless payload.fetch(:sql).match?(/\A\s*INSERT\s+INTO\s+"op_inbound_event_receipts"/i)

          inserted << true
          release.pop
          raise IOError, "injected first delivery failure" if first_outcome == :rollback
        end

      ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
        first =
          Thread.new do
            start.pop
            OpIdentityEventInvalidator.call(event: event_class.find(event.id))
          rescue IOError => e
            e
          ensure
            ActiveRecord::Base.connection_handler.clear_active_connections!
          end
        start << true
        Timeout.timeout(10) { inserted.pop }
        second =
          Thread.new do
            op_record.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
              ready << connection.select_value("SELECT pg_backend_pid()").to_i
              OpIdentityEventInvalidator.call(event: event_class.find(event.id))
            end
          rescue StandardError => e
            e
          ensure
            ActiveRecord::Base.connection_handler.clear_active_connections!
          end
        pid = Timeout.timeout(10) { ready.pop }
        Timeout.timeout(10) do
          loop do
            blocked =
              op_record.uncached do
                op_record.lease_connection.select_value(
                  "SELECT cardinality(pg_blocking_pids(#{Integer(pid)})) > 0",
                )
              end
            break if blocked

            Thread.pass
          end
        end
        release << true

        first_result = Timeout.timeout(10) { first.value }
        second_result = Timeout.timeout(10) { second.value }
        if first_outcome == :commit
          assert_equal :applied, first_result
          assert_equal :duplicate, second_result
        else
          assert_instance_of IOError, first_result
          assert_equal :applied, second_result
        end

        assert_equal 1, receipt_model.where(event_id: event.event_id).count
        assert_equal 1, stop_model.where(authority_evidence_ref: event.event_id).count
        assert_predicate root.reload, :revoked?
        assert_predicate grant.reload, :revoked?
      end
    ensure
      release << true if release
      [first, second].compact.each { |thread| thread.join(10) }
      receipt_model.where(event_id: event.event_id).delete_all if event && receipt_model
      event&.delete
      if org_root
        delete_authority_stops_for!(realm: "org", root_ids: [org_root.id], grant_ids: [org_grant&.id])
        device_id = org_root.device_session_id
        org_grant&.delete
        org_root.delete
        OperatorDeviceSession.where(id: device_id).delete_all
      end
      operator&.delete
    end
  end

  test "a second worker cannot lease a participant while the first worker is waiting on the RP" do
    OpAuthorityStopCommitter.stop_root(
      root: @root, cause: "browser_logout", principal_public_id: @client.public_id,
      authority_evidence_ref: "worker-race",
    )
    participant = OpAppAuthorityStopParticipant.sole
    first_call = Queue.new
    release_call = Queue.new

    OidcBackchannelLogoutClient.stub(
      :call,
      ->(**) {
        first_call << true
        release_call.pop
        :acknowledged
      },
    ) do
      first_thread =
        Thread.new do
          OpBaseAppRecord.connection_pool.with_connection { OpOutboxDispatchJob.perform_now }
        end
      Timeout.timeout(10) { first_call.pop }
      second_thread =
        Thread.new do
          OpBaseAppRecord.connection_pool.with_connection { OpOutboxDispatchJob.perform_now }
        end

      Timeout.timeout(10) { second_thread.value }

      assert_equal 0, first_call.size
      release_call << true
      Timeout.timeout(10) { first_thread.value }
    ensure
      release_call << true if release_call
      first_thread&.join(10)
      second_thread&.join(10)
    end

    assert_equal OpAuthorityStopReference.participant_status_id("acknowledged"), participant.reload.status_id
    assert_equal 1, participant.delivery_attempts
  end

  test "a committed outbox row survives enqueue failure and the recurring dispatch can deliver it" do
    result =
      OpOutboxDispatchJob.stub(:perform_later, false) do
        OpAuthorityStopCommitter.stop_root(
          root: @root, cause: "browser_logout", principal_public_id: @client.public_id,
          authority_evidence_ref: "enqueue-failure",
        )
      end

    participant = OpAppAuthorityStopParticipant.sole

    assert_predicate result, :stopped?
    assert_equal OpAuthorityStopReference.participant_status_id("pending"), participant.status_id

    OidcBackchannelLogoutClient.stub(:call, :acknowledged) { OpOutboxDispatchJob.perform_now }

    assert_equal OpAuthorityStopReference.participant_status_id("acknowledged"), participant.reload.status_id
  end
end
