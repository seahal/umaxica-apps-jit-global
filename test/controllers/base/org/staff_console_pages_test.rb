# typed: false
# frozen_string_literal: true

require "test_helper"

# The staff console's thin landing endpoints are gated by OrgStaffPolicy, whose
# `staff_area_access?` delegates to role predicates (`operator_or_manager?`,
# `can_view?`) that Operator does not implement yet. The gate therefore denies
# every operator, which is the fail-closed behaviour these tests pin: a signed-in
# operator without a staff role gets no more than an anonymous request does.
class Base::Org::StaffConsolePagesTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses, :operator_token_kinds, :operator_token_statuses,
           :operator_token_binding_methods, :operator_token_dbsc_statuses

  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! @host
    @operator = operators(:one)
    @token = OperatorToken.create!(
      staff: @operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: @token)
    access_token = AuthenticationToken.encode(
      @operator, host: @host, session_public_id: @token.public_id,
                 resource_type: "operator", jwt_issuer_id: "surface:BASE_ORG",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    @headers = {
      "Authorization" => "Bearer #{access_token}",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => @host,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }.freeze
  end

  test "audit console denies an operator that holds no staff role" do
    get base_org_audit_index_url(ri: "jp", host: @host), headers: @headers

    assert_response :redirect
    assert_not_equal "ok", response.parsed_body["status"]
  end

  test "billing console denies an operator that holds no staff role" do
    get base_org_billing_index_url(ri: "jp", host: @host), headers: @headers

    assert_response :redirect
  end

  test "iam console denies an operator that holds no staff role" do
    get base_org_iam_index_url(ri: "jp", host: @host), headers: @headers

    assert_response :redirect
  end

  test "system console denies an operator that holds no staff role" do
    get base_org_system_index_url(ri: "jp", host: @host), headers: @headers

    assert_response :redirect
  end

  test "support console denies an operator that holds no staff role" do
    get base_org_support_index_url(ri: "jp", host: @host), headers: @headers

    assert_response :redirect
  end

  test "configuration console denies an operator that holds no staff role" do
    get base_org_configuration_url(ri: "jp", host: @host), headers: @headers

    assert_response :redirect
  end

  test "audit console denies an anonymous request" do
    get base_org_audit_index_url(ri: "jp", host: @host), headers: { "Host" => @host }

    assert_not_equal 200, response.status
  end
end
