# typed: false
# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

# adr/operator-capability-authorization.md, Access lock and Enforcement: what an approval leaves
# behind when it fails at each point, and who each enforcement event names. Operator A opens, B
# approves, C releases or reviews; every event must name the operator who performed it.
class Base::Org::Support::EnforcementApprovalFailuresTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "www.umaxica.org")
    @operator_a = operators(:one)
    @operator_b = operators(:two)
    @operator_c = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    @client = clients(:one)
    @tokens =
      [@operator_a, @operator_b, @operator_c].to_h do |operator|
        token = OperatorToken.create!(
          staff_id: operator.id, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
          staff_token_status_id: OperatorTokenStatus::ACTIVE,
          staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
          staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
        )
        [operator, token]
      end
    # Step-Up state is written directly here; test/integration/org_admin_step_up_ceremony_test.rb
    # covers the real ceremony. Each operator holds exactly the capability it uses.
    {
      @operator_a => [OperatorCapabilityGrant::ENFORCEMENT_APPLY_APP, "enforcement_case_apply"],
      @operator_b => [OperatorCapabilityGrant::ENFORCEMENT_APPROVE_APP, "enforcement_case_approve"],
      @operator_c => [OperatorCapabilityGrant::ENFORCEMENT_RELEASE_APP, "enforcement_case_release"],
    }.each do |operator, (capability, scope)|
      [OperatorCapabilityGrant::ENFORCEMENT_READ_APP, capability].each do |granted|
        OperatorCapabilityGrant.create!(
          operator: operator, origin: "bootstrap", capability: granted,
          reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
        )
      end
      token = @tokens.fetch(operator)
      token.update_columns( # rubocop:disable Rails/SkipsModelValidations
        last_step_up_at: Time.current, last_step_up_scope: scope, last_step_up_aal: "aal2",
        last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
        last_step_up_purpose: "step_up", last_step_up_audience: "step_up:org",
      )
    end
    @pending = AppEnforcementCase.create!(
      kind: "permanent_ban", duration_mode: "permanent", visibility: "hidden", release_mode: "break_glass_only",
      effective_at: Time.current, reason_code: "abuse", principal_public_id: @client.public_id,
      applied_by_operator_public_id: @operator_a.public_id, state: "pending_approval",
    )
  end

  test "failure before the claim: a case that is not pending is refused and left unchanged" do
    @pending.update_columns(state: "failed") # rubocop:disable Rails/SkipsModelValidations

    post base_org_support_app_enforcement_case_approval_url(@pending.public_id, host: @host),
         params: { principal_effect: { access_blocking: true } },
         headers: as_staff_headers(@operator_b, host: @host, session_public_id: @tokens.fetch(@operator_b).public_id),
         as: :json

    assert_response :conflict
    assert_nil @pending.reload.approved_by_operator_public_id
  end

  test "failure after the claim but before the apply starts releases the claim" do
    fails_before_start = ->(**) { raise ArgumentError, "apply did not start" }

    EnforcementCaseApplyOperation.stub(:call, fails_before_start) do
      post base_org_support_app_enforcement_case_approval_url(@pending.public_id, host: @host),
           params: { principal_effect: { access_blocking: true } },
           headers: as_staff_headers(@operator_b, host: @host, session_public_id: @tokens.fetch(@operator_b).public_id),
           as: :json
    end

    assert_response :unprocessable_content
    @pending.reload

    assert_equal "pending_approval", @pending.state
    assert_nil @pending.approved_by_operator_public_id
    assert_not_predicate @client.reload, :admin_locked?
    assert_not EnforcementEvent.exists?(case_public_id: @pending.public_id)
  end

  test "failure while persisting effects rolls the apply back entirely and releases the claim" do
    post base_org_support_app_enforcement_case_approval_url(@pending.public_id, host: @host),
         params: {
           principal_effect: { access_blocking: true },
           authentication_method_effect: { authentication_method: "not-a-method", effect: "unusable" },
         },
         headers: as_staff_headers(@operator_b, host: @host, session_public_id: @tokens.fetch(@operator_b).public_id),
         as: :json

    assert_response :unprocessable_content
    @pending.reload

    assert_equal "pending_approval", @pending.state
    assert_nil @pending.approved_by_operator_public_id
    assert_not_predicate @client.reload, :admin_locked?
    assert_nil @pending.principal_effect, "the effect rows rolled back with the state change"
    assert_not EnforcementEvent.exists?(case_public_id: @pending.public_id)
  end

  test "failure in the lock after the state change commits marks the Case failed and keeps the approver" do
    lock_fails = ->(**) { raise ActiveRecord::RecordInvalid, Client.new }

    AdministrativeAccessLock.stub(:lock!, lock_fails) do
      post base_org_support_app_enforcement_case_approval_url(@pending.public_id, host: @host),
           params: { principal_effect: { access_blocking: true } },
           headers: as_staff_headers(@operator_b, host: @host, session_public_id: @tokens.fetch(@operator_b).public_id),
           as: :json
    end

    assert_response :unprocessable_content
    @pending.reload

    assert_equal "failed", @pending.state, "a Case whose apply started is never returned to pending"
    assert_equal @operator_b.public_id, @pending.approved_by_operator_public_id
  end

  test "failure after the lock took effect keeps the lock and the approver, and reconciliation writes both events" do
    audit_down = ->(**) { raise ActiveRecord::ConnectionNotEstablished, "chronicle unavailable" }

    EnforcementEvent.stub(:create!, audit_down) do
      assert_raises(ActiveRecord::ConnectionNotEstablished) do
        post(
          base_org_support_app_enforcement_case_approval_url(@pending.public_id, host: @host),
          params: { principal_effect: { access_blocking: true } },
          headers: as_staff_headers(
            @operator_b, host: @host,
                         session_public_id: @tokens.fetch(@operator_b).public_id,
          ),
          as: :json,
        )
      end
    end
    @pending.reload

    assert_equal "active", @pending.state
    assert_equal @operator_b.public_id, @pending.approved_by_operator_public_id
    assert_predicate @client.reload, :admin_locked?, "an applied lock is never undone to look pending"
    assert_nil @pending.audited_at

    EnforcementReconciliationJob.perform_now

    approved = EnforcementEvent.find_by!(case_public_id: @pending.public_id, event_type: "approved")

    assert_equal @operator_b.public_id, approved.operator_public_id
    assert EnforcementEvent.exists?(case_public_id: @pending.public_id, event_type: "revocation_reconciled")
  end

  test "each event names the operator who performed it: A opens, B approves and applies, C releases" do
    cooldown_case = AppEnforcementCase.new(
      kind: "temporary_freeze", duration_mode: "timed", visibility: "visible", release_mode: "operator",
      effective_at: Time.current, expires_at: 1.day.from_now, reason_code: "abuse",
      principal_public_id: @client.public_id, applied_by_operator_public_id: @operator_a.public_id,
    )
    cooldown_case.build_principal_effect(
      principal_public_id: @client.public_id, access_blocking: true,
      effective_at: Time.current,
    )
    EnforcementCaseApplyOperation.call(enforcement_case: cooldown_case, actor_operator_public_id: @operator_a.public_id)

    post base_org_support_app_enforcement_case_approval_url(@pending.public_id, host: @host),
         params: { principal_effect: { access_blocking: true } },
         headers: as_staff_headers(@operator_b, host: @host, session_public_id: @tokens.fetch(@operator_b).public_id),
         as: :json

    assert_response :ok

    post base_org_support_app_enforcement_case_release_url(cooldown_case.public_id, host: @host),
         params: { reason: "revoked" },
         headers: as_staff_headers(@operator_c, host: @host, session_public_id: @tokens.fetch(@operator_c).public_id),
         as: :json

    assert_response :ok
    actors = EnforcementEvent.where(case_public_id: [@pending.public_id, cooldown_case.public_id])
      .pluck(:case_public_id, :event_type, :operator_public_id)

    assert_includes actors, [cooldown_case.public_id, "applied", @operator_a.public_id]
    assert_includes actors, [@pending.public_id, "approved", @operator_b.public_id]
    assert_includes actors, [@pending.public_id, "applied", @operator_b.public_id]
    assert_includes actors, [cooldown_case.public_id, "ended", @operator_c.public_id]
    assert_equal @operator_a.public_id, @pending.reload.applied_by_operator_public_id,
                 "the Case's own attribution still names the opener"
  end

  test "an appeal decision names the reviewer, not the opener or approver" do
    the_case = AppEnforcementCase.create!(
      kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: @client.public_id, applied_by_operator_public_id: @operator_a.public_id,
    )
    appeal = AppEnforcementAppeal.create!(
      # rubocop:disable I18n/RailsI18n/DecorateString -- appeal statements are stored user content, not UI copy
      enforcement_case: the_case, reason_code: "incorrect_decision", statement: "Please review.",
      # rubocop:enable I18n/RailsI18n/DecorateString
      submitted_at: Time.current,
    )

    appeal.resolve!(reviewer_operator_public_id: @operator_c.public_id, resolution_code: "rejected")

    event = EnforcementEvent.find_by!(case_public_id: the_case.public_id, event_type: "appeal_rejected")

    assert_equal @operator_c.public_id, event.operator_public_id
  end
end
