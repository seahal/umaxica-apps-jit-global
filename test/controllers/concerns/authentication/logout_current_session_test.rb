# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthenticationLogoutCurrentSessionTest < ActiveSupport::TestCase
  fixtures :clients, :client_token_statuses, :client_token_kinds

  # Test double used only to exercise the fallback branch in #revoke_token!
  # (elsif token_record.respond_to?(:destroy)) for token-like records that
  # do not implement #revoke!.
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
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!

    assert_difference -> { ClientSignOutFlow.count }, 1 do
      AuthenticationLogoutCurrentSession.call(
        resource: user,
        token_class: ClientToken,
        session_public_id: token.public_id,
        reason: "user_logout",
      )
    end

    assert_predicate token.reload, :revoked?
    assert_not token.currently_usable?
    cycle = ClientSignOutFlow.recent_first.find_by!(token: token)

    assert_predicate cycle, :sign_out_completed?
    assert_equal ClientSignOutFlow.kind_id_for("IDP_SIGN_OUT"), cycle.kind_id
    assert_equal user.id, cycle.principal_id
    assert_equal token.refresh_token_family_id, cycle.refresh_token_family_id
    assert_not_nil cycle.access_discarded_at
    assert_not_nil cycle.logically_revoked_at
    assert_not_nil cycle.completed_at
  end

  test "revokes current user session token by oidc sid" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!

    AuthenticationLogoutCurrentSession.call(
      resource: user,
      token_class: ClientToken,
      session_public_id: token.oidc_sid,
      reason: "user_logout",
    )

    assert_predicate token.reload, :revoked?
  end

  test "is idempotent when token is already revoked" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.revoke!

    assert_difference -> { ClientSignOutFlow.count }, 1 do
      AuthenticationLogoutCurrentSession.call(
        resource: user,
        token_class: ClientToken,
        session_public_id: token.public_id,
        reason: "user_logout",
      )
    end

    assert_predicate token.reload, :revoked?
    assert_predicate ClientSignOutFlow.recent_first.find_by!(token: token), :sign_out_completed?
  end

  test "succeeds when token and session are nil" do
    assert_no_difference -> { ClientSignOutFlow.count } do
      AuthenticationLogoutCurrentSession.call(
        resource: clients(:one),
        token_class: ClientToken,
        session_public_id: nil,
        reason: "user_logout",
      )
    end
  end

  test "records visitor and operator sign-out cycles on their own surfaces" do
    visitor = Visitor.create!(public_id: "v#{SecureRandom.hex(10)}", status_id: VisitorStatus::ACTIVE)
    visitor_token = VisitorToken.create!(visitor: visitor)
    visitor_token.rotate_refresh_token!
    operator = Operator.create!(status_id: OperatorStatus::ACTIVE)
    operator_token = OperatorToken.create!(staff: operator)
    operator_token.rotate_refresh_token!

    assert_difference -> { VisitorSignOutFlow.count }, 1 do
      AuthenticationLogoutCurrentSession.call(
        resource: visitor,
        token_class: VisitorToken,
        session_public_id: visitor_token.public_id,
        reason: "visitor_logout",
      )
    end
    assert_difference -> { OperatorSignOutFlow.count }, 1 do
      AuthenticationLogoutCurrentSession.call(
        resource: operator,
        token_class: OperatorToken,
        session_public_id: operator_token.public_id,
        reason: "operator_logout",
      )
    end

    assert_predicate VisitorSignOutFlow.recent_first.find_by!(token: visitor_token), :sign_out_completed?
    assert_predicate OperatorSignOutFlow.recent_first.find_by!(token: operator_token), :sign_out_completed?
  end

  # ------------------------------------------------------------------
  # call: rescue StandardError -> fail_sign_out_flow(cycle); raise
  # Targets lines 34, 35 and the "continue" branch of fail_sign_out_flow's
  # guard (else@257), plus its normal reload+fail_sign_out! path (259, 260).
  # ------------------------------------------------------------------
  test "marks the sign-out cycle failed and re-raises when a step in the flow raises" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!

    original_create = ClientSignOutFlow.method(:create!)
    cycle = nil

    ClientSignOutFlow.stub(
      :create!, ->(attrs) {
                  cycle = original_create.call(attrs)
                  def cycle.mark_access_discarded!(*)
                    raise StandardError, "boom"
                  end
                  cycle
                },
    ) do
      assert_raises(StandardError) do
        AuthenticationLogoutCurrentSession.call(
          resource: user,
          token_class: ClientToken,
          session_public_id: token.public_id,
          reason: "user_logout",
        )
      end
    end

    assert_predicate cycle.reload, :sign_out_failed?
    assert_not token.reload.revoked?,
               "the token must not have been revoked yet since the failure happened before revocation"
  end

  # Targets then@257: fail_sign_out_flow must not attempt another transition
  # when the cycle was already failed by the time the rescue runs.
  test "does not re-fail an already-failed sign-out cycle" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!

    original_create = ClientSignOutFlow.method(:create!)
    cycle = nil

    ClientSignOutFlow.stub(
      :create!, ->(attrs) {
                  cycle = original_create.call(attrs)
                  cycle.update_columns(status_id: ClientSignOutFlowStatus::FAILED, failed_at: Time.current)
                  def cycle.mark_access_discarded!(*)
                    raise StandardError, "boom"
                  end
                  cycle
                },
    ) do
      assert_raises(StandardError) do
        AuthenticationLogoutCurrentSession.call(
          resource: user,
          token_class: ClientToken,
          session_public_id: token.public_id,
          reason: "user_logout",
        )
      end
    end

    assert_predicate cycle.reload, :sign_out_failed?
  end

  # Targets fail_sign_out_flow's own rescue (line 263): the cycle can no
  # longer transition (it was discarded out from under the flow), and the
  # resulting FlowInvalidTransition must be swallowed, not re-raised.
  test "swallows a transition error raised while failing a discarded sign-out cycle" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!

    original_create = ClientSignOutFlow.method(:create!)
    cycle = nil
    ClientSignOutFlow.stub(
      :create!, ->(attrs) {
                  cycle = original_create.call(attrs)
                  cycle.update_columns(discard_at: 1.hour.ago)
                  def cycle.mark_access_discarded!(*)
                    raise StandardError, "boom"
                  end
                  cycle
                },
    ) do
      error =
        assert_raises(StandardError) do
          AuthenticationLogoutCurrentSession.call(
            resource: user,
            token_class: ClientToken,
            session_public_id: token.public_id,
            reason: "user_logout",
          )
        end
      assert_equal "boom", error.message
    end

    assert_predicate cycle.reload, :sign_out_requested?
  end

  # ------------------------------------------------------------------
  # current_session_from_current: resolves session_public_id from `current`
  # when session_public_id is omitted. Targets line 49 and the fallthrough
  # branch of line 47 (else@47).
  # ------------------------------------------------------------------
  test "resolves the session public id from current when session_public_id is omitted" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!
    current = Struct.new(:session).new(token.public_id)

    AuthenticationLogoutCurrentSession.call(
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
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!
    device_session = token.reload.device_session

    assert_not_nil device_session

    assert_difference -> { ClientSignOutFlow.count }, 1 do
      AuthenticationLogoutCurrentSession.call(
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
    assert_no_difference -> { ClientSignOutFlow.count } do
      result = AuthenticationLogoutCurrentSession.call(
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
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!

    ClientDeviceSession.stub(:active, -> { raise ActiveRecord::StatementInvalid, "boom" }) do
      assert_raises(ActiveRecord::StatementInvalid) do
        AuthenticationLogoutCurrentSession.call(
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
  # revoke_device_session!: failure fallback and its logging. Targets
  # lines 141, 157 and (with a present resource/token) then@145-147.
  # ------------------------------------------------------------------
  test "falls back to revoking the token directly when the device session revoke raises" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!
    device_session = token.reload.device_session

    assert_not_nil device_session
    device_session.define_singleton_method(:revoke!) { |*| raise ActiveRecord::RecordInvalid.new(device_session) }

    AuthenticationLogoutCurrentSession.call(
      resource: user,
      token: token,
      reason: "user_logout",
    )

    assert_predicate token.reload, :revoked?
    assert_not device_session.reload.revoked?,
               "the device session revoke itself failed, so it must remain unrevoked"
  end

  # Targets else@145, else@146, else@147: the failure-logging path must not
  # blow up when resource and the resolved token are both absent.
  test "logs safely without resource or token identifiers when the device session revoke raises" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    device_session = token.reload.device_session

    assert_not_nil device_session
    token.revoke!

    original_revoke = ClientDeviceSession.instance_method(:revoke!)
    ClientDeviceSession.define_method(:revoke!) { |*| raise ActiveRecord::RecordInvalid.new(self) }

    result =
      begin
        AuthenticationLogoutCurrentSession.call(
          resource: nil,
          token_class: ClientToken,
          session_public_id: device_session.public_id,
          reason: "user_logout",
        )
      ensure
        ClientDeviceSession.define_method(:revoke!, original_revoke)
      end

    assert result
    assert_not device_session.reload.revoked?
  end

  # ------------------------------------------------------------------
  # revoke_token!: destroy fallback and rescue logging. Targets lines 167,
  # 171, 183 and (resource variants) then/else@175-178.
  # ------------------------------------------------------------------
  test "revokes a token lacking revoke! by destroying it instead" do
    token = DestroyOnlyToken.new

    result = AuthenticationLogoutCurrentSession.call(
      resource: clients(:one),
      token: token,
      reason: "user_logout",
    )

    assert result
    assert token.destroyed
  end

  test "a revocation failure propagates and the token stays unrevoked" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.define_singleton_method(:revoke!) { raise ActiveRecord::RecordInvalid.new(token) }

    assert_raises(ActiveRecord::RecordInvalid) do
      AuthenticationLogoutCurrentSession.call(
        resource: user,
        token: token,
        reason: "user_logout",
        cascade_device_session_tokens: false,
      )
    end

    assert_not token.revoked?
  end

  # Targets else@175, else@176: the rescue log must not blow up without a
  # resource present.
  test "a revocation failure propagates without a resource" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.define_singleton_method(:revoke!) { raise ActiveRecord::RecordInvalid.new(token) }

    assert_raises(ActiveRecord::RecordInvalid) do
      AuthenticationLogoutCurrentSession.call(
        resource: nil,
        token: token,
        reason: "user_logout",
        cascade_device_session_tokens: false,
      )
    end

    assert_not token.revoked?
  end

  # ------------------------------------------------------------------
  # begin_sign_out_flow: cycle creation failure. Targets lines 228, 239 and
  # then/else@232-233 (resource variants).
  # ------------------------------------------------------------------
  test "still revokes the token when the sign-out cycle record cannot be created" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!

    ClientSignOutFlow.stub(:create!, ->(*) { raise ArgumentError, "boom" }) do
      assert_no_difference -> { ClientSignOutFlow.count } do
        AuthenticationLogoutCurrentSession.call(
          resource: user,
          token_class: ClientToken,
          session_public_id: token.public_id,
          reason: "user_logout",
        )
      end
    end

    assert_predicate token.reload, :revoked?
  end

  test "still revokes the token when the sign-out cycle record cannot be created and no resource is present" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!

    ClientSignOutFlow.stub(:create!, ->(*) { raise ArgumentError, "boom" }) do
      AuthenticationLogoutCurrentSession.call(
        resource: nil,
        token_class: ClientToken,
        session_public_id: token.public_id,
        reason: "user_logout",
      )
    end

    assert_predicate token.reload, :revoked?
  end

  # ------------------------------------------------------------------
  # recent_completed_sign_out_flow?: rescue and unmapped-class branches.
  # Targets lines 253 and 246 (then@246).
  # ------------------------------------------------------------------
  test "logout proceeds normally when checking for a recent completed sign-out cycle raises" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.revoke!

    result =
      ClientSignOutFlow.stub(:where, ->(*) { raise ArgumentError, "boom" }) do
        AuthenticationLogoutCurrentSession.call(
          resource: user,
          token_class: ClientToken,
          session_public_id: token.public_id,
          reason: "user_logout",
        )
      end

    assert result
  end

  test "logout proceeds normally for a revoked token whose class has no sign-out flow mapping" do
    token = RevokedUnmappedToken.new

    result = AuthenticationLogoutCurrentSession.call(
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
      resource: clients(:one),
      token: token,
      reason: "user_logout",
    )

    assert result
  end

  # ------------------------------------------------------------------
  # sign_out_refresh_expires_at: mirrors a future discard_at, or falls
  # back to the current time. Targets then@289 and else@288/else@289.
  # ------------------------------------------------------------------
  test "sign-out cycle refresh expiry mirrors the token's future discard_at" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!
    expected_discard_at = token.reload.discard_at

    assert_predicate expected_discard_at, :present?
    assert_operator expected_discard_at, :>, Time.current

    AuthenticationLogoutCurrentSession.call(
      resource: user,
      token_class: ClientToken,
      session_public_id: token.public_id,
      reason: "user_logout",
    )

    cycle = ClientSignOutFlow.recent_first.find_by!(token: token)

    assert_in_delta Float(expected_discard_at), Float(cycle.refresh_expires_at), 1.0
  end

  test "sign-out cycle refresh expiry falls back to the current time when discard_at is not in the future" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.revoke!

    assert_operator token.reload.discard_at, :<, Time.current

    before_call = Time.current
    AuthenticationLogoutCurrentSession.call(
      resource: user,
      token_class: ClientToken,
      session_public_id: token.public_id,
      reason: "user_logout",
    )

    cycle = ClientSignOutFlow.recent_first.find_by!(token: token)

    assert_operator cycle.refresh_expires_at, :>=, before_call
  end

  # Targets then@288: a token whose discard_at is still at its raw
  # Float::INFINITY default (i.e. it has not yet gone through the
  # before_validation callback that assigns a concrete lapse time) must get
  # a concrete far-future refresh expiry instead of an unusable
  # Float::INFINITY value. `token:` is passed directly (bypassing lookup),
  # matching how a caller holding an in-memory, not-yet-persisted token
  # object would invoke this concern.
  test "sign-out cycle refresh expiry is set 100 years out when the token's discard_at is infinite" do
    user = clients(:one)
    token = ClientToken.new(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    assert token.discard_at.respond_to?(:infinite?) && token.discard_at.infinite?

    AuthenticationLogoutCurrentSession.call(resource: user, token: token, reason: "user_logout")

    cycle = ClientSignOutFlow.recent_first.find_by!(token_id: token.id)

    assert_in_delta 100.years.from_now.to_f, Float(cycle.refresh_expires_at), 5.0
  end

  # Targets else@287: the token record does not expose discard_at via
  # respond_to? (a singleton override on this one instance; the underlying
  # attribute keeps working normally so ActiveRecord internals are
  # unaffected), so the cycle's refresh expiry must fall back to the
  # current time rather than raising.
  test "sign-out cycle refresh expiry falls back to the current time when the token cannot report discard_at" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.define_singleton_method(:respond_to?) do |name, include_all = false|
      next false if name == :discard_at

      super(name, include_all)
    end

    before_call = Time.current
    AuthenticationLogoutCurrentSession.call(resource: user, token: token, reason: "user_logout")

    cycle = ClientSignOutFlow.recent_first.find_by!(token: token)

    assert_operator cycle.refresh_expires_at, :>=, before_call
  end
end
