# typed: false
# frozen_string_literal: true

require "test_helper"
require "timeout"

# The sign-out transaction and an RP refresh must use independent writer
# connections and the same Device Session -> root -> RP lock order. This test
# uses only the normal Rails test database; it does not create an isolated
# database or bypass the ownership guard.
class SignOutRefreshRaceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @root = ClientToken.create!(
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      discard_at: 1.day.from_now,
      purge_eligible_at: 2.days.from_now,
    )
    @root.rotate_refresh_token!
    @session = ClientRpSession.create!(
      client_token: @root,
      oidc_client_id: "core-app",
      oidc_scope: "openid profile",
      refresh_token_expires_at: 1.hour.from_now,
    )
    @refresh_token = @session.issue_refresh_token!
    ActiveRecord::Base.connection_handler.clear_active_connections!
  end

  teardown do
    ClientSignOutFlow.where(token_id: @root&.id).delete_all
    ClientRpSession.where(id: @session&.id).delete_all
    device_session_id = @root&.device_session_id
    ClientToken.where(id: @root&.id).delete_all
    ClientDeviceSession.where(id: device_session_id).delete_all if device_session_id
    Client.where(id: @user&.id).delete_all
  end

  test "a refresh racing sign-out cannot leave a usable RP session under a revoked parent" do
    ready = Queue.new
    release = Queue.new
    threads = [
      Thread.new do
        AppTicketRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
          pid = connection.select_value("SELECT pg_backend_pid()")
          ready << pid
          release.pop
          result = AuthenticationLogoutCurrentSession.call(
            resource: Client.find(@user.id),
            token: ClientToken.find(@root.id),
            reason: "user_logout",
          )
          { operation: :logout, pid: pid, result: result }
        end
      end,
      Thread.new do
        AppTicketRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
          pid = connection.select_value("SELECT pg_backend_pid()")
          ready << pid
          release.pop
          result = OidcRefreshTokenIssuer.call(
            refresh_token: @refresh_token,
            resource_type: "client",
          )
          { operation: :refresh, pid: pid, result: result }
        end
      end,
    ]

    outcomes =
      Timeout.timeout(10) do
        pids = [ready.pop, ready.pop]

        assert_equal 2, pids.uniq.length, "logout and refresh must use independent connections"
        2.times { release << true }
        threads.map(&:value)
      end

    refresh_outcome = outcomes.find { |outcome| outcome.fetch(:operation) == :refresh }

    assert(
      refresh_outcome.fetch(:result).success? ||
        %i(inactive_token invalid_digest refresh_token_reuse_detected).include?(refresh_outcome.fetch(:result).reason),
      "refresh outcome must be a committed success or a refusal: #{refresh_outcome.fetch(:result).inspect}",
    )

    assert_predicate @root.reload, :revoked?
    assert_predicate @root.device_session.reload, :revoked?
    assert_predicate @session.reload, :revoked?
    assert_not_predicate @session, :active?
  ensure
    2.times { release << true } if release
    threads&.each { |thread| thread.kill unless thread.join(10) }
  end
end
