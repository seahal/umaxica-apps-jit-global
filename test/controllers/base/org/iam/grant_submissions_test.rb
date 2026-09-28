# typed: false
# frozen_string_literal: true

require "test_helper"

# adr/operator-capability-authorization.md, IAM: the grant screen and the input contract of a grant
# submission (ticket id, operation id, idempotency). Every test states the grants it relies on.
class Base::Org::Iam::GrantSubmissionsTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    @granter = operators(:one)
    @grantee = operators(:two)
    @granter_token = OperatorToken.create!(
      staff: @granter,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
    # The compliance row normally comes from migration 20260926130000 (365 days, decided 2026-09-26);
    # a schema-only load skips that insert, so the test ensures it with the same value.
    ChronicleRetentionPolicy.find_or_create_by!(code: "compliance") do |policy|
      policy.name = "Compliance"
      policy.duration_days = 365
      policy.permanent = false
    end
  end

  test "with Step-Up the grant screen offers only the non-IAM capabilities the granter holds" do
    [OperatorCapabilityGrant::IAM_CAPABILITY_READ, OperatorCapabilityGrant::IAM_CAPABILITY_GRANT].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @granter, origin: "bootstrap", capability: capability,
        reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    OperatorCapabilityGrant.create!(
      operator: @granter, granted_by_operator: @grantee, origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ, reason_code: "duty_assignment",
      starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )
    @granter_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "operator_capability",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @granter_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    headers = as_staff_headers(@granter, host: @host, session_public_id: @granter_token.public_id)

    get new_base_org_iam_grant_url(ri: "jp", host: @host), headers: headers

    assert_response :ok
    assert_equal "base/org/iam/grants/new", inertia_component
    capability_field = inertia_props.fetch("fields").find { |field| field.fetch("name") == "capability" }

    assert_equal [OperatorCapabilityGrant::SUPPORT_CONSOLE_READ],
                 capability_field.fetch("options").map { |option| option.fetch("value") }

    get base_org_iam_grants_url(ri: "jp", host: @host), headers: headers

    assert_equal [new_base_org_iam_grant_path(ri: "jp")],
                 inertia_props.fetch("actions").map { |action| action.fetch("href") }
  end

  test "ticket ids are accepted up to 64 characters and refused at 65 or with a leading symbol" do
    [OperatorCapabilityGrant::IAM_CAPABILITY_READ, OperatorCapabilityGrant::IAM_CAPABILITY_GRANT].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @granter, origin: "bootstrap", capability: capability,
        reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    OperatorCapabilityGrant.create!(
      operator: @granter, granted_by_operator: @grantee, origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ, reason_code: "duty_assignment",
      starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )
    @granter_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "operator_capability",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @granter_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    headers = as_staff_headers(@granter, host: @host, session_public_id: @granter_token.public_id)
    valid = { operator_public_id: @grantee.public_id,
              capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ,
              reason_code: "duty_assignment",
              duration_days: "30", }

    ["A" * 65, "-OPS-1"].each do |ticket_id|
      assert_no_difference -> { OperatorCapabilityGrant.count } do
        post base_org_iam_grants_url(host: @host),
             params: valid.merge(ticket_id: ticket_id, operation_id: SecureRandom.uuid), headers: headers
      end

      assert_response :unprocessable_content, "expected ticket id #{ticket_id.inspect} to be refused"
      assert_predicate inertia_props.dig("errors", "ticket_id"), :present?
    end

    ticket_id = "A" * 64
    post base_org_iam_grants_url(host: @host),
         params: valid.merge(ticket_id: ticket_id, operation_id: SecureRandom.uuid), headers: headers

    assert_response :see_other
    assert_equal ticket_id, OperatorCapabilityGrant.find_by!(operator: @grantee).ticket_id
  end

  test "a missing or non-UUIDv4 operation id is refused before anything is granted" do
    [OperatorCapabilityGrant::IAM_CAPABILITY_READ, OperatorCapabilityGrant::IAM_CAPABILITY_GRANT].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @granter, origin: "bootstrap", capability: capability,
        reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    OperatorCapabilityGrant.create!(
      operator: @granter, granted_by_operator: @grantee, origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ, reason_code: "duty_assignment",
      starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )
    @granter_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "operator_capability",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @granter_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    valid = { operator_public_id: @grantee.public_id,
              capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ,
              reason_code: "duty_assignment",
              duration_days: "30", }

    [{}, { operation_id: "" }, { operation_id: "00000000-0000-1000-8000-000000000000" }].each do |operation|
      assert_no_difference -> { OperatorCapabilityGrant.count } do
        post base_org_iam_grants_url(host: @host),
             params: valid.merge(operation),
             headers: as_staff_headers(@granter, host: @host, session_public_id: @granter_token.public_id)
      end

      assert_response :unprocessable_content, "expected #{operation.inspect} to be refused"
      assert_predicate inertia_props.dig("errors", "operation_id"), :present?
    end
  end

  test "an operation id reused for a different grant is a conflict and grants nothing more" do
    [OperatorCapabilityGrant::IAM_CAPABILITY_READ, OperatorCapabilityGrant::IAM_CAPABILITY_GRANT].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @granter, origin: "bootstrap", capability: capability,
        reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    OperatorCapabilityGrant.create!(
      operator: @granter, granted_by_operator: @grantee, origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ, reason_code: "duty_assignment",
      starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )
    @granter_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "operator_capability",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @granter_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    headers = as_staff_headers(@granter, host: @host, session_public_id: @granter_token.public_id)
    operation_id = SecureRandom.uuid
    valid = { operator_public_id: @grantee.public_id,
              capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ,
              duration_days: "30",
              operation_id: operation_id, }

    post base_org_iam_grants_url(host: @host), params: valid.merge(reason_code: "duty_assignment"), headers: headers

    assert_response :see_other

    assert_no_difference -> { OperatorCapabilityGrant.count } do
      post base_org_iam_grants_url(host: @host), params: valid.merge(reason_code: "incident_response"),
                                                 headers: headers
    end

    assert_response :conflict
    assert_predicate inertia_props.dig("errors", "operation_id"), :present?
  end
end
