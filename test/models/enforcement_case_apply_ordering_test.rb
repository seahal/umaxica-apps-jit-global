# typed: false
# frozen_string_literal: true

require "test_helper"

# adr/unified-enforcement.md: apply! commits the state change in a transaction and then performs
# its side effects outside it, deliberately. A committed security decision must never be rolled
# back because a downstream effect failed, and end_case! must not release a lock another Case is
# still holding.
#
# These are the two guarantees that survive no matter where apply! and end_case! live, so they are
# pinned before #871 moves them into app/operations. Both use real failures rather than stubbed
# collaborators, per generic/no-test-only-code.mdc.
class EnforcementCaseApplyOrderingTest < ActiveSupport::TestCase
  test "reconciling a released Case does not clear a later administrative lock" do
    client = clients(:one)
    operator = operators(:one)
    the_case = blocking_case_for(client, operator_public_id: operator.public_id)
    EnforcementCaseApplyOperation.call(enforcement_case: the_case, actor_operator_public_id: operator.public_id)
    EnforcementCaseEndOperation.call(enforcement_case: the_case, reason: "revoked")
    AdministrativeAccessLock.lock!(account: client, operator: operator, reason_code: "security_incident")

    EnforcementCaseEndOperation.new(enforcement_case: the_case, reason: "revoked").reconcile

    assert_predicate client.reload, :admin_locked?
  end

  test "end reconciliation retries a missing release audit after unlock committed" do
    client = clients(:one)
    operator = operators(:one)
    the_case = blocking_case_for(client, operator_public_id: operator.public_id)
    EnforcementCaseApplyOperation.call(enforcement_case: the_case, actor_operator_public_id: operator.public_id)

    AccountAccessEvent.stub(:create!, ->(**) { raise ActiveRecord::RecordNotUnique }) do
      assert_raises(ActiveRecord::RecordNotUnique) do
        EnforcementCaseEndOperation.call(enforcement_case: the_case, reason: "revoked")
      end
    end

    assert_predicate client.reload, :access_enabled?
    assert_predicate the_case.reload.ended_at, :present?
    EnforcementCaseEndOperation.new(enforcement_case: the_case, reason: "revoked").reconcile

    assert_predicate AccountAccessEvent.where(
      account_type: "Client", account_id: client.id, event_type: AccountAccessEvent::EVENT_TYPE_ADMIN_UNLOCK,
    ).where("metadata @> ?::jsonb", { enforcement_case_public_id: the_case.public_id }.to_json), :exists?
  end

  test "reconciling an already released Case does not advance the account token cutoff" do
    client = clients(:one)
    operator = operators(:one)
    the_case = blocking_case_for(client, operator_public_id: operator.public_id)
    EnforcementCaseApplyOperation.call(enforcement_case: the_case, actor_operator_public_id: operator.public_id)
    EnforcementCaseEndOperation.call(enforcement_case: the_case, reason: "revoked")
    cutoff = client.reload.token_valid_after_at
    release_events = AccountAccessEvent.where(
      account_type: "Client", account_id: client.id, event_type: AccountAccessEvent::EVENT_TYPE_ADMIN_UNLOCK,
    )

    travel 1.second do
      assert_no_difference -> { release_events.count } do
        EnforcementCaseEndOperation.new(enforcement_case: the_case, reason: "revoked").reconcile
      end
    end

    assert_equal cutoff, client.reload.token_valid_after_at
  end

  test "a side effect failing after the transaction leaves the case active" do
    client = clients(:one)

    # A real failure with no stubbing: perform_principal_access_effect! resolves the operator with
    # find_by!, and presence is all the model validates about that column.
    the_case = blocking_case_for(client, operator_public_id: "operator-that-does-not-exist")

    assert_raises(ActiveRecord::RecordNotFound) { EnforcementCaseApplyOperation.call(enforcement_case: the_case, actor_operator_public_id: the_case.applied_by_operator_public_id) }

    the_case.reload

    assert_equal "active", the_case.state,
                 "the state change committed before the side effect ran and must not be rolled back"
    assert_nil the_case.sessions_revoked_at, "the raise happened before the later side effects"
    assert_not_predicate client.reload, :admin_locked?
  end

  test "end_case! leaves the account locked while another blocking case is still in force" do
    client = clients(:one)
    operator = operators(:one)

    first = blocking_case_for(client, operator_public_id: operator.public_id)
    EnforcementCaseApplyOperation.call(
      enforcement_case: first,
      actor_operator_public_id: first.applied_by_operator_public_id,
    )
    second = blocking_case_for(client, operator_public_id: operator.public_id)
    EnforcementCaseApplyOperation.call(
      enforcement_case: second,
      actor_operator_public_id: second.applied_by_operator_public_id,
    )

    assert_predicate client.reload, :admin_locked?

    step_up_now = OpBaseOrgRecord.database_now
    step_up_token = OperatorToken.create!(
      authentication_epoch: operator.authentication_epoch,
      staff: operator,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      discard_at: step_up_now + 1.hour,
    )
    step_up_token.update!(root_login_established_at: step_up_now, established_authentication_method: "passkey")
    step_up_token.rotate_refresh_token!(now: step_up_now)
    step_up_token.device_session_record!
    step_up_client = OidcClientRegistry.find!("base-org-ww")
    step_up_auth_time = step_up_now.to_i - 1
    step_up_grant = OpOrgGrant.create!(
      authentication_epoch: step_up_token.authentication_epoch,
      operator_token: step_up_token,
      oidc_client_id: step_up_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: step_up_now + 1.hour,
    )
    step_up_grant.issue_refresh_token!(now: step_up_now)
    step_up_evidence = StepUpEvidenceValue.new(
      acr: step_up_grant.oidc_acr,
      amr: ["passkey"],
      auth_time: step_up_auth_time,
      sid: step_up_grant.public_id,
      sub: OidcSubject.for(operator, resource_type: "operator"),
      client_id: step_up_client.client_id,
      aud: [step_up_client.aud],
      jti: step_up_grant.oidc_jti,
    )

    EnforcementCaseEndOperation.call(
      enforcement_case: first, reason: "revoked",
      ended_by_operator_public_id: operator.public_id,
      step_up_token: step_up_token, step_up_actor: operator, step_up_evidence: step_up_evidence,
    )

    assert_predicate client.reload, :admin_locked?,
                     "the refcount rule: the second Case still holds the lock"

    EnforcementCaseEndOperation.call(
      enforcement_case: second, reason: "revoked",
      ended_by_operator_public_id: operator.public_id,
      step_up_token: step_up_token, step_up_actor: operator, step_up_evidence: step_up_evidence,
    )

    assert_not_predicate client.reload, :admin_locked?
  end

  private

  def blocking_case_for(client, operator_public_id:)
    the_case = AppEnforcementCase.new(
      kind: "temporary_freeze",
      duration_mode: "timed",
      visibility: "visible",
      release_mode: "operator",
      effective_at: Time.current,
      expires_at: 1.day.from_now,
      reason_code: "security_incident",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator_public_id,
    )
    the_case.build_principal_effect(
      principal_public_id: client.public_id,
      access_blocking: true,
      effective_at: Time.current,
    )
    the_case
  end
end
