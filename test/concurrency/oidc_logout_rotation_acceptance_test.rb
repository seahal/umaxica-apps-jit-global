# frozen_string_literal: true

require "test_helper"
require "timeout"

class OidcLogoutRotationAcceptanceTest < ActiveSupport::TestCase
  include AuthorityStopCleanup

  self.use_transactional_tests = false
  fixtures :clients, :visitors, :operators

  setup do
    @actor = clients(:one)
    @root = ClientToken.create!(authentication_epoch: 0, user: @actor, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    @root.rotate_refresh_token!
    @grant = OpAppGrant.create!(
      authentication_epoch: 0, client_token: @root, oidc_client_id: "core-app-jp", oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.hour.from_now,
    )
    @refresh = @grant.issue_refresh_token!
    ActiveRecord::Base.connection_handler.clear_active_connections!
  end

  teardown do
    root_ids = [@root&.id, @replacement_id].compact
    delete_authority_stops_for!(realm: "app", root_ids: root_ids, grant_ids: [@grant&.id])
    OpAppGrant.where(id: @grant&.id).delete_all
    device_id = @root&.device_session_id
    ClientToken.where(id: root_ids).delete_all
    ClientDeviceSession.where(id: device_id).delete_all if device_id
  end

  test "rotation committed on one connection is stopped on another and refresh after commit fails" do
    ready = Queue.new
    rotation_go = Queue.new
    stop_go = Queue.new
    refresh_go = Queue.new
    rotated = Queue.new
    first =
      Thread.new do
        OpBaseAppRecord.connection_pool.with_connection do |connection|
          ready << connection.select_value("SELECT pg_backend_pid()")
          rotation_go.pop
          result = ClientToken.rotate_refresh!(presented_refresh_digest: @root.refresh_token_digest)
          rotated << result
          refresh_go.pop
          OidcRefreshTokenIssuer.call(refresh_token: @refresh, resource_type: "client")
        end
      end
    second =
      Thread.new do
        OpBaseAppRecord.connection_pool.with_connection do |connection|
          ready << connection.select_value("SELECT pg_backend_pid()")
          stop_go.pop
          AuthenticationLogoutCurrentSession.call(
            cause: "rp_initiated_logout", resource: Client.find(@actor.id), token: ClientToken.find(@root.id),
            reason: "user_logout", cascade_device_session_tokens: true,
          )
        end
      end
    pids = Timeout.timeout(10) { [ready.pop, ready.pop] }

    assert_equal 2, pids.uniq.length
    rotation_go << true
    result = Timeout.timeout(10) { rotated.pop }

    assert_equal :rotated, result.fetch(:status)
    @replacement_id = result.fetch(:token).id
    stop_go << true
    Timeout.timeout(10) { second.value }
    refresh_go << true
    refresh_result = Timeout.timeout(10) { first.value }

    assert_not_predicate refresh_result, :success?
    assert_predicate @root.reload, :revoked?
    assert_predicate ClientToken.find(@replacement_id), :revoked?
    assert_predicate @root.device_session.reload, :revoked?
    assert_predicate @grant.reload, :revoked?
    assert_equal 2, OpAppAuthorityStopRootTarget.where(root_id: [@root.id, @replacement_id]).count
  ensure
    rotation_go << true if rotation_go
    stop_go << true if stop_go
    refresh_go << true if refresh_go
    first&.join(10)
    second&.join(10)
  end
  test "COM and ORG committed rotations are stopped across connections and subsequent refresh is refused" do
    [
      ["com", VisitorToken, OpComGrant, VisitorDeviceSession, OpComAuthorityStopRootTarget,
       visitors(:reserved_visitor), :visitor, :visitor_token, "visitor", OpBaseComRecord,],
      ["org", OperatorToken, OpOrgGrant, OperatorDeviceSession, OpOrgAuthorityStopRootTarget,
       operators(:one), :staff, :operator_token, "operator", OpBaseOrgRecord,],
    ].each do |realm, token_class, grant_class, device_class, target_class, actor, owner, parent, type, record_class|
      root = token_class.create!(:authentication_epoch => 0, owner => actor)
      root.rotate_refresh_token!
      grant = grant_class.create!(
        :authentication_epoch => 0, parent => root, :oidc_client_id => "core-#{realm}-jp", :oidc_scope => "openid",
        :oidc_jti => SecureRandom.uuid, :refresh_token_expires_at => 1.hour.from_now,
      )
      refresh = grant.issue_refresh_token!
      ready = Queue.new
      rotation_go = Queue.new
      stop_go = Queue.new
      refresh_go = Queue.new
      rotated = Queue.new
      replacement_id = nil
      first =
        Thread.new do
          record_class.connection_pool.with_connection do |connection|
            ready << connection.select_value("SELECT pg_backend_pid()")
            rotation_go.pop
            rotated << token_class.rotate_refresh!(presented_refresh_digest: root.refresh_token_digest)
            refresh_go.pop
            OidcRefreshTokenIssuer.call(refresh_token: refresh, resource_type: type)
          end
        end
      second =
        Thread.new do
          record_class.connection_pool.with_connection do |connection|
            ready << connection.select_value("SELECT pg_backend_pid()")
            stop_go.pop
            AuthenticationLogoutCurrentSession.call(
              cause: "rp_initiated_logout", resource: actor, token: token_class.find(root.id),
              reason: "user_logout", cascade_device_session_tokens: true,
            )
          end
        end
      begin
        pids = Timeout.timeout(10) { [ready.pop, ready.pop] }

        assert_equal 2, pids.uniq.length, realm
        rotation_go << true
        result = Timeout.timeout(10) { rotated.pop }

        assert_equal :rotated, result.fetch(:status), realm
        replacement_id = result.fetch(:token).id
        stop_go << true
        Timeout.timeout(10) { second.value }
        refresh_go << true
        refresh_result = Timeout.timeout(10) { first.value }

        assert_not_predicate refresh_result, :success?, realm
        assert_predicate root.reload, :revoked?, realm
        assert_predicate token_class.find(replacement_id), :revoked?, realm
        assert_predicate root.device_session.reload, :revoked?, realm
        assert_predicate grant.reload, :revoked?, realm
        assert_equal 2, target_class.where(root_id: [root.id, replacement_id]).count, realm
      ensure
        rotation_go << true
        stop_go << true
        refresh_go << true
        first.join(10)
        second.join(10)
        root_ids = [root.id, replacement_id].compact
        delete_authority_stops_for!(realm: realm, root_ids: root_ids, grant_ids: [grant.id])
        grant_class.where(id: grant.id).delete_all
        token_class.where(id: root_ids).delete_all
        device_class.where(id: root.device_session_id).delete_all
      end
    end
  end
end
