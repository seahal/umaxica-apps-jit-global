# typed: false
# frozen_string_literal: true

require "test_helper"

# The shared "revoke every session except this one" primitive behind the three
# surfaces' `Identity::Revocations::Others` controllers. Covers the operator
# actor as well, whose HTTP path is not reachable in an integration test
# without a full OIDC RP browser session.
class AuthenticationOtherSessionsRevokerTest < ActiveSupport::TestCase
  fixtures :clients

  setup do
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::NOTHING)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::NOTHING)
    VisitorTokenBindingMethod.ensure_defaults!
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
    OperatorTokenKind.find_or_create_by!(id: OperatorTokenKind::BROWSER_WEB)
    OperatorTokenStatus.find_or_create_by!(id: OperatorTokenStatus::NOTHING)
    OperatorTokenBindingMethod.ensure_defaults!
    OperatorTokenDbscStatus.find_or_create_by!(id: OperatorTokenDbscStatus::NOTHING)
  end

  test "revokes every session except the current one for a client" do
    client = client_without_sessions
    current = create_client_token(client)
    other = create_client_token(client)

    result = AuthenticationOtherSessionsRevoker.call(
      owner: client,
      sessions: client.client_tokens.session_inventory,
      current_token: current,
      current_session_public_id: current.public_id,
    )

    assert_predicate result, :success?
    assert_equal [other.public_id], result.revoked_tokens.map(&:public_id)
    assert_not_predicate other.reload, :currently_usable?
    assert_predicate current.reload, :currently_usable?
  end

  test "revokes every session except the current one for an operator" do
    operator = Operator.create!(status_id: OperatorStatus.find_or_create_by!(id: OperatorStatus::ACTIVE).id)
    current = create_operator_token(operator)
    other = create_operator_token(operator)

    result = AuthenticationOtherSessionsRevoker.call(
      owner: operator,
      sessions: operator.staff_tokens.session_inventory,
      current_token: current,
      current_session_public_id: current.public_id,
    )

    assert_equal [other.public_id], result.revoked_tokens.map(&:public_id)
    assert_not_predicate other.reload, :currently_usable?
    assert_predicate current.reload, :currently_usable?
  end

  test "revokes every session except the current one for a visitor" do
    visitor = create_visitor
    current = create_visitor_token(visitor)
    other = create_visitor_token(visitor)

    result = AuthenticationOtherSessionsRevoker.call(
      owner: visitor,
      sessions: visitor.visitor_tokens.session_inventory,
      current_token: current,
      current_session_public_id: current.public_id,
    )

    assert_equal [other.public_id], result.revoked_tokens.map(&:public_id)
    assert_not_predicate other.reload, :currently_usable?
    assert_predicate current.reload, :currently_usable?
  end

  test "revokes nothing when the current session is the only one" do
    client = client_without_sessions
    current = create_client_token(client)

    result = AuthenticationOtherSessionsRevoker.call(
      owner: client,
      sessions: client.client_tokens.session_inventory,
      current_token: current,
      current_session_public_id: current.public_id,
    )

    assert_predicate result, :success?
    assert_empty result.revoked_tokens
    assert_predicate current.reload, :currently_usable?
  end

  test "matches the current session by public id when no token instance is given" do
    client = client_without_sessions
    current = create_client_token(client)
    other = create_client_token(client)

    AuthenticationOtherSessionsRevoker.call(
      owner: client,
      sessions: client.client_tokens.session_inventory,
      current_session_public_id: current.public_id,
    )

    assert_predicate current.reload, :currently_usable?
    assert_not_predicate other.reload, :currently_usable?
  end

  private

  # The client fixture ships with a session row; start from a clean inventory
  # so the assertions describe only the sessions this test creates.
  def client_without_sessions
    client = clients(:one)
    client.client_tokens.find_each(&:revoke!)
    client
  end

  def create_client_token(client)
    ClientToken.create!(
      user: client,
      user_token_status_id: ClientTokenStatus::NOTHING,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      public_id: "others_#{SecureRandom.hex(4)}",
      discard_at: 1.day.from_now,
    )
  end

  def create_operator_token(operator)
    OperatorToken.create!(
      staff: operator,
      staff_token_status_id: OperatorTokenStatus::NOTHING,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      public_id: "others_#{SecureRandom.hex(4)}",
      discard_at: 1.day.from_now,
    )
  end

  def create_visitor
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    Visitor.create!(
      status_id: VisitorStatus::NOTHING,
      visibility_id: VisitorVisibility::VISITOR,
      mfa_level_id: VisitorMfaLevel::NOTHING,
      mfa_status_id: VisitorMfaStatus::UNCONFIGURED,
    )
  end

  def create_visitor_token(visitor)
    VisitorToken.create!(
      visitor: visitor,
      visitor_token_status_id: VisitorTokenStatus::NOTHING,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      public_id: "others_#{SecureRandom.hex(4)}",
      discard_at: 1.day.from_now,
    )
  end
end
