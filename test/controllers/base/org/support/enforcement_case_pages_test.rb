# typed: false
# frozen_string_literal: true

require "test_helper"

# adr/unified-enforcement.md: the HTML console pages for Enforcement Cases. Each test grants the
# capabilities it relies on in its own body.
class Base::Org::Support::EnforcementCasePagesTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "www.umaxica.org")
    @operator = operators(:one)
    @granter = operators(:two)
    @operator_token = OperatorToken.create!(
      staff_id: @operator.id,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
  end

  test "the app case list renders as a console page" do
    OperatorCapabilityGrant.create!(
      operator: @operator, granted_by_operator: @granter, origin: "grant",
      capability: OperatorCapabilityGrant::ENFORCEMENT_READ_APP, reason_code: "duty_assignment",
      starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )

    get base_org_support_app_enforcement_cases_url(ri: "jp", host: @host),
        headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    assert_response :ok
    assert_equal "base/org/support/enforcement_cases/index", inertia_component
  end

  test "a pending app case offers approval only to an operator holding the approve capability" do
    the_case = AppEnforcementCase.create!(
      kind: "permanent_ban", duration_mode: "permanent", visibility: "hidden",
      release_mode: "break_glass_only", effective_at: Time.current, reason_code: "abuse",
      principal_public_id: clients(:one).public_id, applied_by_operator_public_id: @granter.public_id,
      state: "pending_approval",
    )
    OperatorCapabilityGrant.create!(
      operator: @operator, granted_by_operator: @granter, origin: "grant",
      capability: OperatorCapabilityGrant::ENFORCEMENT_READ_APP, reason_code: "duty_assignment",
      starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )
    headers = as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    get base_org_support_app_enforcement_case_url(the_case.public_id, ri: "jp", host: @host), headers: headers

    assert_response :ok
    assert_equal "base/org/support/enforcement_cases/show", inertia_component
    assert_empty inertia_props.fetch("actions")
    assert_empty inertia_props.fetch("notices")

    OperatorCapabilityGrant.create!(
      operator: @operator, granted_by_operator: @granter, origin: "grant",
      capability: OperatorCapabilityGrant::ENFORCEMENT_APPROVE_APP, reason_code: "duty_assignment",
      starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )

    get base_org_support_app_enforcement_case_url(the_case.public_id, ri: "jp", host: @host), headers: headers

    assert_response :ok
    assert_equal [new_base_org_support_app_enforcement_case_approval_path(the_case.public_id, ri: "jp")],
                 inertia_props.fetch("actions").map { |action| action.fetch("href") }
  end

  test "an active com case whose audit has not converged shows a warning and a release action" do
    the_case = ComEnforcementCase.create!(
      kind: "cooldown", duration_mode: "timed", visibility: "visible", release_mode: "automatic",
      effective_at: Time.current, expires_at: 1.day.from_now, reason_code: "abuse",
      principal_public_id: visitors(:reserved_visitor).public_id,
      applied_by_operator_public_id: @granter.public_id, state: "active",
    )
    [OperatorCapabilityGrant::ENFORCEMENT_READ_COM,
     OperatorCapabilityGrant::ENFORCEMENT_RELEASE_COM,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, granted_by_operator: @granter, origin: "grant",
        capability: capability, reason_code: "duty_assignment",
        starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end

    get base_org_support_com_enforcement_case_url(the_case.public_id, ri: "jp", host: @host),
        headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    assert_response :ok
    assert_nil the_case.reload.audited_at
    assert_equal ["warning"], inertia_props.fetch("notices").map { |notice| notice.fetch("tone") }
    assert_equal base_org_support_com_enforcement_cases_path(ri: "jp"), inertia_props.dig("up_link", "href")
    assert_equal [new_base_org_support_com_enforcement_case_release_path(the_case.public_id, ri: "jp")],
                 inertia_props.fetch("actions").map { |action| action.fetch("href") }
  end
end
