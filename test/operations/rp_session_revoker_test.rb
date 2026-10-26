# typed: false
# frozen_string_literal: true

require "test_helper"

class RpSessionRevokerTest < ActiveSupport::TestCase
  setup do
    @root = ClientToken.create!(authentication_epoch: 0, user: Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL))
    @session_a = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: @root,
      oidc_client_id: "core-app-jp",
      oidc_scope: "openid profile",
      refresh_token_expires_at: 1.hour.from_now,
    )
    @session_b = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: @root,
      oidc_client_id: "warp-app-jp",
      oidc_scope: "openid profile",
      refresh_token_expires_at: 1.hour.from_now,
    )
  end

  test "rp_session scope revokes only the targeted child" do
    result = RpSessionRevoker.call(
      scope: :rp_session, record: @session_a, cause: "token_revocation",
      authority_evidence_ref: "test",
    )

    assert_predicate result, :success?
    assert_equal 1, result.revoked_count
    assert_predicate @session_a.reload, :revoked?
    assert_not @session_b.reload.revoked?
    assert_predicate @root.reload, :currently_usable?
  end

  test "browser_session scope revokes every active child for the parent" do
    result = RpSessionRevoker.call(
      scope: :browser_session, record: @root, cause: "browser_logout",
      authority_evidence_ref: "test",
    )

    assert_predicate result, :success?
    assert_equal 2, result.revoked_count
    assert_predicate @session_a.reload, :revoked?
    assert_predicate @session_b.reload, :revoked?
  end

  test "browser_session scope revokes an unrevoked child after its refresh window expires" do
    expired_session = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: @root,
      oidc_client_id: "palm-app-jp",
      oidc_scope: "openid profile",
      refresh_token_expires_at: 1.minute.ago,
    )

    result = RpSessionRevoker.call(
      scope: :browser_session, record: @root, cause: "browser_logout",
      authority_evidence_ref: "test",
    )

    assert_predicate result, :success?
    assert_equal 3, result.revoked_count
    assert_predicate expired_session.reload, :revoked?
    assert_equal "success", expired_session.reload.last_logout_status
  end

  test "browser_session scope locks the parent before any RP Session" do
    lock_tables = []
    callback =
      lambda do |*, payload|
        next if payload[:cached]

        sql = payload[:sql].to_s
        next unless sql.match?(/\bFOR UPDATE\b/i)

        if sql.match?(/\b#{Regexp.escape(ClientToken.table_name)}\b/i)
          lock_tables << :parent
        elsif sql.match?(/\b#{Regexp.escape(OpAppGrant.table_name)}\b/i)
          lock_tables << :child
        end
      end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      RpSessionRevoker.call(
        scope: :browser_session, record: @root, cause: "browser_logout",
        authority_evidence_ref: "test",
      )
    end

    assert_equal :parent, lock_tables.first,
                 "browser-session revocation must lock the parent before child RP Sessions"
    assert_includes lock_tables, :child
  end

  test "rp_session scope locks the parent before the targeted child" do
    lock_tables = []
    callback =
      lambda do |*, payload|
        next if payload[:cached]

        sql = payload[:sql].to_s
        next unless sql.match?(/\bFOR UPDATE\b/i)

        if sql.match?(/\b#{Regexp.escape(ClientToken.table_name)}\b/i)
          lock_tables << :parent
        elsif sql.match?(/\b#{Regexp.escape(OpAppGrant.table_name)}\b/i)
          lock_tables << :child
        end
      end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      RpSessionRevoker.call(
        scope: :rp_session, record: @session_a, cause: "token_revocation",
        authority_evidence_ref: "test",
      )
    end

    assert_equal :parent, lock_tables.first,
                 "RP-session revocation must lock the parent before the child"
    assert_includes lock_tables, :child
  end

  test "identity scope walks each Base Browser Session" do
    other_root = ClientToken.create!(authentication_epoch: 0, user: Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL))
    other_session = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: other_root,
      oidc_client_id: "core-app-jp",
      oidc_scope: "openid profile",
      refresh_token_expires_at: 1.hour.from_now,
    )

    result = RpSessionRevoker.call(
      scope: :identity, record: [@root, other_root], cause: "browser_logout", authority_evidence_ref: "test",
    )

    assert_predicate result, :success?
    assert_operator result.revoked_count, :>=, 3
    assert_predicate @session_a.reload, :revoked?
    assert_predicate @session_b.reload, :revoked?
    assert_predicate other_session.reload, :revoked?
  end

  test "browser_session scope revokes a visitor session's RP Sessions and the visitor token" do
    visitor_root = VisitorToken.create!(
      authentication_epoch: 0,
      visitor: Visitor.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::ACTIVE,
      ),
    )
    visitor_session = OpComGrant.create!(
      authentication_epoch: 0,
      visitor_token: visitor_root,
      oidc_client_id: "core-com-jp",
      oidc_scope: "openid profile",
      refresh_token_expires_at: 1.hour.from_now,
    )

    result = RpSessionRevoker.call(
      scope: :browser_session, record: visitor_root, cause: "browser_logout",
      authority_evidence_ref: "test",
    )

    assert_equal 1, result.revoked_count
    assert_predicate visitor_session.reload, :revoked?
    assert_predicate visitor_root.reload, :revoked?
  end

  test "browser_session scope revokes an operator session's RP Sessions and the operator token" do
    operator_root = OperatorToken.create!(
      authentication_epoch: 0,
      staff_id: Operator.create!(
        security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE,
      ).id,
    )
    operator_session = OpOrgGrant.create!(
      authentication_epoch: 0,
      operator_token: operator_root,
      oidc_client_id: "core-org-jp",
      oidc_scope: "openid profile",
      refresh_token_expires_at: 1.hour.from_now,
    )

    result = RpSessionRevoker.call(
      scope: :browser_session, record: operator_root, cause: "browser_logout",
      authority_evidence_ref: "test",
    )

    assert_equal 1, result.revoked_count
    assert_predicate operator_session.reload, :revoked?
    assert_predicate operator_root.reload, :revoked?
  end

  test "browser_session scope rejects a record that is not a Base Browser Session" do
    error =
      assert_raises(ArgumentError) do
        RpSessionRevoker.call(
          scope: :browser_session, record: @session_a, cause: "browser_logout",
          authority_evidence_ref: "test",
        )
      end

    assert_includes error.message, "OpAppGrant"
    assert_not @session_a.reload.revoked?
  end

  test "identity scope rejects a record that is not enumerable" do
    assert_raises(ArgumentError) do
      RpSessionRevoker.call(scope: :identity, record: @root, cause: "browser_logout", authority_evidence_ref: "test")
    end

    assert_not @session_a.reload.revoked?
  end

  test "rejects an unsupported revoke scope" do
    error =
      assert_raises(ArgumentError) do
        RpSessionRevoker.call(
          scope: :organization, record: @root, cause: "browser_logout",
          authority_evidence_ref: "test",
        )
      end

    assert_includes error.message, ":organization"
    assert_not @session_a.reload.revoked?
  end
end
