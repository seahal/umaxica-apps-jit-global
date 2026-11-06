# frozen_string_literal: true

require "test_helper"

class EnforcementCaseApplyFailureTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  self.use_transactional_tests = false

  setup do
    @existing_app_case_ids = AppEnforcementCase.pluck(:id)
    @existing_org_case_ids = OrgEnforcementCase.pluck(:id)
    @existing_operator_ids = Operator.pluck(:id)
    @existing_operator_token_ids = OperatorToken.pluck(:id)
    @existing_capability_grant_ids = OperatorCapabilityGrant.pluck(:id)
    @existing_client_ids = Client.pluck(:id)
    @existing_operator_device_session_ids = OperatorDeviceSession.pluck(:id)
    @existing_op_org_grant_ids = OpOrgGrant.pluck(:id)
    @existing_enforcement_event_ids = EnforcementEvent.pluck(:id)
  end

  teardown do
    EnforcementEvent.where.not(id: @existing_enforcement_event_ids).delete_all
    AppEnforcementCase.where.not(id: @existing_app_case_ids).delete_all
    OrgEnforcementCase.where.not(id: @existing_org_case_ids).delete_all
    OpOrgGrant.where.not(id: @existing_op_org_grant_ids).delete_all
    OperatorDeviceSession.where.not(id: @existing_operator_device_session_ids).update_all(current_refresh_token_id: nil)
    OperatorCapabilityGrant.where.not(id: @existing_capability_grant_ids).delete_all
    OperatorToken.where.not(id: @existing_operator_token_ids).delete_all
    OperatorDeviceSession.where.not(id: @existing_operator_device_session_ids).delete_all
    Client.where.not(id: @existing_client_ids).delete_all
    created_operator_ids = Operator.where.not(id: @existing_operator_ids).pluck(:id)
    OperatorAuthorityLock.where(operator_id: created_operator_ids).delete_all
    OperatorAccount.where(staff_id: created_operator_ids).delete_all
    Operator.where.not(id: @existing_operator_ids).delete_all
  end

  [AppEnforcementCase, OrgEnforcementCase].each do |case_class|
    test "#{case_class.name} reports a missing principal after committing the decision" do
      enforcement_case = case_class.new(
        kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
        release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
        principal_public_id: SecureRandom.uuid, applied_by_operator_public_id: "apply-test-operator",
      )

      assert_raises(ActiveRecord::RecordNotFound) do
        EnforcementCaseApplyOperation.call(
          enforcement_case: enforcement_case, actor_operator_public_id: "apply-test-operator",
        )
      end
      assert_equal "active", enforcement_case.reload.state
      assert_nil enforcement_case.sessions_revoked_at
      assert_nil enforcement_case.audited_at
      assert case_class.pending_convergence.exists?(id: enforcement_case.id)
    end
  end

  test "unavailable Step-Up evidence rolls the Case decision back" do
    operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP, OperatorCapabilityGrant::ENFORCEMENT_APPLY_APP].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: operator, origin: "bootstrap", capability: capability, reason_code: "bootstrap",
        starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    token = OperatorToken.create!(
      authentication_epoch: operator.authentication_epoch,
      staff_id: operator.id,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    enforcement_case = AppEnforcementCase.create!(
      kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: client.public_id, applied_by_operator_public_id: operator.public_id,
    )
    rp_client = OidcClientRegistry.find!("base-org-ww")
    evidence = StepUpEvidenceValue.new(
      acr: StepUpEvidenceResolver::STEP_UP_ACR,
      amr: ["passkey"],
      auth_time: OpBaseOrgRecord.database_now.to_i,
      sid: SecureRandom.uuid,
      sub: OidcSubject.for(operator, resource_type: "operator"),
      client_id: rp_client.client_id,
      aud: [rp_client.aud],
      jti: SecureRandom.uuid,
    )

    assert_raises(TokenStatusManagement::StepUpEvidenceUnavailable) do
      EnforcementCaseApplyOperation.call(
        enforcement_case: enforcement_case,
        actor_operator_public_id: operator.public_id,
        step_up_token: token,
        step_up_actor: operator,
        step_up_evidence: evidence,
        authorization_rule: :create,
      )
    end

    assert_equal "draft", enforcement_case.reload.state
    assert_nil enforcement_case.audited_at
    assert_not AppEnforcementCase.pending_convergence.exists?(id: enforcement_case.id)
  end

  test "a current Step-Up applies the Case with actor and OP locks held through commit" do
    operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP, OperatorCapabilityGrant::ENFORCEMENT_APPLY_APP].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: operator, origin: "bootstrap", capability: capability, reason_code: "bootstrap",
        starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    token = OperatorToken.create!(
      authentication_epoch: operator.authentication_epoch,
      staff: operator,
      root_login_established_at: Time.current,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
    now = OpBaseOrgRecord.database_now
    token.rotate_refresh_token!(now:)
    token.device_session_record!
    client = OidcClientRegistry.find!("base-org-ww")
    grant = OpOrgGrant.create!(
      authentication_epoch: token.authentication_epoch,
      operator_token: token,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(now.to_time.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 10.minutes,
    )
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr,
      amr: ["passkey"],
      auth_time: grant.oidc_auth_time.to_i,
      sid: grant.public_id,
      sub: OidcSubject.for(operator, resource_type: "operator"),
      client_id: client.client_id,
      aud: [client.aud],
      jti: grant.oidc_jti,
    )
    client_account = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    enforcement_case = AppEnforcementCase.create!(
      kind: "cooldown", state: "draft", duration_mode: "timed", visibility: "visible",
      release_mode: "automatic", effective_at: Time.current, expires_at: 1.day.from_now,
      reason_code: "abuse", principal_public_id: client_account.public_id,
      applied_by_operator_public_id: operator.public_id,
    )

    assert EnforcementCaseApplyOperation.call(
      enforcement_case: enforcement_case,
      actor_operator_public_id: operator.public_id,
      step_up_token: token,
      step_up_actor: operator,
      step_up_evidence: evidence,
      authorization_rule: :create,
    )

    assert_equal "active", enforcement_case.reload.state
    assert EnforcementEvent.exists?(case_public_id: enforcement_case.public_id, event_type: "applied")
    assert_equal 0, Operator.connection.open_transactions
    assert_equal 0, OpBaseOrgRecord.connection.open_transactions
  end

  test "a rejected post-commit effect keeps the committed Case in force for reconciliation" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    enforcement_case = AppEnforcementCase.create!(
      kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: client.public_id, applied_by_operator_public_id: "apply-test-operator",
    )

    enforcement_case.stub(:revoke_method_sessions!, -> { raise ActiveRecord::RecordNotUnique }) do
      assert_raises(ActiveRecord::RecordNotUnique) do
        EnforcementCaseApplyOperation.call(
          enforcement_case: enforcement_case,
          actor_operator_public_id: "apply-test-operator",
        )
      end
    end

    assert_equal "active", enforcement_case.reload.state
    assert AppEnforcementCase.in_force.exists?(id: enforcement_case.id)
    assert AppEnforcementCase.pending_convergence.exists?(id: enforcement_case.id)
  end

  test "a new Case outside the applicable states is not persisted" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    enforcement_case = AppEnforcementCase.new(
      kind: "security_lock", state: "failed", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: client.public_id, applied_by_operator_public_id: "apply-test-operator",
    )

    assert_no_difference "AppEnforcementCase.count" do
      assert_raises(EnforcementCaseApplicable::InvalidStateTransitionError) do
        EnforcementCaseApplyOperation.call(
          enforcement_case: enforcement_case,
          actor_operator_public_id: "apply-test-operator",
        )
      end
    end
    assert_not_predicate enforcement_case, :persisted?
  end
end
