# typed: false
# frozen_string_literal: true

require "test_helper"

# adr/unified-enforcement.md and adr/operator-capability-authorization.md. Every test states the
# capability grants it relies on in its own body: being an operator authorizes nothing on its own.
class Base::Org::Support::EnforcementCasesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "www.umaxica.org")
    @operator = operators(:one)
    @approver = operators(:two)
    @operator_token = OperatorToken.create!(
      staff_id: @operator.id,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
    @approver_token = OperatorToken.create!(
      staff_id: @approver.id,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
  end

  test "an operator with no grant is refused the case list" do
    get(
      base_org_support_app_enforcement_cases_url(host: @host),
      headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
      as: :json,
    )

    assert_response :forbidden
  end

  test "the read capability lists cases without Step-Up but does not allow opening one" do
    OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: @approver,
      origin: "grant",
      capability: OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )

    get(
      base_org_support_app_enforcement_cases_url(host: @host),
      headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
      as: :json,
    )

    assert_response :ok

    post(
      base_org_support_app_enforcement_cases_url(host: @host),
      params: { enforcement_case: { kind: "cooldown", principal_public_id: clients(:one).public_id } },
      headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
      as: :json,
    )

    assert_response :forbidden
  end

  test "an app grant does not reach the com realm, and no grant reaches the org realm" do
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP, OperatorCapabilityGrant::ENFORCEMENT_READ_COM].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @approver,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    OperatorCapabilityGrant.where(operator: @operator, capability: OperatorCapabilityGrant::ENFORCEMENT_READ_COM)
      .find_each { |grant| grant.update!(revoked_at: Time.current, revoke_reason_code: "duty_ended") }

    get(
      base_org_support_com_enforcement_cases_url(host: @host),
      headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
      as: :json,
    )

    assert_response :forbidden

    get(
      base_org_support_org_enforcement_cases_url(host: @host),
      headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
      as: :json,
    )

    assert_response :forbidden
  end

  test "a realm query parameter cannot redirect an app route to com cases" do
    OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: @approver,
      origin: "grant",
      capability: OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )
    com_case = ComEnforcementCase.create!(
      kind: "cooldown",
      duration_mode: "timed",
      visibility: "visible",
      release_mode: "automatic",
      effective_at: Time.current,
      expires_at: 1.day.from_now,
      reason_code: "abuse",
      principal_public_id: visitors(:reserved_visitor).public_id,
      applied_by_operator_public_id: @approver.public_id,
    )

    get(
      base_org_support_app_enforcement_case_url(com_case.public_id, realm: "com", host: @host),
      headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
      as: :json,
    )

    assert_response :not_found
  end

  test "without a grant the operator is refused before any Step-Up is asked for" do
    post(
      base_org_support_app_enforcement_cases_url(host: @host),
      params: { enforcement_case: { kind: "cooldown", principal_public_id: clients(:one).public_id } },
      headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
      as: :json,
    )

    assert_response :forbidden
    assert_not_includes response.body, "Step-up"
  end

  test "the apply capability without Step-Up does not open a case" do
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP, OperatorCapabilityGrant::ENFORCEMENT_APPLY_APP].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @approver,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end

    assert_no_difference -> { AppEnforcementCase.count } do
      post(
        base_org_support_app_enforcement_cases_url(host: @host),
        params: {
          enforcement_case: {
            kind: "cooldown",
            duration_mode: "timed",
            visibility: "visible",
            release_mode: "automatic",
            effective_at: Time.current,
            expires_at: 1.day.from_now,
            reason_code: "abuse",
            principal_public_id: clients(:one).public_id,
          },
        },
        headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
        as: :json,
      )
    end

    assert_response :unprocessable_content
    assert_includes response.parsed_body.fetch("error"), "Step-up authentication required"
  end

  test "Step-Up for a different scope does not satisfy the apply scope" do
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP, OperatorCapabilityGrant::ENFORCEMENT_APPLY_APP].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @approver,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    mark_token_step_up_satisfied_for_test(@operator_token, scope: "enforcement_case_release")

    post(
      base_org_support_app_enforcement_cases_url(host: @host),
      params: { enforcement_case: { kind: "cooldown", principal_public_id: clients(:one).public_id } },
      headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
      as: :json,
    )

    assert_response :unprocessable_content
    assert_includes response.parsed_body.fetch("error"), "Step-up authentication required"
  end

  test "operator with apply capability and Step-Up opens a cooldown case that applies immediately" do
    client = clients(:one)
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP, OperatorCapabilityGrant::ENFORCEMENT_APPLY_APP].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @approver,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    mark_token_step_up_satisfied_for_test(@operator_token, scope: "enforcement_case_apply")

    post(
      base_org_support_app_enforcement_cases_url(host: @host),
      params: {
        enforcement_case: {
          kind: "cooldown",
          duration_mode: "timed",
          visibility: "visible",
          release_mode: "automatic",
          effective_at: Time.current,
          expires_at: 1.day.from_now,
          reason_code: "abuse",
          principal_public_id: client.public_id,
        },
      },
      headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
      as: :json,
    )

    assert_response :created
    body = response.parsed_body

    assert_equal "active", body.fetch("state")
    assert_equal client.public_id, body.fetch("principal_public_id")
    assert_equal @operator.public_id, body.fetch("applied_by_operator_public_id")
  end

  test "a case naming no existing principal, or a principal of another realm, is not found" do
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP, OperatorCapabilityGrant::ENFORCEMENT_APPLY_APP].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @approver,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    mark_token_step_up_satisfied_for_test(@operator_token, scope: "enforcement_case_apply")

    ["NO0SUCH0PRINCIPAL", visitors(:reserved_visitor).public_id].each do |principal_public_id|
      assert_no_difference -> { AppEnforcementCase.count } do
        post(
          base_org_support_app_enforcement_cases_url(host: @host),
          params: {
            enforcement_case: {
              kind: "cooldown",
              duration_mode: "timed",
              visibility: "visible",
              release_mode: "automatic",
              effective_at: Time.current,
              expires_at: 1.day.from_now,
              reason_code: "abuse",
              principal_public_id: principal_public_id,
            },
          },
          headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
          as: :json,
        )
      end

      assert_response :not_found
    end
  end

  test "a break-glass request on create is refused rather than trusted" do
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP, OperatorCapabilityGrant::ENFORCEMENT_APPLY_APP].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @approver,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    mark_token_step_up_satisfied_for_test(@operator_token, scope: "enforcement_case_apply")

    assert_no_difference -> { AppEnforcementCase.count } do
      post(
        base_org_support_app_enforcement_cases_url(host: @host),
        params: {
          enforcement_case: {
            kind: "permanent_ban",
            duration_mode: "permanent",
            visibility: "visible",
            release_mode: "break_glass_only",
            effective_at: Time.current,
            reason_code: "abuse",
            principal_public_id: clients(:one).public_id,
            break_glass: true,
            break_glass_approved_by_operator_public_id: @approver.public_id,
          },
        },
        headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
        as: :json,
      )
    end

    assert_response :unprocessable_content
  end

  test "an approver named in the create request is ignored; the Case waits for a real approval" do
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP, OperatorCapabilityGrant::ENFORCEMENT_APPLY_APP].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @approver,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    mark_token_step_up_satisfied_for_test(@operator_token, scope: "enforcement_case_apply")

    post(
      base_org_support_app_enforcement_cases_url(host: @host),
      params: {
        enforcement_case: {
          kind: "permanent_ban",
          duration_mode: "permanent",
          visibility: "hidden",
          release_mode: "break_glass_only",
          effective_at: Time.current,
          reason_code: "abuse",
          principal_public_id: clients(:one).public_id,
          approved_by_operator_public_id: @approver.public_id,
        },
      },
      headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
      as: :json,
    )

    assert_response :accepted
    the_case = AppEnforcementCase.find_by!(public_id: response.parsed_body.fetch("public_id"))

    assert_equal "pending_approval", the_case.state
    assert_nil the_case.approved_by_operator_public_id
    assert_not_predicate the_case.identifier_effects, :exists?
  end

  test "a second operator with the approve capability approves, and the audit event names them" do
    client = clients(:one)
    the_case = AppEnforcementCase.create!(
      kind: "permanent_ban",
      duration_mode: "permanent",
      visibility: "hidden",
      release_mode: "break_glass_only",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: @operator.public_id,
      state: "pending_approval",
    )
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
     OperatorCapabilityGrant::ENFORCEMENT_APPROVE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @approver,
        granted_by_operator: @operator,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    mark_token_step_up_satisfied_for_test(@approver_token, scope: "enforcement_case_approve")

    post(
      base_org_support_app_enforcement_case_approval_url(the_case.public_id, host: @host),
      params: { principal_effect: { access_blocking: true } },
      headers: as_staff_headers(@approver, host: @host, session_public_id: @approver_token.public_id),
      as: :json,
    )

    assert_response :ok
    the_case.reload

    assert_equal "active", the_case.state
    assert_equal @approver.public_id, the_case.approved_by_operator_public_id
    assert_predicate client.reload, :admin_locked?
    approved = EnforcementEvent.find_by!(case_public_id: the_case.public_id, event_type: "approved")

    assert_equal @approver.public_id, approved.operator_public_id
  end

  test "a second approval of the same case is a conflict and does not apply it twice" do
    client = clients(:one)
    the_case = AppEnforcementCase.create!(
      kind: "permanent_ban",
      duration_mode: "permanent",
      visibility: "hidden",
      release_mode: "break_glass_only",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: @operator.public_id,
      state: "pending_approval",
    )
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
     OperatorCapabilityGrant::ENFORCEMENT_APPROVE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @approver,
        granted_by_operator: @operator,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    mark_token_step_up_satisfied_for_test(@approver_token, scope: "enforcement_case_approve")
    headers = as_staff_headers(@approver, host: @host, session_public_id: @approver_token.public_id)

    post(
      base_org_support_app_enforcement_case_approval_url(the_case.public_id, host: @host),
      params: { principal_effect: { access_blocking: true } },
      headers: headers,
      as: :json,
    )

    assert_response :ok

    post(
      base_org_support_app_enforcement_case_approval_url(the_case.public_id, host: @host),
      params: { principal_effect: { access_blocking: true } },
      headers: headers,
      as: :json,
    )

    assert_response :conflict
    assert_equal 1, EnforcementEvent.where(case_public_id: the_case.public_id, event_type: "applied").count
  end

  test "the applying operator cannot approve their own case even holding the approve capability" do
    the_case = AppEnforcementCase.create!(
      kind: "permanent_ban",
      duration_mode: "permanent",
      visibility: "hidden",
      release_mode: "break_glass_only",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: clients(:one).public_id,
      applied_by_operator_public_id: @operator.public_id,
      state: "pending_approval",
    )
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
     OperatorCapabilityGrant::ENFORCEMENT_APPROVE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @approver,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    mark_token_step_up_satisfied_for_test(@operator_token, scope: "enforcement_case_approve")

    post(
      base_org_support_app_enforcement_case_approval_url(the_case.public_id, host: @host),
      params: {},
      headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
      as: :json,
    )

    assert_response :forbidden
    assert_equal "pending_approval", the_case.reload.state
  end

  test "an approver whose grant was revoked after Step-Up is refused" do
    the_case = AppEnforcementCase.create!(
      kind: "permanent_ban",
      duration_mode: "permanent",
      visibility: "hidden",
      release_mode: "break_glass_only",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: clients(:one).public_id,
      applied_by_operator_public_id: @operator.public_id,
      state: "pending_approval",
    )
    grants =
      [OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
       OperatorCapabilityGrant::ENFORCEMENT_APPROVE_APP,].map do |capability|
        OperatorCapabilityGrant.create!(
          operator: @approver,
          granted_by_operator: @operator,
          origin: "grant",
          capability: capability,
          reason_code: "duty_assignment",
          starts_at: 1.minute.ago,
          expires_at: 1.day.from_now,
        )
      end
    mark_token_step_up_satisfied_for_test(@approver_token, scope: "enforcement_case_approve")
    grants.last.update!(revoked_at: Time.current, revoked_by_operator: @operator, revoke_reason_code: "duty_ended")

    post(
      base_org_support_app_enforcement_case_approval_url(the_case.public_id, host: @host),
      params: { principal_effect: { access_blocking: true } },
      headers: as_staff_headers(@approver, host: @host, session_public_id: @approver_token.public_id),
      as: :json,
    )

    assert_response :forbidden
    assert_equal "pending_approval", the_case.reload.state
  end

  test "releasing one blocking case keeps the principal locked while another blocking case is in force" do
    client = clients(:one)
    first, second =
      2.times.map do
      the_case = AppEnforcementCase.new(
        kind: "temporary_freeze",
        duration_mode: "timed",
        visibility: "visible",
        release_mode: "operator",
        effective_at: Time.current,
        expires_at: 1.day.from_now,
        reason_code: "security_incident",
        principal_public_id: client.public_id,
        applied_by_operator_public_id: @approver.public_id,
      )
      the_case.build_principal_effect(
        principal_public_id: client.public_id,
        access_blocking: true,
        effective_at: Time.current,
      )
      EnforcementCaseApplyOperation.call(
        enforcement_case: the_case,
        actor_operator_public_id: the_case.applied_by_operator_public_id,
      )
      the_case
    end
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
     OperatorCapabilityGrant::ENFORCEMENT_RELEASE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @approver,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    mark_token_step_up_satisfied_for_test(@operator_token, scope: "enforcement_case_release")
    headers = as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    post(
      base_org_support_app_enforcement_case_release_url(first.public_id, host: @host),
      params: { reason: "revoked" },
      headers: headers,
      as: :json,
    )

    assert_response :ok
    assert_predicate first.reload.ended_at, :present?
    assert_predicate client.reload, :admin_locked?

    post(
      base_org_support_app_enforcement_case_release_url(second.public_id, host: @host),
      params: { reason: "revoked" },
      headers: headers,
      as: :json,
    )

    assert_response :ok
    assert_not_predicate client.reload, :admin_locked?
    ended = EnforcementEvent.find_by!(case_public_id: second.public_id, event_type: "ended")

    assert_equal @operator.public_id, ended.operator_public_id
  end

  test "an unknown release reason is refused instead of defaulting" do
    client = clients(:one)
    the_case = AppEnforcementCase.new(
      kind: "temporary_freeze",
      duration_mode: "timed",
      visibility: "visible",
      release_mode: "operator",
      effective_at: Time.current,
      expires_at: 1.day.from_now,
      reason_code: "security_incident",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: @approver.public_id,
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
     OperatorCapabilityGrant::ENFORCEMENT_RELEASE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @approver,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    mark_token_step_up_satisfied_for_test(@operator_token, scope: "enforcement_case_release")

    ["", "break_glass_released", "appeal_approved", "REVOKED"].each do |reason|
      post(
        base_org_support_app_enforcement_case_release_url(the_case.public_id, host: @host),
        params: { reason: reason },
        headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
        as: :json,
      )

      assert_response :unprocessable_content
    end
    assert_nil the_case.reload.ended_at
  end

  test "a permanent ban is not released through the console" do
    client = clients(:one)
    the_case = AppEnforcementCase.new(
      kind: "permanent_ban",
      duration_mode: "permanent",
      visibility: "visible",
      release_mode: "break_glass_only",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: @approver.public_id,
      approved_by_operator_public_id: @operator.public_id,
    )
    the_case.build_principal_effect(
      principal_public_id: client.public_id,
      access_blocking: true,
      effective_at: Time.current,
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
     OperatorCapabilityGrant::ENFORCEMENT_RELEASE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @approver,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    mark_token_step_up_satisfied_for_test(@operator_token, scope: "enforcement_case_release")

    post(
      base_org_support_app_enforcement_case_release_url(the_case.public_id, host: @host),
      params: { reason: "revoked" },
      headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
      as: :json,
    )

    assert_response :unprocessable_content
    assert_nil the_case.reload.ended_at
    assert_predicate client.reload, :admin_locked?
  end

  test "a separate operator with the review capability rejects an appeal, and the event names them" do
    client = clients(:one)
    the_case = AppEnforcementCase.create!(
      kind: "security_lock",
      state: "draft",
      duration_mode: "indefinite",
      visibility: "visible",
      release_mode: "verification_required",
      effective_at: Time.current,
      reason_code: "security_incident",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: @operator.public_id,
    )
    appeal = AppEnforcementAppeal.create!(
      # rubocop:disable I18n/RailsI18n/DecorateString -- appeal statements are stored user content, not UI copy
      enforcement_case: the_case,
      reason_code: "incorrect_decision",
      statement: "Please review this decision.",
      # rubocop:enable I18n/RailsI18n/DecorateString
      submitted_at: Time.current,
    )
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
     OperatorCapabilityGrant::ENFORCEMENT_REVIEW_APPEAL_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @approver,
        granted_by_operator: @operator,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    mark_token_step_up_satisfied_for_test(@approver_token, scope: "enforcement_case_review_appeal")

    post(
      base_org_support_app_enforcement_case_appeal_review_url(the_case.public_id, host: @host),
      params: { resolution_code: "rejected" },
      headers: as_staff_headers(@approver, host: @host, session_public_id: @approver_token.public_id),
      as: :json,
    )

    assert_response :ok
    assert_equal "rejected", appeal.reload.state
    assert_equal @approver.public_id, appeal.reviewer_operator_public_id
    event = EnforcementEvent.find_by!(case_public_id: the_case.public_id, event_type: "appeal_rejected")

    assert_equal @approver.public_id, event.operator_public_id
  end

  test "index scopes strictly to the app realm and never returns com cases" do
    app_client = clients(:one)
    app_case = AppEnforcementCase.create!(
      kind: "cooldown",
      duration_mode: "timed",
      visibility: "visible",
      release_mode: "automatic",
      effective_at: Time.current,
      expires_at: 1.day.from_now,
      reason_code: "abuse",
      principal_public_id: app_client.public_id,
      applied_by_operator_public_id: @approver.public_id,
    )
    com_case = ComEnforcementCase.create!(
      kind: "cooldown",
      duration_mode: "timed",
      visibility: "visible",
      release_mode: "automatic",
      effective_at: Time.current,
      expires_at: 1.day.from_now,
      reason_code: "abuse",
      principal_public_id: visitors(:reserved_visitor).public_id,
      applied_by_operator_public_id: @approver.public_id,
    )
    OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: @approver,
      origin: "grant",
      capability: OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )

    get(
      base_org_support_app_enforcement_cases_url(host: @host),
      headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
      as: :json,
    )

    assert_response :ok
    public_ids = response.parsed_body.fetch("enforcement_cases").map { |c| c.fetch("public_id") }

    assert_includes public_ids, app_case.public_id
    assert_not_includes public_ids, com_case.public_id
  end

  test "a malformed principal filter is a bad request, not an empty list" do
    OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: @approver,
      origin: "grant",
      capability: OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )

    get(
      base_org_support_app_enforcement_cases_url(host: @host, principal_public_id: "bad value\u0000"),
      headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
      as: :json,
    )

    assert_response :bad_request
  end

  private

  # as_staff_headers / host_headers come from the globally-included
  # AuthenticationHarness (test/test_helper.rb) -- it mints a real JWT access
  # cookie for the operator, unlike the raw X-TEST-* headers some older test
  # files shadow it with locally.

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    attrs = {
      last_step_up_at: at,
      last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
      last_step_up_aal: ("aal2" if token.respond_to?(:last_step_up_aal)),
      last_step_up_method: ("passkey" if token.respond_to?(:last_step_up_method)),
      last_step_up_session_public_id: (token.public_id if token.respond_to?(:last_step_up_session_public_id)),
      last_step_up_purpose: ("step_up" if token.respond_to?(:last_step_up_purpose)),
      last_step_up_audience: (step_up_test_audience_for_token(token) if token.respond_to?(:last_step_up_audience)),
      updated_at: Time.current,
    }.compact
    token.update_columns(attrs)
  end

  def step_up_test_audience_for_token(token)
    case token.class.name
    when "OperatorToken" then "step_up:org"
    when "VisitorToken" then "step_up:com"
    else "step_up:app"
    end
  end
end
