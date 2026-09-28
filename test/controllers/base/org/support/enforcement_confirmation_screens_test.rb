# typed: false
# frozen_string_literal: true

require "test_helper"

# adr/unified-enforcement.md: the HTML confirmation screens and HTML submissions of the Enforcement
# Case console (apply, release, appeal review). Each test grants the capabilities and Step-Up scope
# it relies on in its own body.
class Base::Org::Support::EnforcementConfirmationScreensTest < ActionDispatch::IntegrationTest
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

  test "the apply screen names the principal and posts to the realm case list" do
    client = clients(:one)
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP, OperatorCapabilityGrant::ENFORCEMENT_APPLY_APP].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, granted_by_operator: @granter, origin: "grant",
        capability: capability, reason_code: "duty_assignment",
        starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    @operator_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "enforcement_case_apply",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @operator_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )

    get new_base_org_support_app_enforcement_case_url(principal_public_id: client.public_id, ri: "jp", host: @host),
        headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    assert_response :ok
    assert_equal "base/org/support/enforcement_cases/new", inertia_component
    assert_equal client.public_id, inertia_props.fetch("target").first.fetch("description")
    assert_equal base_org_support_app_enforcement_cases_path(ri: "jp"), inertia_props.fetch("action")
  end

  test "the apply screen without a principal is a bad request" do
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP, OperatorCapabilityGrant::ENFORCEMENT_APPLY_APP].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, granted_by_operator: @granter, origin: "grant",
        capability: capability, reason_code: "duty_assignment",
        starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    @operator_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "enforcement_case_apply",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @operator_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )

    get new_base_org_support_app_enforcement_case_url(ri: "jp", host: @host),
        headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    assert_response :bad_request
  end

  test "an HTML apply with principal, method, and identifier effects redirects to the new case" do
    client = clients(:one)
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP, OperatorCapabilityGrant::ENFORCEMENT_APPLY_APP].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, granted_by_operator: @granter, origin: "grant",
        capability: capability, reason_code: "duty_assignment",
        starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    @operator_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "enforcement_case_apply",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @operator_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )

    post base_org_support_app_enforcement_cases_url(ri: "jp", host: @host),
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
           principal_effect: { access_blocking: "false" },
           authentication_method_effect: { authentication_method: "passkey", effect: "mutation_locked" },
           identifier_effect: { email: "blocked@example.com",
                                registration_blocked: "true",
                                attachment_blocked: "false",
                                recovery_blocked: "false", },
         },
         headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    assert_response :see_other
    the_case = AppEnforcementCase.where(principal_public_id: client.public_id).order(:created_at).last

    assert_redirected_to base_org_support_app_enforcement_case_url(the_case.public_id, ri: "jp", host: @host)
    assert_equal "active", the_case.state
    assert_not_nil the_case.principal_effect
    assert_equal ["passkey"], the_case.authentication_method_effects.map(&:authentication_method)
    assert_equal 1, the_case.identifier_effects.count
  end

  test "an HTML apply whose identifier effect names neither email nor telephone re-renders the screen" do
    client = clients(:one)
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP, OperatorCapabilityGrant::ENFORCEMENT_APPLY_APP].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, granted_by_operator: @granter, origin: "grant",
        capability: capability, reason_code: "duty_assignment",
        starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    @operator_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "enforcement_case_apply",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @operator_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )

    assert_no_difference -> { AppEnforcementCase.count } do
      post base_org_support_app_enforcement_cases_url(ri: "jp", host: @host),
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
             identifier_effect: { registration_blocked: "true" },
           },
           headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)
    end

    assert_response :unprocessable_content
    assert_equal "base/org/support/enforcement_cases/new", inertia_component
    assert_predicate inertia_props.dig("errors", "base"), :present?
  end

  test "an apply whose effect omits a block flag is refused as invalid input and creates no case" do
    client = clients(:one)
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP, OperatorCapabilityGrant::ENFORCEMENT_APPLY_APP].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, granted_by_operator: @granter, origin: "grant",
        capability: capability, reason_code: "duty_assignment",
        starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    @operator_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "enforcement_case_apply",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @operator_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )

    [
      { identifier_effect: { email: "blocked@example.com", registration_blocked: "true" } },
      { principal_effect: { access_blocking: "" } },
    ].each do |effect|
      assert_no_difference -> { AppEnforcementCase.count } do
        post base_org_support_app_enforcement_cases_url(ri: "jp", host: @host),
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
             }.merge(effect),
             headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
             as: :json
      end

      assert_response :unprocessable_content, "expected #{effect.inspect} to be refused"
    end
  end

  test "the release screen renders for an active case, and an HTML release redirects to the case" do
    the_case = AppEnforcementCase.create!(
      kind: "cooldown", duration_mode: "timed", visibility: "visible", release_mode: "automatic",
      effective_at: Time.current, expires_at: 1.day.from_now, reason_code: "abuse",
      principal_public_id: clients(:one).public_id, applied_by_operator_public_id: @granter.public_id,
      state: "active",
    )
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
     OperatorCapabilityGrant::ENFORCEMENT_RELEASE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, granted_by_operator: @granter, origin: "grant",
        capability: capability, reason_code: "duty_assignment",
        starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    @operator_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "enforcement_case_release",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @operator_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    headers = as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    get new_base_org_support_app_enforcement_case_release_url(the_case.public_id, ri: "jp", host: @host),
        headers: headers

    assert_response :ok
    assert_equal "base/org/support/enforcement_cases/releases/new", inertia_component
    assert_equal base_org_support_app_enforcement_case_path(the_case.public_id, ri: "jp"),
                 inertia_props.dig("up_link", "href")

    post base_org_support_app_enforcement_case_release_url(the_case.public_id, ri: "jp", host: @host),
         params: { reason: "corrected" }, headers: headers

    assert_response :see_other
    assert_redirected_to base_org_support_app_enforcement_case_url(the_case.public_id, ri: "jp", host: @host)
    assert_equal "corrected", the_case.reload.end_reason
  end

  test "the release screen for a permanent ban shows the break-glass refusal instead of a form" do
    the_case = AppEnforcementCase.create!(
      kind: "permanent_ban", duration_mode: "permanent", visibility: "hidden",
      release_mode: "break_glass_only", effective_at: Time.current, reason_code: "abuse",
      principal_public_id: clients(:one).public_id, applied_by_operator_public_id: @granter.public_id,
      state: "active",
    )
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
     OperatorCapabilityGrant::ENFORCEMENT_RELEASE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, granted_by_operator: @granter, origin: "grant",
        capability: capability, reason_code: "duty_assignment",
        starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    @operator_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "enforcement_case_release",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @operator_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )

    get new_base_org_support_app_enforcement_case_release_url(the_case.public_id, ri: "jp", host: @host),
        headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    assert_response :unprocessable_content
    assert_predicate inertia_props.dig("errors", "base"), :present?
  end

  test "a released case cannot be released again over HTML" do
    the_case = AppEnforcementCase.create!(
      kind: "cooldown", duration_mode: "timed", visibility: "visible", release_mode: "automatic",
      effective_at: Time.current, expires_at: 1.day.from_now, reason_code: "abuse",
      principal_public_id: clients(:one).public_id, applied_by_operator_public_id: @granter.public_id,
      state: "draft",
    )
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
     OperatorCapabilityGrant::ENFORCEMENT_RELEASE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, granted_by_operator: @granter, origin: "grant",
        capability: capability, reason_code: "duty_assignment",
        starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    @operator_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "enforcement_case_release",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @operator_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )

    post base_org_support_app_enforcement_case_release_url(the_case.public_id, ri: "jp", host: @host),
         params: { reason: "revoked" },
         headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    assert_response :conflict
    assert_equal "draft", the_case.reload.state
  end

  test "an open com appeal is offered for review, and the review screen and HTML review work" do
    the_case = ComEnforcementCase.create!(
      kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: visitors(:reserved_visitor).public_id,
      applied_by_operator_public_id: @granter.public_id,
    )
    appeal = ComEnforcementAppeal.create!(
      # rubocop:disable I18n/RailsI18n/DecorateString -- appeal statements are stored user content, not UI copy
      enforcement_case: the_case, reason_code: "incorrect_decision", statement: "Please review this decision.",
      # rubocop:enable I18n/RailsI18n/DecorateString
      submitted_at: Time.current,
    )
    [OperatorCapabilityGrant::ENFORCEMENT_READ_COM,
     OperatorCapabilityGrant::ENFORCEMENT_REVIEW_APPEAL_COM,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, granted_by_operator: @granter, origin: "grant",
        capability: capability, reason_code: "duty_assignment",
        starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    @operator_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "enforcement_case_review_appeal",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @operator_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    headers = as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    get base_org_support_com_enforcement_case_url(the_case.public_id, ri: "jp", host: @host), headers: headers

    assert_response :ok
    assert_equal [new_base_org_support_com_enforcement_case_appeal_review_path(the_case.public_id, ri: "jp")],
                 inertia_props.fetch("actions").map { |action| action.fetch("href") }

    get new_base_org_support_com_enforcement_case_appeal_review_url(the_case.public_id, ri: "jp", host: @host),
        headers: headers

    assert_response :ok
    assert_equal "base/org/support/enforcement_cases/appeal_reviews/new", inertia_component

    post base_org_support_com_enforcement_case_appeal_review_url(the_case.public_id, ri: "jp", host: @host),
         params: { resolution_code: "not_a_resolution" }, headers: headers

    assert_response :unprocessable_content
    assert_equal "base/org/support/enforcement_cases/appeal_reviews/new", inertia_component

    post base_org_support_com_enforcement_case_appeal_review_url(the_case.public_id, ri: "jp", host: @host),
         params: { resolution_code: "rejected" }, headers: headers

    assert_response :see_other
    assert_redirected_to base_org_support_com_enforcement_case_url(the_case.public_id, ri: "jp", host: @host)
    assert_equal "rejected", appeal.reload.state
  end
end
