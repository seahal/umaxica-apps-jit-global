# typed: false
# frozen_string_literal: true

require "test_helper"

# OidcRefreshTokenIssuer serves all three surfaces from one code path, and every
# actor-dependent step -- the usage lookup, the risk-event actor key, and the
# connection touch -- dispatches on the parent token class. The client surface is
# already pinned by Security::Invariants::RefreshTokenReuseInvariantTest; these
# tests pin the staff and visitor branches so a surface cannot silently drop out
# of rotation or out of reuse reporting.
class OidcRefreshTokenIssuerSurfaceTest < ActiveSupport::TestCase
  fixtures :operators, :operator_statuses, :operator_token_kinds, :operator_token_statuses,
           :operator_token_binding_methods, :operator_token_dbsc_statuses,
           :visitors, :visitor_statuses, :visitor_token_kinds, :visitor_token_statuses,
           :visitor_token_binding_methods, :visitor_token_dbsc_statuses

  test "a staff refresh token rotates and touches the staff connection" do
    operator = operators(:one)
    token = OperatorToken.create!(
      staff: operator,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      discarded_at: 1.day.from_now,
    )
    connection = OperatorOidcConnection.create!(
      staff: operator, client_id: "org-console-rp", last_used_at: 3.days.ago,
    )
    usage = OperatorTokenUsage.create!(operator_token: token, oidc_client_id: "org-console-rp")
    refresh_token = usage.issue_refresh_token!

    result = OidcRefreshTokenIssuer.call(refresh_token: refresh_token)

    assert_predicate result, :success?
    assert_equal usage.id, result.token.id
    assert_operator connection.reload.last_used_at, :>, 1.minute.ago
  end

  test "replaying a staff refresh token is reported as reuse against the staff id" do
    operator = operators(:one)
    token = OperatorToken.create!(
      staff: operator,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      discarded_at: 1.day.from_now,
    )
    usage = OperatorTokenUsage.create!(operator_token: token, oidc_client_id: "org-console-rp")
    replayed = usage.issue_refresh_token!

    assert_predicate OidcRefreshTokenIssuer.call(refresh_token: replayed), :success?

    emitted = []
    SignRiskEmitter.stub(:emit, ->(name, **attrs) { emitted << [name, attrs] }) do
      result = OidcRefreshTokenIssuer.call(refresh_token: replayed)

      assert_not result.success?
      assert_equal :refresh_token_reuse_detected, result.reason
    end

    assert_predicate usage.reload, :revoked?
    assert_equal [["refresh_reuse_detected", { staff_id: operator.id, user_token_id: usage.public_id }]],
                 emitted
    audit = ChronicleRecord.connected_to(role: :writing) do
      OperatorChronicle.where(
        event_id: OperatorChronicleEvent::REFRESH_TOKEN_REUSE_DETECTED,
        subject_id: operator.id.to_s,
        subject_type: "Operator",
      ).order(occurred_at: :desc).first
    end
    assert_predicate audit, :present?
    assert_equal "token_usage_revoked", audit.context.deep_stringify_keys.fetch("result")
  end

  test "a visitor refresh token rotates and touches the visitor connection" do
    visitor = visitors(:reserved_visitor)
    token = VisitorToken.create!(
      visitor: visitor,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      discarded_at: 1.day.from_now,
    )
    connection = VisitorOidcConnection.create!(
      visitor: visitor, client_id: "com-portal-rp", last_used_at: 3.days.ago,
    )
    usage = VisitorTokenUsage.create!(visitor_token: token, oidc_client_id: "com-portal-rp")
    refresh_token = usage.issue_refresh_token!

    result = OidcRefreshTokenIssuer.call(refresh_token: refresh_token)

    assert_predicate result, :success?
    assert_equal usage.id, result.token.id
    assert_operator connection.reload.last_used_at, :>, 1.minute.ago
  end

  test "replaying a visitor refresh token is reported as reuse against the visitor id" do
    visitor = visitors(:reserved_visitor)
    token = VisitorToken.create!(
      visitor: visitor,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      discarded_at: 1.day.from_now,
    )
    usage = VisitorTokenUsage.create!(visitor_token: token, oidc_client_id: "com-portal-rp")
    replayed = usage.issue_refresh_token!

    assert_predicate OidcRefreshTokenIssuer.call(refresh_token: replayed), :success?

    emitted = []
    SignRiskEmitter.stub(:emit, ->(name, **attrs) { emitted << [name, attrs] }) do
      result = OidcRefreshTokenIssuer.call(refresh_token: replayed)

      assert_not result.success?
      assert_equal :refresh_token_reuse_detected, result.reason
    end

    assert_predicate usage.reload, :revoked?
    assert_equal [["refresh_reuse_detected", { visitor_id: visitor.id, user_token_id: usage.public_id }]],
                 emitted
    audit = ChronicleRecord.connected_to(role: :writing) do
      ClientChronicle.where(
        event_id: ClientChronicleEvent::REFRESH_TOKEN_REUSE_DETECTED,
        subject_id: visitor.id.to_s,
        subject_type: "Visitor",
      ).order(occurred_at: :desc).first
    end
    assert_predicate audit, :present?
    assert_equal "token_usage_revoked", audit.context.deep_stringify_keys.fetch("result")
  end
end
