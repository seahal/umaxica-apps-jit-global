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
    ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::ACTIVE)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::NOTHING)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    VisitorTokenBindingMethod.ensure_defaults!
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
    OperatorTokenKind.find_or_create_by!(id: OperatorTokenKind::BROWSER_WEB)
    OperatorTokenStatus.find_or_create_by!(id: OperatorTokenStatus::NOTHING)
    OperatorTokenStatus.find_or_create_by!(id: OperatorTokenStatus::ACTIVE)
    OperatorTokenBindingMethod.ensure_defaults!
    OperatorTokenDbscStatus.find_or_create_by!(id: OperatorTokenDbscStatus::NOTHING)
  end

  test "revokes every session except the current one for a client" do
    client = client_without_sessions
    current = create_client_token(client)
    other = create_client_token(client)
    requirement = grant_step_up!(client, current)

    result = AuthenticationOtherSessionsRevoker.call(
      owner: client,
      sessions: client.client_tokens.session_inventory,
      current_token: current,
      current_session_public_id: current.public_id,
      step_up_requirement: requirement,
    )

    assert_predicate result, :success?
    assert_equal [other.public_id], result.revoked_tokens.map(&:public_id)
    assert_not_predicate other.reload, :currently_usable?
    assert_predicate current.reload, :currently_usable?
    assert_nil current.last_step_up_at
  end

  # A44-10 (D-167): the revocation is point-in-time. A session that commits after the request was
  # decided (here: created after the revoker's database clock reading) survives.
  test "a session created after the revocation request survives" do
    client = client_without_sessions
    current = create_client_token(client)
    existing = create_client_token(client)
    later = create_client_token(client)
    later.update_columns(created_at: ClientToken.database_now + 1.minute)
    requirement = grant_step_up!(client, current)

    result = AuthenticationOtherSessionsRevoker.call(
      owner: client,
      sessions: client.client_tokens.session_inventory,
      current_token: current,
      current_session_public_id: current.public_id,
      step_up_requirement: requirement,
    )

    assert_predicate result, :success?
    assert_equal [existing.public_id], result.revoked_tokens.map(&:public_id)
    assert_not_predicate existing.reload, :currently_usable?
    assert_predicate later.reload, :currently_usable?
  end

  test "revokes every session except the current one for an operator" do
    operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus.find_or_create_by!(id: OperatorStatus::ACTIVE).id,
    )
    current = create_operator_token(operator)
    other = create_operator_token(operator)
    requirement = grant_step_up!(operator, current)

    result = AuthenticationOtherSessionsRevoker.call(
      owner: operator,
      sessions: operator.staff_tokens.session_inventory,
      current_token: current,
      current_session_public_id: current.public_id,
      step_up_requirement: requirement,
    )

    assert_equal [other.public_id], result.revoked_tokens.map(&:public_id)
    assert_not_predicate other.reload, :currently_usable?
    assert_predicate current.reload, :currently_usable?
  end

  test "revokes every session except the current one for a visitor" do
    visitor = create_visitor
    current = create_visitor_token(visitor)
    other = create_visitor_token(visitor)
    requirement = grant_step_up!(visitor, current)

    result = AuthenticationOtherSessionsRevoker.call(
      owner: visitor,
      sessions: visitor.visitor_tokens.session_inventory,
      current_token: current,
      current_session_public_id: current.public_id,
      step_up_requirement: requirement,
    )

    assert_equal [other.public_id], result.revoked_tokens.map(&:public_id)
    assert_not_predicate other.reload, :currently_usable?
    assert_predicate current.reload, :currently_usable?
  end

  test "revokes nothing when the current session is the only one" do
    client = client_without_sessions
    current = create_client_token(client)
    requirement = grant_step_up!(client, current)

    result = AuthenticationOtherSessionsRevoker.call(
      owner: client,
      sessions: client.client_tokens.session_inventory,
      current_token: current,
      current_session_public_id: current.public_id,
      step_up_requirement: requirement,
    )

    assert_predicate result, :success?
    assert_empty result.revoked_tokens
    assert_predicate current.reload, :currently_usable?
    assert_not_nil current.last_step_up_at
  end

  test "refuses revocation when the current token instance is missing" do
    client = client_without_sessions
    current = create_client_token(client)
    other = create_client_token(client)
    requirement = grant_step_up!(client, current)

    assert_raises(AuthenticationOtherSessionsRevoker::Denied) do
      AuthenticationOtherSessionsRevoker.call(
        owner: client,
        sessions: client.client_tokens.session_inventory,
        current_session_public_id: current.public_id,
        step_up_requirement: requirement,
      )
    end

    assert_predicate current.reload, :currently_usable?
    assert_predicate other.reload, :currently_usable?
  end

  test "each surface consumes one proof per successful revocation and requires a new proof for the next write" do
    pairs = []
    client = client_without_sessions
    client_token = create_client_token(client)
    pairs << [client, client_token, create_client_token(client), -> { create_client_token(client) }]

    visitor = create_visitor
    visitor_token = create_visitor_token(visitor)
    pairs << [visitor, visitor_token, create_visitor_token(visitor), -> { create_visitor_token(visitor) }]

    operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus.find_or_create_by!(id: OperatorStatus::ACTIVE).id,
    )
    operator_token = create_operator_token(operator)
    pairs << [operator, operator_token, create_operator_token(operator), -> { create_operator_token(operator) }]

    pairs.each do |owner, current, first_other, create_other|
      requirement = grant_step_up!(owner, current)
      result = AuthenticationOtherSessionsRevoker.call(
        owner: owner, sessions: token_relation_for(owner), current_token: current,
        current_session_public_id: current.public_id, step_up_requirement: requirement,
      )

      assert_equal [first_other.public_id], result.revoked_tokens.map(&:public_id)
      assert_nil current.reload.last_step_up_at

      second_other = create_other.call
      assert_raises(AuthenticationOtherSessionsRevoker::StepUpUnavailable) do
        AuthenticationOtherSessionsRevoker.call(
          owner: owner, sessions: token_relation_for(owner), current_token: current,
          current_session_public_id: current.public_id, step_up_requirement: requirement,
        )
      end
      assert_predicate second_other.reload, :currently_usable?

      next_requirement = grant_step_up!(owner, current)
      result = AuthenticationOtherSessionsRevoker.call(
        owner: owner, sessions: token_relation_for(owner), current_token: current,
        current_session_public_id: current.public_id, step_up_requirement: next_requirement,
      )

      assert_equal [second_other.public_id], result.revoked_tokens.map(&:public_id)
      assert_nil current.reload.last_step_up_at
    end
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
      authentication_epoch: 0,
      user: client,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      public_id: PublicId.generate,
      discard_at: 1.day.from_now,
    )
  end

  def create_operator_token(operator)
    OperatorToken.create!(
      authentication_epoch: 0,
      staff: operator,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      public_id: PublicId.generate,
      discard_at: 1.day.from_now,
    )
  end

  def create_visitor
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    Visitor.create!(
      status_id: VisitorStatus::NOTHING,
      visibility_id: VisitorVisibility::VISITOR,
      security_mode_id: SecurityModeConfigurable::NORMAL,
      mfa_status_id: VisitorMfaStatus::UNCONFIGURED,
    )
  end

  def create_visitor_token(visitor)
    VisitorToken.create!(
      authentication_epoch: 0,
      visitor: visitor,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      public_id: PublicId.generate,
      discard_at: 1.day.from_now,
    )
  end

  def token_relation_for(owner)
    case owner
    when Client then owner.client_tokens.session_inventory
    when Visitor then owner.visitor_tokens.session_inventory
    when Operator then owner.staff_tokens.session_inventory
    else raise ArgumentError, "unsupported session owner"
    end
  end

  def grant_step_up!(owner, token)
    surface = owner.is_a?(Client) ? "app" : (owner.is_a?(Visitor) ? "com" : "org")
    methods = owner.is_a?(Operator) ? [:passkey] : %i(passkey totp email_otp)
    now = token.class.database_now
    token.update!(
      last_step_up_at: now, last_step_up_scope: "session_revoke_all", last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:#{surface}", last_step_up_phishing_resistant: false,
      last_step_up_user_verified: false, last_step_up_credential_ref: "test-step-up",
      last_step_up_full_reauthentication: false,
    )
    StepUpRequirement.new(
      scope: "session_revoke_all", step_up_required: true, allowed_methods: methods,
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, purpose: "step_up", audience: "step_up:#{surface}",
      session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
      ttl: StepUpRequirement::DEFAULT_TTL, actor_ref: owner.public_id, resource_ref: nil, tenant_ref: nil,
    )
  end
end
