# typed: false
# frozen_string_literal: true

require "test_helper"

# adr/operator-capability-authorization.md, IAM. Every test states the grants it relies on.
class Base::Org::Iam::GrantsControllerTest < ActionDispatch::IntegrationTest
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

  test "an operator without iam.capability.read cannot list grants" do
    get base_org_iam_grants_url(ri: "jp", host: @host),
        headers: as_staff_headers(@granter, host: @host, session_public_id: @granter_token.public_id),
        as: :json

    assert_response :forbidden
  end

  test "a granter delegates a capability they hold to another operator, with Step-Up and an audit record" do
    [OperatorCapabilityGrant::IAM_CAPABILITY_READ, OperatorCapabilityGrant::IAM_CAPABILITY_GRANT].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @granter,
        origin: "bootstrap",
        capability: capability,
        reason_code: "bootstrap",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    OperatorCapabilityGrant.create!(
      operator: @granter,
      granted_by_operator: @grantee,
      origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
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
    operation_id = SecureRandom.uuid

    post base_org_iam_grants_url(host: @host),
         params: { operator_public_id: @grantee.public_id,
                   capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
                   reason_code: "duty_assignment",
                   duration_days: "30",
                   operation_id: operation_id, },
         headers: as_staff_headers(@granter, host: @host, session_public_id: @granter_token.public_id)

    assert_response :see_other
    grant = OperatorCapabilityGrant.find_by!(operator: @grantee, capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP)

    assert_equal @granter, grant.granted_by_operator
    assert @grantee.capability?(OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP)
    chronicle = Chronicle.find_by!(event_uuid: operation_id)

    assert_equal ["iam.capability.granted", "succeeded"], [chronicle.action, chronicle.result]
    assert_equal grant.public_id, chronicle.changeset.fetch("grant_public_id")
  end

  test "a granter cannot delegate a capability they do not hold" do
    [OperatorCapabilityGrant::IAM_CAPABILITY_READ, OperatorCapabilityGrant::IAM_CAPABILITY_GRANT].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @granter,
        origin: "bootstrap",
        capability: capability,
        reason_code: "bootstrap",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    @granter_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "operator_capability",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @granter_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )

    assert_no_difference -> { OperatorCapabilityGrant.count } do
      post base_org_iam_grants_url(host: @host),
           params: { operator_public_id: @grantee.public_id,
                     capability: OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,
                     reason_code: "duty_assignment",
                     duration_days: "30",
                     operation_id: SecureRandom.uuid, },
           headers: as_staff_headers(@granter, host: @host, session_public_id: @granter_token.public_id),
           as: :json
    end

    assert_response :forbidden
  end

  test "IAM capabilities cannot be delegated through the console, even by a holder" do
    [OperatorCapabilityGrant::IAM_CAPABILITY_READ, OperatorCapabilityGrant::IAM_CAPABILITY_GRANT].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @granter,
        origin: "bootstrap",
        capability: capability,
        reason_code: "bootstrap",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    @granter_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "operator_capability",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @granter_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )

    assert_no_difference -> { OperatorCapabilityGrant.count } do
      post base_org_iam_grants_url(host: @host),
           params: { operator_public_id: @grantee.public_id,
                     capability: OperatorCapabilityGrant::IAM_CAPABILITY_GRANT,
                     reason_code: "duty_assignment",
                     duration_days: "30",
                     operation_id: SecureRandom.uuid, },
           headers: as_staff_headers(@granter, host: @host, session_public_id: @granter_token.public_id),
           as: :json
    end

    assert_response :forbidden
  end

  test "self-grant, unknown capability, unknown operator, and out-of-list durations are refused" do
    [OperatorCapabilityGrant::IAM_CAPABILITY_READ, OperatorCapabilityGrant::IAM_CAPABILITY_GRANT].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @granter,
        origin: "bootstrap",
        capability: capability,
        reason_code: "bootstrap",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    OperatorCapabilityGrant.create!(
      operator: @granter,
      granted_by_operator: @grantee,
      origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
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

    [
      valid.merge(operator_public_id: @granter.public_id), valid.merge(capability: "support.*"),
      valid.merge(capability: ""), valid.merge(operator_public_id: "0000000000000000"),
      valid.merge(duration_days: "0"), valid.merge(duration_days: "366"), valid.merge(duration_days: "31"),
      valid.merge(reason_code: "bootstrap"),
    ].each do |params|
      assert_no_difference -> { OperatorCapabilityGrant.count } do
        post base_org_iam_grants_url(host: @host),
             params: params.merge(operation_id: SecureRandom.uuid),
             headers: as_staff_headers(
               @granter,
               host: @host,
               session_public_id: @granter_token.public_id,
             )
      end

      assert_response :unprocessable_content, "expected #{params.inspect} to be refused"
    end
  end

  test "the grant screen asks for Step-Up only after the grant capability is confirmed" do
    OperatorCapabilityGrant.create!(
      operator: @granter,
      origin: "bootstrap",
      capability: OperatorCapabilityGrant::IAM_CAPABILITY_READ,
      reason_code: "bootstrap",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )

    get new_base_org_iam_grant_url(ri: "jp", host: @host),
        headers: as_staff_headers(@granter, host: @host, session_public_id: @granter_token.public_id),
        as: :json

    assert_response :forbidden

    OperatorCapabilityGrant.create!(
      operator: @granter,
      origin: "bootstrap",
      capability: OperatorCapabilityGrant::IAM_CAPABILITY_GRANT,
      reason_code: "bootstrap",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )

    get new_base_org_iam_grant_url(ri: "jp", host: @host),
        headers: as_staff_headers(@granter, host: @host, session_public_id: @granter_token.public_id)

    assert_response :redirect
    assert_includes response.location, "scope=operator_capability"
  end

  test "revoking the last holder of the grant capability is refused and leaves the grant in force" do
    grants =
      [OperatorCapabilityGrant::IAM_CAPABILITY_READ, OperatorCapabilityGrant::IAM_CAPABILITY_GRANT,
       OperatorCapabilityGrant::IAM_CAPABILITY_REVOKE,].map do |capability|
        OperatorCapabilityGrant.create!(
          operator: @granter,
          origin: "bootstrap",
          capability: capability,
          reason_code: "bootstrap",
          starts_at: 1.minute.ago,
          expires_at: 1.day.from_now,
        )
      end
    @granter_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "operator_capability",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @granter_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    grant_capability = grants[1]

    post base_org_iam_grant_revocation_url(grant_capability.public_id, host: @host),
         params: { reason_code: "duty_ended", operation_id: SecureRandom.uuid },
         headers: as_staff_headers(@granter, host: @host, session_public_id: @granter_token.public_id)

    assert_response :unprocessable_content
    assert_predicate grant_capability.reload, :in_force?
  end

  test "a revoked grant stops the grantee's next request" do
    [OperatorCapabilityGrant::IAM_CAPABILITY_READ, OperatorCapabilityGrant::IAM_CAPABILITY_REVOKE].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @granter,
        origin: "bootstrap",
        capability: capability,
        reason_code: "bootstrap",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    target = OperatorCapabilityGrant.create!(
      operator: @grantee,
      granted_by_operator: @granter,
      origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )
    grantee_token = OperatorToken.create!(
      staff: @grantee,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
    get base_org_support_clients_url(ri: "jp", host: @host),
        headers: as_staff_headers(@grantee, host: @host, session_public_id: grantee_token.public_id),
        as: :json

    assert_response :ok

    @granter_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "operator_capability",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @granter_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    post base_org_iam_grant_revocation_url(target.public_id, host: @host),
         params: { reason_code: "duty_ended", operation_id: SecureRandom.uuid },
         headers: as_staff_headers(@granter, host: @host, session_public_id: @granter_token.public_id)

    assert_response :see_other
    assert_predicate target.reload, :revoked?

    get base_org_support_clients_url(ri: "jp", host: @host),
        headers: as_staff_headers(@grantee, host: @host, session_public_id: grantee_token.public_id),
        as: :json

    assert_response :forbidden
  end
end
