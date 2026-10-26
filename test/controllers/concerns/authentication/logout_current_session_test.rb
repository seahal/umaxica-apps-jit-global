# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthenticationLogoutCurrentSessionTest < ActiveSupport::TestCase
  fixtures :clients, :client_token_statuses, :client_token_kinds

  # Unmapped token-like records are never authority for an OP stop.
  class DestroyOnlyToken
    attr_reader :destroyed

    def destroy
      @destroyed = true
    end
  end

  # Test double for a token whose class has no sign-out-flow / device-session
  # mapping (i.e. not ClientToken/VisitorToken/OperatorToken) but is already
  # revoked.
  class RevokedUnmappedToken
    def revoked?
      true
    end
  end

  # Test double for a token that reports a device_session_id but whose class
  # is not one of the known device-session-owning token classes.
  class DeviceSessionIdOnlyToken
    attr_reader :device_session_id

    def initialize(device_session_id)
      @device_session_id = device_session_id
    end
  end

  # Test double for a token_class argument whose column introspection blows
  # up with a real ActiveRecord infrastructure error.
  class StatementInvalidTokenClass
    def self.column_names
      raise ActiveRecord::StatementInvalid, "relation does not exist"
    end
  end

  test "revokes current user session token by public id" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!

    assert_difference -> { OpAppAuthorityStop.count }, 1 do
      AuthenticationLogoutCurrentSession.call(
        cause: "browser_logout",
        resource: user,
        token_class: ClientToken,
        session_public_id: token.public_id,
        reason: "user_logout",
      )
    end

    assert_predicate token.reload, :revoked?
    assert_not token.currently_usable?
    stop = OpAppAuthorityStop.find_by!(authority_evidence_ref: "user_logout")

    assert_equal "browser_logout", stop.cause_name
    assert_equal OpAuthorityStopReference.scope_id("root"), stop.scope_id
    assert_equal user.public_id, stop.principal_public_id
    assert OpAppAuthorityStopRootTarget.exists?(stop:, root: token)
  end

  test "revokes every unrevoked RP session row with the parent" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!
    active_session = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: token,
      oidc_client_id: "core-app-jp",
      oidc_scope: "openid profile",
      refresh_token_expires_at: 1.hour.from_now,
    )
    expired_session = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: token,
      oidc_client_id: "warp-app-jp",
      oidc_scope: "openid profile",
      refresh_token_expires_at: 1.minute.ago,
    )

    AuthenticationLogoutCurrentSession.call(
      cause: "browser_logout",
      resource: user,
      token: token,
      reason: "user_logout",
    )

    assert_predicate token.reload, :revoked?
    assert_predicate token.device_session.reload, :revoked?
    assert_predicate active_session.reload, :revoked?
    assert_predicate expired_session.reload, :revoked?
    assert_equal "success", active_session.last_logout_status
    assert_equal "success", expired_session.last_logout_status
  end

  test "risk cause on one root records a root stop without a browser flow or identity epoch change" do
    user = clients(:one)
    user.update_columns(authentication_epoch: 0)
    token = ClientToken.create!(
      authentication_epoch: 0, user:, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )
    session = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: token,
      oidc_client_id: "core-app-jp",
      oidc_scope: "openid profile",
      refresh_token_expires_at: 1.hour.from_now,
    )

    AuthenticationLogoutCurrentSession.call(
      cause: "risk", resource: user, token:, reason: "dbsc_refresh_failed",
    )

    stop = OpAppAuthorityStop.find_by!(authority_evidence_ref: "dbsc_refresh_failed")

    assert_equal "risk", stop.cause_name
    assert_equal OpAuthorityStopReference.scope_id("root"), stop.scope_id
    assert OpAppAuthorityStopRootTarget.exists?(stop:, root: token)
    assert_equal 0, user.reload.authentication_epoch
    assert_not AppIdentityAuthenticationEvent.exists?(reason: "sign_risk")
    assert_predicate token.reload, :revoked?
    assert_predicate session.reload, :revoked?
    assert_not OpAppAuthorityStopEpochCutoff.exists?(stop_id: stop.id)
    assert_not OpAppAuthorityStopBrowserLogout.exists?(stop_id: stop.id)
  end

  test "risk cause without a root records a principal-wide identity event" do
    user = clients(:one)
    user.update_columns(authentication_epoch: 0)
    token = ClientToken.create!(
      authentication_epoch: 0, user:, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )
    session = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: token,
      oidc_client_id: "core-app-jp",
      oidc_scope: "openid profile",
      refresh_token_expires_at: 1.hour.from_now,
    )

    assert_difference -> { AppIdentityAuthenticationEvent.where(reason: "sign_risk").count }, 1 do
      assert_difference -> { OpAppAuthorityStop.where(cause_id: OpAuthorityStopReference.cause_id("risk")).count }, 1 do
        AuthenticationLogoutCurrentSession.call(cause: "risk", resource: user, reason: "risk_decision")
      end
    end

    event = AppIdentityAuthenticationEvent.order(:id).last
    stop = OpAppAuthorityStop.find_by!(authority_evidence_ref: event.event_id)

    assert_equal 1, user.reload.authentication_epoch
    assert_equal "sign_risk", event.reason
    assert_equal "risk", stop.cause_name
    assert_equal OpAuthorityStopReference.scope_id("all_roots_of_principal"), stop.scope_id
    assert_equal 1, OpAppAuthorityStopEpochCutoff.find_by!(stop:).cutoff_epoch
    assert OpAppAuthorityStopRootTarget.exists?(stop:, root: token)
    assert_predicate token.reload, :revoked?
    assert_predicate session.reload, :revoked?
    assert_not OpAppAuthorityStopBrowserLogout.exists?(stop_id: stop.id)
  end

  test "revokes unrevoked RP sessions when the parent token was already revoked" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!
    session = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: token,
      oidc_client_id: "core-app-jp",
      oidc_scope: "openid profile",
      refresh_token_expires_at: 1.hour.from_now,
    )

    token.revoke!

    AuthenticationLogoutCurrentSession.call(
      cause: "browser_logout",
      resource: user,
      token: token,
      reason: "user_logout",
    )

    assert_predicate session.reload, :revoked?
    assert_equal "success", session.last_logout_status
  end

  test "a precondition that fails under the parent lock revokes nothing" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    rp_session = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: token,
      oidc_client_id: "core-app-jp",
      oidc_scope: "openid profile",
      refresh_token_expires_at: 1.hour.from_now,
    )
    stops_before = OpAppAuthorityStop.count

    assert_raises(AuthenticationLogoutCurrentSession::PreconditionFailed) do
      AuthenticationLogoutCurrentSession.call(
        cause: "browser_logout",
        resource: user, token: token, reason: "rp_initiated_logout", precondition: -> { false },
      )
    end

    assert_not_predicate token.reload, :revoked?
    assert_not_predicate token.device_session.reload, :revoked?
    assert_predicate rp_session.reload, :active?
    assert_equal stops_before, OpAppAuthorityStop.count
  end

  test "a precondition is evaluated while the parent Device Session row is locked" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    device_session = token.device_session
    locked = nil
    precondition =
      lambda do
        locked = ClientDeviceSession.connection.select_value(<<~SQL.squish)
          SELECT count(*) FROM pg_locks l JOIN pg_class c ON c.oid = l.relation
          WHERE c.relname = '#{ClientDeviceSession.table_name}' AND l.mode = 'RowShareLock'
            AND l.pid = pg_backend_pid()
        SQL
        true
      end

    AuthenticationLogoutCurrentSession.call(
      cause: "browser_logout",
      resource: user, token: token, reason: "rp_initiated_logout", precondition: precondition,
    )

    assert_operator locked.to_i, :>=, 1
    assert_predicate device_session.reload, :revoked?
    assert_predicate token.reload, :revoked?
  end

  test "revokes current user session token by oidc sid" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!

    AuthenticationLogoutCurrentSession.call(
      cause: "browser_logout",
      resource: user,
      token_class: ClientToken,
      session_public_id: token.oidc_sid,
      reason: "user_logout",
    )

    assert_predicate token.reload, :revoked?
  end

  test "is idempotent when token is already revoked" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.revoke!

    assert_no_difference -> { OpAppAuthorityStop.count } do
      AuthenticationLogoutCurrentSession.call(
        cause: "browser_logout",
        resource: user,
        token_class: ClientToken,
        session_public_id: token.public_id,
        reason: "user_logout",
      )
    end

    assert_predicate token.reload, :revoked?
    assert_not OpAppAuthorityStop.exists?(authority_evidence_ref: "user_logout")
  end

  test "repairs an unrevoked RP grant under a previously revoked root" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!
    session = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: token,
      oidc_client_id: "core-app-jp",
      oidc_scope: "openid profile",
      refresh_token_expires_at: 1.hour.from_now,
    )

    token.revoke!
    AuthenticationLogoutCurrentSession.call(
      cause: "browser_logout", resource: user, token: token,
      reason: "user_logout",
    )

    stop = OpAppAuthorityStop.find_by!(authority_evidence_ref: "user_logout")

    assert OpAppAuthorityStopRootTarget.exists?(stop:, root: token)
    assert_predicate session.reload, :revoked?

    AuthenticationLogoutCurrentSession.call(
      cause: "browser_logout", resource: user, token: token,
      reason: "user_logout",
    )

    assert_predicate session.reload, :revoked?
  end

  test "succeeds when token and session are nil" do
    assert_no_difference -> { OpAppAuthorityStop.count } do
      AuthenticationLogoutCurrentSession.call(
        cause: "browser_logout",
        resource: clients(:one),
        token_class: ClientToken,
        session_public_id: nil,
        reason: "user_logout",
      )
    end
  end

  test "records visitor and operator root stops in their own realms" do
    visitor = Visitor.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      public_id: "v#{SecureRandom.hex(10)}", status_id: VisitorStatus::ACTIVE,
    )
    visitor_token = VisitorToken.create!(authentication_epoch: 0, visitor: visitor)
    visitor_token.rotate_refresh_token!
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    operator_token = OperatorToken.create!(authentication_epoch: 0, staff: operator)
    operator_token.rotate_refresh_token!

    assert_difference -> { OpComAuthorityStop.count }, 1 do
      AuthenticationLogoutCurrentSession.call(
        cause: "browser_logout",
        resource: visitor,
        token_class: VisitorToken,
        session_public_id: visitor_token.public_id,
        reason: "visitor_logout",
      )
    end
    assert_difference -> { OpOrgAuthorityStop.count }, 1 do
      AuthenticationLogoutCurrentSession.call(
        cause: "browser_logout",
        resource: operator,
        token_class: OperatorToken,
        session_public_id: operator_token.public_id,
        reason: "operator_logout",
      )
    end

    visitor_stop = OpComAuthorityStop.find_by!(authority_evidence_ref: "visitor_logout")
    operator_stop = OpOrgAuthorityStop.find_by!(authority_evidence_ref: "operator_logout")

    assert_equal "browser_logout", visitor_stop.cause_name
    assert_equal "browser_logout", operator_stop.cause_name
    assert OpComAuthorityStopRootTarget.exists?(stop: visitor_stop, root: visitor_token)
    assert OpOrgAuthorityStopRootTarget.exists?(stop: operator_stop, root: operator_token)
  end

  # ------------------------------------------------------------------
  # current_session_from_current: resolves session_public_id from `current`
  # when session_public_id is omitted. Targets line 49 and the fallthrough
  # branch of line 47 (else@47).
  # ------------------------------------------------------------------
  test "resolves the session public id from current when session_public_id is omitted" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!
    current = Struct.new(:session).new(token.public_id)

    AuthenticationLogoutCurrentSession.call(
      cause: "browser_logout",
      current: current,
      resource: user,
      token_class: ClientToken,
      reason: "user_logout",
    )

    assert_predicate token.reload, :revoked?
  end

  # ------------------------------------------------------------------
  # resolved_token: device-session lookup path. Targets line 58 (then@58)
  # and the paired else@56 case below.
  # ------------------------------------------------------------------
  test "resolves the token via its device session when session_public_id targets the device session" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!
    device_session = token.reload.device_session

    assert_not_nil device_session

    assert_difference -> { OpAppAuthorityStop.count }, 1 do
      AuthenticationLogoutCurrentSession.call(
        cause: "browser_logout",
        resource: user,
        token_class: ClientToken,
        session_public_id: device_session.public_id,
        reason: "user_logout",
      )
    end

    assert_predicate token.reload, :revoked?
  end

  # Targets else@56, then@70 and then@77: token_class cannot report its own
  # columns, so both the device-session lookup and the public_id/oidc_sid
  # lookups short-circuit and resolved_token is nil. Logout must still
  # complete without raising.
  test "is a safe no-op when token_class cannot report its column names" do
    # A token_class double with no .column_names at all (unlike ClientToken,
    # which always exposes it via ActiveRecord).
    columnless_token_class = Class.new

    result = AuthenticationLogoutCurrentSession.call(
      cause: "browser_logout",
      resource: clients(:one),
      token_class: columnless_token_class,
      session_public_id: "some-session-id",
      reason: "user_logout",
    )

    assert result
  end

  # Targets then@71: session_public_id fails the public_id lookup and is not
  # a valid oidc_sid uuid, so find_token_by(:oidc_sid) returns early.
  test "resolved token is nil when session_public_id matches neither a public id nor a valid oidc sid" do
    assert_no_difference -> { OpAppAuthorityStop.count } do
      result = AuthenticationLogoutCurrentSession.call(
        cause: "browser_logout",
        resource: clients(:one),
        token_class: ClientToken,
        session_public_id: "not-a-uuid-and-not-a-public-id",
        reason: "user_logout",
      )

      assert result
    end
  end

  # Targets line 66: resolved_token swallows a real ActiveRecord::StatementInvalid
  # raised while introspecting token_class and treats it as "no token found".
  # A database failure is not "no session": sign-out must not report success.
  test "a statement error while resolving the token propagates" do
    assert_raises(ActiveRecord::StatementInvalid) do
      AuthenticationLogoutCurrentSession.call(
        cause: "browser_logout",
        resource: clients(:one),
        token_class: StatementInvalidTokenClass,
        session_public_id: "some-session-id",
        reason: "user_logout",
      )
    end
  end

  # Targets line 94: find_device_session swallows a device-session lookup
  # failure and the resolver falls back to the ordinary public_id lookup.
  test "a device-session lookup failure propagates and revokes nothing" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!

    ClientDeviceSession.stub(:active, -> { raise ActiveRecord::StatementInvalid, "boom" }) do
      assert_raises(ActiveRecord::StatementInvalid) do
        AuthenticationLogoutCurrentSession.call(
          cause: "browser_logout",
          resource: user,
          token_class: ClientToken,
          session_public_id: token.public_id,
          reason: "user_logout",
        )
      end
    end

    assert_not_predicate token.reload, :revoked?
  end

  # ------------------------------------------------------------------
  # revoke_device_session!: a device-session failure must be observable and
  # must not turn a partial revocation into a successful sign-out.
  # ------------------------------------------------------------------
  test "propagates a device-session revoke failure without revoking the token" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!
    device_session = token.reload.device_session

    assert_not_nil device_session
    device_session.define_singleton_method(:revoke!) { |*| raise ActiveRecord::RecordInvalid.new(device_session) }

    assert_raises(ActiveRecord::RecordInvalid) do
      ClientDeviceSession.stub(:find_by, ->(*) { device_session }) do
        AuthenticationLogoutCurrentSession.call(
          cause: "browser_logout",
          resource: user,
          token: token,
          reason: "user_logout",
        )
      end
    end

    assert_not token.reload.revoked?
    assert_not device_session.reload.revoked?,
               "the device session revoke itself failed, so it must remain unrevoked"
  end

  # Targets else@145, else@146, else@147: the failure-logging path must not
  # blow up when resource and the resolved token are both absent.
  test "logs safely without resource or token identifiers when the device session revoke raises" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    device_session = token.reload.device_session

    assert_not_nil device_session
    token.revoke!

    original_revoke = ClientDeviceSession.instance_method(:revoke!)
    ClientDeviceSession.define_method(:revoke!) { |*| raise ActiveRecord::RecordInvalid.new(self) }

    assert_raises(ActiveRecord::RecordInvalid) do
      begin
        AuthenticationLogoutCurrentSession.call(
          cause: "browser_logout",
          resource: nil,
          token_class: ClientToken,
          session_public_id: device_session.public_id,
          reason: "user_logout",
        )
      ensure
        ClientDeviceSession.define_method(:revoke!, original_revoke)
      end
    end
    assert_not device_session.reload.revoked?
  end

  test "failure logs carry no actor reference, token identifier or error message" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    output = StringIO.new
    original_logger = Rails.logger
    original_revoke = ClientDeviceSession.instance_method(:revoke!)
    ClientDeviceSession.define_method(:revoke!) { |*| raise ActiveRecord::StatementInvalid, "secret-bearing detail" }
    Rails.logger = ActiveSupport::Logger.new(output)

    assert_raises(ActiveRecord::StatementInvalid) do
      AuthenticationLogoutCurrentSession.call(
        cause: "browser_logout", resource: user, token: token,
        reason: "user_logout",
      )
    ensure
      Rails.logger = original_logger
      ClientDeviceSession.define_method(:revoke!, original_revoke)
    end

    log = output.string

    assert_includes log, "auth.logout_current_session.device_session_failed"
    assert_not_includes log, "secret-bearing detail"
    assert_not_includes log, token.public_id
    assert_no_match(/resource_id=#{user.id}\b|"resource_id":#{user.id}\b/, log)
    assert_no_match(/token_id/, log)
  end

  # ------------------------------------------------------------------
  # revoke_token!: destroy fallback and rescue logging. Targets lines 167,
  # 171, 183 and (resource variants) then/else@175-178.
  # ------------------------------------------------------------------
  test "does not destroy an unsupported token-like object" do
    token = DestroyOnlyToken.new

    result = AuthenticationLogoutCurrentSession.call(
      cause: "browser_logout",
      resource: clients(:one),
      token: token,
      reason: "user_logout",
    )

    assert result
    assert_nil token.destroyed
  end

  test "a revocation failure propagates and the token stays unrevoked" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    OpAuthorityStopCommitter.stub(
      :stop_root, ->(**) { raise ActiveRecord::RecordInvalid.new(token) },
    ) do
      assert_raises(ActiveRecord::RecordInvalid) do
        AuthenticationLogoutCurrentSession.call(
          cause: "browser_logout",
          resource: user,
          token: token,
          reason: "user_logout",
          cascade_device_session_tokens: false,
        )
      end
    end

    assert_not token.revoked?
  end

  # Targets else@175, else@176: the rescue log must not blow up without a
  # resource present.
  test "a revocation failure propagates without a resource" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    OpAuthorityStopCommitter.stub(
      :stop_root, ->(**) { raise ActiveRecord::RecordInvalid.new(token) },
    ) do
      assert_raises(ActiveRecord::RecordInvalid) do
        AuthenticationLogoutCurrentSession.call(
          cause: "browser_logout",
          resource: nil,
          token: token,
          reason: "user_logout",
          cascade_device_session_tokens: false,
        )
      end
    end

    assert_not token.revoked?
  end

  test "rolls back the parent and authority stop when token cascade fails" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!
    device_session = token.reload.device_session

    stop_count = OpAppAuthorityStop.count

    assert_raises(ActiveRecord::StatementInvalid) do
      ClientToken.stub(:where, ->(*) { raise ActiveRecord::StatementInvalid, "cascade lookup failed" }) do
        AuthenticationLogoutCurrentSession.call(
          cause: "browser_logout",
          resource: user,
          token: token,
          reason: "user_logout",
        )
      end
    end

    assert_predicate device_session.reload, :usable?
    assert_not_predicate token.reload, :revoked?
    assert_equal stop_count, OpAppAuthorityStop.count
  end

  test "rolls back the parent, RP sessions and authority stop when an RP revoke fails" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!
    device_session = token.reload.device_session
    rp_session = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: token,
      oidc_client_id: "core-app-jp",
      oidc_scope: "openid profile",
      refresh_token_expires_at: 1.hour.from_now,
    )
    stop_count = OpAppAuthorityStop.count
    original_revoke = OpAppGrant.instance_method(:revoke_under_stop_lock!)

    OpAppGrant.define_method(:revoke_under_stop_lock!) { |**| raise ActiveRecord::RecordInvalid.new(self) }
    assert_raises(ActiveRecord::RecordInvalid) do
      AuthenticationLogoutCurrentSession.call(
        cause: "browser_logout",
        resource: user,
        token: token,
        reason: "user_logout",
      )
    end
  ensure
    OpAppGrant.define_method(:revoke_under_stop_lock!, original_revoke) if original_revoke

    assert_predicate device_session.reload, :usable?
    assert_not_predicate token.reload, :revoked?
    assert_not_predicate rp_session.reload, :revoked?
    assert_equal stop_count, OpAppAuthorityStop.count
  end

  test "confirms the persisted parent when the writer reports a lost commit response" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!
    transaction_depth = 0

    result =
      OpBaseAppRecord.stub(
        :transaction,
        lambda do |*, &block|
          transaction_depth += 1
          result = block.call
          raise ActiveRecord::ConnectionFailed, "commit response lost" if transaction_depth == 1

          result
        ensure
          transaction_depth -= 1
        end,
      ) do
        AuthenticationLogoutCurrentSession.call(
          cause: "browser_logout",
          resource: user,
          token: token,
          reason: "user_logout",
        )
      end

    assert result
    assert_predicate token.reload, :revoked?
    assert_predicate token.device_session.reload, :revoked?
  end

  test "raises an indeterminate outcome when the post-commit read cannot use the writer" do
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!
    transaction_depth = 0
    read_available = true
    original_with_connection = OpBaseAppRecord.connection_pool.method(:with_connection)

    assert_raises(AuthenticationLogoutCurrentSession::CommitOutcomeUnknown) do
      OpBaseAppRecord.stub(
        :transaction,
        lambda do |*, &block|
          transaction_depth += 1
          result = block.call
          if transaction_depth == 1
            read_available = false
            raise ActiveRecord::ConnectionFailed, "commit response lost"
          end

          result
        ensure
          transaction_depth -= 1
        end,
      ) do
        OpBaseAppRecord.connection_pool.stub(
          :with_connection,
          lambda do |*args, **kwargs, &block|
            raise ActiveRecord::ConnectionFailed, "writer unavailable" unless read_available

            original_with_connection.call(*args, **kwargs, &block)
          end,
        ) do
          AuthenticationLogoutCurrentSession.call(
            cause: "browser_logout",
            resource: user,
            token: token,
            reason: "user_logout",
          )
        end
      end
    end
  end

  test "logout proceeds normally for a revoked token-like object without a root mapping" do
    token = RevokedUnmappedToken.new

    result = AuthenticationLogoutCurrentSession.call(
      cause: "browser_logout",
      resource: clients(:one),
      token: token,
      reason: "user_logout",
    )

    assert result
  end

  # ------------------------------------------------------------------
  # device_session_for_token / device_session_class_for_token: unmapped
  # token class with a device_session_id. Targets else@196 and else@200.
  # ------------------------------------------------------------------
  test "tolerates a token with a device_session_id but no device session class mapping" do
    token = DeviceSessionIdOnlyToken.new(999_999_999)

    result = AuthenticationLogoutCurrentSession.call(
      cause: "browser_logout",
      resource: clients(:one),
      token: token,
      reason: "user_logout",
    )

    assert result
  end
end
