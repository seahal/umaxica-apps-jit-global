# typed: false
# frozen_string_literal: true

require "test_helper"

# adr/operator-capability-authorization.md, IAM: the grant list and grant detail pages. Every test
# states the grants it relies on in its own body.
class Base::Org::Iam::GrantPagesTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    @reader = operators(:one)
    @other = operators(:two)
    @reader_token = OperatorToken.create!(
      staff: @reader,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
  end

  test "iam.capability.read lists grants filtered by operator, without a new-grant action" do
    OperatorCapabilityGrant.create!(
      operator: @reader, origin: "bootstrap", capability: OperatorCapabilityGrant::IAM_CAPABILITY_READ,
      reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )
    other_grant = OperatorCapabilityGrant.create!(
      operator: @other, granted_by_operator: @reader, origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP, reason_code: "duty_assignment",
      starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )

    get base_org_iam_grants_url(q: @other.public_id, ri: "jp", host: @host),
        headers: as_staff_headers(@reader, host: @host, session_public_id: @reader_token.public_id)

    assert_response :ok
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_equal "base/org/iam/grants/index", inertia_component
    assert_equal [other_grant.public_id], inertia_props.fetch("rows").map { |row| row.fetch("key") }
    assert_equal I18n.t("base.org.admin.grants.states.in_force", locale: :ja),
                 inertia_props.fetch("rows").first.fetch("cells")[3]
    assert_empty inertia_props.fetch("actions"), "an operator holding only IAM capabilities has nothing to delegate"
  end

  test "each grant state is labelled: revoked, pending, and expired" do
    OperatorCapabilityGrant.create!(
      operator: @reader, origin: "bootstrap", capability: OperatorCapabilityGrant::IAM_CAPABILITY_READ,
      reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )
    revoked = OperatorCapabilityGrant.create!(
      operator: @other, granted_by_operator: @reader, origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP, reason_code: "duty_assignment",
      starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )
    revoked.revoke!(by: @reader, reason_code: "duty_ended")
    pending = OperatorCapabilityGrant.create!(
      operator: @other, granted_by_operator: @reader, origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_COM, reason_code: "duty_assignment",
      starts_at: 1.hour.from_now, expires_at: 1.day.from_now,
    )
    expired = OperatorCapabilityGrant.create!(
      operator: @other, granted_by_operator: @reader, origin: "grant",
      capability: OperatorCapabilityGrant::ENFORCEMENT_READ_APP, reason_code: "duty_assignment",
      starts_at: 2.days.ago, expires_at: 1.day.ago,
    )

    get base_org_iam_grants_url(q: @other.public_id, ri: "jp", host: @host),
        headers: as_staff_headers(@reader, host: @host, session_public_id: @reader_token.public_id)

    assert_response :ok
    states = inertia_props.fetch("rows").to_h { |row| [row.fetch("key"), row.fetch("cells")[3]] }

    assert_equal I18n.t("base.org.admin.grants.states.revoked", locale: :ja), states.fetch(revoked.public_id)
    assert_equal I18n.t("base.org.admin.grants.states.pending", locale: :ja), states.fetch(pending.public_id)
    assert_equal I18n.t("base.org.admin.grants.states.expired", locale: :ja), states.fetch(expired.public_id)
  end

  test "a grant detail offers revocation only to a holder of iam.capability.revoke" do
    OperatorCapabilityGrant.create!(
      operator: @reader, origin: "bootstrap", capability: OperatorCapabilityGrant::IAM_CAPABILITY_READ,
      reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )
    grant = OperatorCapabilityGrant.create!(
      operator: @other, granted_by_operator: @reader, origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP, reason_code: "duty_assignment",
      starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )
    headers = as_staff_headers(@reader, host: @host, session_public_id: @reader_token.public_id)

    get base_org_iam_grant_url(grant.public_id, ri: "jp", host: @host), headers: headers

    assert_response :ok
    assert_equal "base/org/iam/grants/show", inertia_component
    assert_includes inertia_props.fetch("fields").map { |field| field.fetch("description") }, @reader.public_id
    assert_empty inertia_props.fetch("actions")

    OperatorCapabilityGrant.create!(
      operator: @reader, origin: "bootstrap", capability: OperatorCapabilityGrant::IAM_CAPABILITY_REVOKE,
      reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )

    get base_org_iam_grant_url(grant.public_id, ri: "jp", host: @host), headers: headers

    assert_response :ok
    assert_equal [new_base_org_iam_grant_revocation_path(grant.public_id, ri: "jp")],
                 inertia_props.fetch("actions").map { |action| action.fetch("href") }
  end

  test "an unknown grant public id is not found" do
    OperatorCapabilityGrant.create!(
      operator: @reader, origin: "bootstrap", capability: OperatorCapabilityGrant::IAM_CAPABILITY_READ,
      reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )

    get base_org_iam_grant_url("no_such_grant", ri: "jp", host: @host),
        headers: as_staff_headers(@reader, host: @host, session_public_id: @reader_token.public_id)

    assert_response :not_found
  end
end
