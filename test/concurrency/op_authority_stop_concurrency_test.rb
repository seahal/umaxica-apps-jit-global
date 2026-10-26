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
