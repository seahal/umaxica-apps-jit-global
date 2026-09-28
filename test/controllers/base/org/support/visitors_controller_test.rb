# typed: false
# frozen_string_literal: true

require "test_helper"

# adr/operator-capability-authorization.md, Support: com-realm Visitor pages. Every test grants the
# capabilities it relies on in its own body.
class Base::Org::Support::VisitorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    @operator = operators(:one)
    @granter = operators(:two)
    @operator_token = OperatorToken.create!(
      staff: @operator,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
    @visitor = visitors(:reserved_visitor)
  end

  test "an operator with no grant cannot list visitors" do
    get base_org_support_visitors_url(ri: "jp", host: @host),
        headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
        as: :json

    assert_response :forbidden
  end

  test "the com read capability lists visitors filtered by public id" do
    OperatorCapabilityGrant.create!(
      operator: @operator, granted_by_operator: @granter, origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_COM, reason_code: "duty_assignment",
      starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )

    get base_org_support_visitors_url(q: @visitor.public_id, ri: "jp", host: @host),
        headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    assert_response :ok
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_equal "base/org/support/visitors/index", inertia_component
    assert_equal [@visitor.public_id], inertia_props.fetch("rows").map { |row| row.fetch("key") }
    assert_equal @visitor.public_id, inertia_props.dig("search", "value")
    assert_equal "com", inertia_props.dig("context", "realm")
  end

  test "a public id matching no visitor lists no rows" do
    OperatorCapabilityGrant.create!(
      operator: @operator, granted_by_operator: @granter, origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_COM, reason_code: "duty_assignment",
      starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )

    get base_org_support_visitors_url(q: "no_such_visitor", ri: "jp", host: @host),
        headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    assert_response :ok
    assert_empty inertia_props.fetch("rows")
  end

  test "the com read capability alone shows a visitor with no action and no enforcement section" do
    OperatorCapabilityGrant.create!(
      operator: @operator, granted_by_operator: @granter, origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_COM, reason_code: "duty_assignment",
      starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )

    get base_org_support_visitor_url(@visitor.public_id, ri: "jp", host: @host),
        headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    assert_response :ok
    assert_equal "base/org/support/visitors/show", inertia_component
    assert_includes inertia_props.fetch("fields").map { |field| field.fetch("description") }, @visitor.public_id
    assert_empty inertia_props.fetch("actions")
    assert_empty inertia_props.fetch("sections")
  end

  test "revoke, enforcement apply, and enforcement read capabilities add their actions and section" do
    [
      OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_COM,
      OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_COM,
      OperatorCapabilityGrant::ENFORCEMENT_APPLY_COM,
      OperatorCapabilityGrant::ENFORCEMENT_READ_COM,
    ].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, granted_by_operator: @granter, origin: "grant",
        capability: capability, reason_code: "duty_assignment",
        starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end

    get base_org_support_visitor_url(@visitor.public_id, ri: "jp", host: @host),
        headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    assert_response :ok
    hrefs = inertia_props.fetch("actions").map { |action| action.fetch("href") }

    assert_equal 2, hrefs.size
    assert(hrefs.any? { |href| href.include?("/support/visitors/#{@visitor.public_id}/revocations/new") })
    assert(hrefs.any? { |href| href.include?("principal_public_id=#{@visitor.public_id}") })
    assert_equal 1, inertia_props.fetch("sections").size
  end
end
