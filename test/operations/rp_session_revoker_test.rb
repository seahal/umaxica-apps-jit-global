# typed: false
# frozen_string_literal: true

require "test_helper"

class RpSessionRevokerTest < ActiveSupport::TestCase
  setup do
    @root = ClientToken.create!(user: Client.create!)
    @session_a = ClientRpSession.create!(
      client_token: @root,
      oidc_client_id: "core-app",
      oidc_scope: "openid profile",
      refresh_token_expires_at: 1.hour.from_now,
    )
    @session_b = ClientRpSession.create!(
      client_token: @root,
      oidc_client_id: "side-app",
      oidc_scope: "openid profile",
      refresh_token_expires_at: 1.hour.from_now,
    )
  end

  test "rp_session scope revokes only the targeted child" do
    result = RpSessionRevoker.call(scope: :rp_session, record: @session_a)

    assert_predicate result, :success?
    assert_equal 1, result.revoked_count
    assert_predicate @session_a.reload, :revoked?
    assert_not @session_b.reload.revoked?
    assert_predicate @root.reload, :currently_usable?
  end

  test "browser_session scope revokes every active child for the parent" do
    result = RpSessionRevoker.call(scope: :browser_session, record: @root)

    assert_predicate result, :success?
    assert_equal 2, result.revoked_count
    assert_predicate @session_a.reload, :revoked?
    assert_predicate @session_b.reload, :revoked?
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
        elsif sql.match?(/\b#{Regexp.escape(ClientRpSession.table_name)}\b/i)
          lock_tables << :child
        end
      end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      RpSessionRevoker.call(scope: :browser_session, record: @root)
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
        elsif sql.match?(/\b#{Regexp.escape(ClientRpSession.table_name)}\b/i)
          lock_tables << :child
        end
      end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      RpSessionRevoker.call(scope: :rp_session, record: @session_a)
    end

    assert_equal :parent, lock_tables.first,
                 "RP-session revocation must lock the parent before the child"
    assert_includes lock_tables, :child
  end

  test "identity scope walks each Base Browser Session" do
    other_root = ClientToken.create!(user: Client.create!)
    other_session = ClientRpSession.create!(
      client_token: other_root,
      oidc_client_id: "core-app",
      oidc_scope: "openid profile",
      refresh_token_expires_at: 1.hour.from_now,
    )

    result = RpSessionRevoker.call(scope: :identity, record: [@root, other_root])

    assert_predicate result, :success?
    assert_operator result.revoked_count, :>=, 3
    assert_predicate @session_a.reload, :revoked?
    assert_predicate @session_b.reload, :revoked?
    assert_predicate other_session.reload, :revoked?
  end

  test "browser_session scope revokes a visitor session's RP Sessions and the visitor token" do
    visitor_root = VisitorToken.create!(visitor: Visitor.create!(status_id: VisitorStatus::ACTIVE))
    visitor_session = VisitorRpSession.create!(
      visitor_token: visitor_root,
      oidc_client_id: "core-com",
      oidc_scope: "openid profile",
      refresh_token_expires_at: 1.hour.from_now,
    )

    result = RpSessionRevoker.call(scope: :browser_session, record: visitor_root)

    assert_equal 1, result.revoked_count
    assert_predicate visitor_session.reload, :revoked?
    assert_predicate visitor_root.reload, :revoked?
  end

  test "browser_session scope revokes an operator session's RP Sessions and the operator token" do
    operator_root = OperatorToken.create!(staff_id: Operator.create!(status_id: OperatorStatus::ACTIVE).id)
    operator_session = OperatorRpSession.create!(
      operator_token: operator_root,
      oidc_client_id: "core-org",
      oidc_scope: "openid profile",
      refresh_token_expires_at: 1.hour.from_now,
    )

    result = RpSessionRevoker.call(scope: :browser_session, record: operator_root)

    assert_equal 1, result.revoked_count
    assert_predicate operator_session.reload, :revoked?
    assert_predicate operator_root.reload, :revoked?
  end

  test "browser_session scope rejects a record that is not a Base Browser Session" do
    error =
      assert_raises(ArgumentError) do
        RpSessionRevoker.call(scope: :browser_session, record: @session_a)
      end

    assert_includes error.message, "ClientRpSession"
    assert_not @session_a.reload.revoked?
  end

  test "identity scope rejects a record that is not enumerable" do
    assert_raises(ArgumentError) do
      RpSessionRevoker.call(scope: :identity, record: @root)
    end

    assert_not @session_a.reload.revoked?
  end

  test "rejects an unsupported revoke scope" do
    error =
      assert_raises(ArgumentError) do
        RpSessionRevoker.call(scope: :organization, record: @root)
      end

    assert_includes error.message, ":organization"
    assert_not @session_a.reload.revoked?
  end
end
