# typed: false
# frozen_string_literal: true

require "test_helper"

# The org administration consoles are gated by OrgConsolePolicy on operator capability grants
# (adr/operator-capability-authorization.md). An operator with no grant gets no more than an anonymous
# request does; Support and IAM open with their own read capability; audit, billing, configuration,
# and system have no data source yet and stay closed even to an operator holding every capability.
class Base::Org::StaffConsolePagesTest < ActionDispatch::IntegrationTest
  fixtures :operators,
           :operator_statuses,
           :operator_token_kinds,
           :operator_token_statuses,
           :operator_token_binding_methods,
           :operator_token_dbsc_statuses

  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! @host
    @operator = operators(:one)
    @token = OperatorToken.create!(
      staff: @operator,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: @token)
    access_token = AuthenticationToken.encode(
      @operator,
      host: @host,
      session_public_id: @token.public_id,
      resource_type: "operator",
      jwt_issuer_id: "surface:BASE_ORG",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    @headers = {
      "Authorization" => "Bearer #{access_token}",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => @host,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }.freeze
  end

  test "audit console denies an operator that holds no grant" do
    get base_org_audit_index_url(ri: "jp", host: @host), headers: @headers

    assert_response :redirect
    assert_not_equal "ok", response.parsed_body["status"]
  end

  test "billing console denies an operator that holds no grant" do
    get base_org_billing_index_url(ri: "jp", host: @host), headers: @headers

    assert_response :redirect
  end

  test "iam console denies an operator that holds no grant" do
    get base_org_iam_index_url(ri: "jp", host: @host), headers: @headers

    assert_response :redirect
  end

  test "system console denies an operator that holds no grant" do
    get base_org_system_index_url(ri: "jp", host: @host), headers: @headers

    assert_response :redirect
  end

  test "support console denies an operator that holds no grant" do
    get base_org_support_index_url(ri: "jp", host: @host), headers: @headers

    assert_response :redirect
  end

  test "configuration console denies an operator that holds no grant" do
    get base_org_configuration_url(ri: "jp", host: @host), headers: @headers

    assert_response :redirect
  end

  test "audit console denies an anonymous request" do
    get base_org_audit_index_url(ri: "jp", host: @host), headers: { "Host" => @host }

    assert_not_equal 200, response.status
  end

  test "support console opens with support.console.read and lists only granted areas" do
    [OperatorCapabilityGrant::SUPPORT_CONSOLE_READ,
     OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_COM,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        origin: "bootstrap",
        capability: capability,
        reason_code: "bootstrap",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end

    get base_org_support_index_url(ri: "jp", host: @host), headers: @headers

    assert_response :ok
    hrefs =
      inertia_props.fetch("sections").flat_map { |section|
        section.fetch("items")
      }.map { |item| item.fetch("href") }

    assert_equal [base_org_support_visitors_path(ri: "jp")], hrefs
  end

  test "iam console opens with iam.capability.read" do
    OperatorCapabilityGrant.create!(
      operator: @operator,
      origin: "bootstrap",
      capability: OperatorCapabilityGrant::IAM_CAPABILITY_READ,
      reason_code: "bootstrap",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )

    get base_org_iam_index_url(ri: "jp", host: @host), headers: @headers

    assert_response :ok
    assert_equal "base/org/iam/index", inertia_component
  end

  test "consoles without a data source stay closed even to an operator holding every capability" do
    OperatorCapabilityGrant.bootstrap!(
      operator: @operator,
      capabilities: OperatorCapabilityGrant::CAPABILITIES,
      ticket_id: "TEST-1",
      expires_at: 1.day.from_now,
    )

    [base_org_audit_index_url(ri: "jp", host: @host), base_org_billing_index_url(ri: "jp", host: @host),
     base_org_system_index_url(ri: "jp", host: @host), base_org_configuration_url(ri: "jp", host: @host),].each do |url|
      get url, headers: @headers

      assert_not_equal 200, response.status, "expected #{url} to stay closed"
      assert_not_equal 501, response.status, "expected #{url} to be refused by policy before any response"
    end
  end

  test "the dashboard shows Administration only for consoles the operator is granted" do
    get base_org_root_url(ri: "jp", host: @host), headers: @headers

    assert_response :ok
    headings = inertia_props.fetch("sections").map { |section| section.fetch("heading") }

    assert_not_includes headings, I18n.t("base.org.admin.dashboard.administration")

    OperatorCapabilityGrant.create!(
      operator: @operator,
      origin: "bootstrap",
      capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ,
      reason_code: "bootstrap",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )

    get base_org_root_url(ri: "jp", host: @host), headers: @headers
    administration =
      inertia_props.fetch("sections").find do |section|
        section.fetch("heading") == I18n.t("base.org.admin.dashboard.administration")
      end

    assert_equal [base_org_support_index_path(ri: "jp")],
                 administration.fetch("items").map { |item|
                   item.fetch("href")
                 }
    assert_includes inertia_props.fetch("sections").flat_map { |section|
      Array(section["items"])
    }.pluck("href"),
                    new_base_org_sign_out_path(ri: "jp"),
                    "personal links such as logout stay in place"
  end
end
