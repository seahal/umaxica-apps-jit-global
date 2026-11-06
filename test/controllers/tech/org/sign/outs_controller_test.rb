# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../../../support/rp_cell_sign_out_helper"

class Tech::Org::Sign::OutsControllerTest < ActionDispatch::IntegrationTest
  include RpCellSessionHelper
  include RpCellSignOutHelper

  fixtures :operators, :operator_statuses, :operator_token_kinds

  setup do
    @host = ENV.fetch("PUBLIC_TECH_STAFF_URL")
    host! @host
    https!
    @operator = operators(:one)
  end

  test "an operator can start sign-out after tech access is revoked" do
    previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    grant = OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: operators(:two),
      origin: "grant",
      capability: OperatorCapabilityGrant::TECH_ACCESS,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )
    root_token = OperatorToken.create!(
      authentication_epoch: 0, staff: @operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
    )
    authenticate_rp_cell_for_sign_out!(client_id: "tech-org-ww", actor: @operator, root_token:)
    grant.update!(
      revoked_at: Time.current,
      revoked_by_operator: operators(:two),
      revoke_reason_code: "duty_ended",
    )

    get(tech_org_dashboard_path(ri: "jp"))

    assert_response :forbidden
    assert_select "h1", I18n.t("tech.org.access_denial.heading")
    assert_not_includes response.body, I18n.t("tech.org.dashboard.empty_state")
    authenticity_token = css_select('input[name="authenticity_token"]').first["value"]

    stops_before = OpOrgAuthorityStop.count
    post_rp_cell_sign_out(
      tech_org_sign_out_path(ri: "jp"),
      params: { authenticity_token: },
      headers: { "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin" },
    )

    assert_equal stops_before, OpOrgAuthorityStop.count
    assert_rp_cell_sign_out_handoff!(client_id: "tech-org-ww", region: "jp")
    assert_predicate root_token.reload, :currently_usable?
    assert_equal "no-store", response.headers["Cache-Control"]
  ensure
    ActionController::Base.allow_forgery_protection = previous_forgery_protection
  end

  test "cross-site sign-out without a valid authenticity token is refused" do
    previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: operators(:two),
      origin: "grant",
      capability: OperatorCapabilityGrant::TECH_ACCESS,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )
    root_token = OperatorToken.create!(
      authentication_epoch: 0, staff: @operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
    )
    authenticate_rp_cell_for_sign_out!(client_id: "tech-org-ww", actor: @operator, root_token:)

    post_rp_cell_sign_out(
      tech_org_sign_out_path(ri: "jp"), headers: {
        "Origin" => "https://attacker.example",
        "Sec-Fetch-Site" => "cross-site",
      },
    )

    assert_response :unprocessable_content
    assert_predicate @rp_cell_session.reload, :active?
    assert_empty @rp_cell_revocation_calls
  ensure
    ActionController::Base.allow_forgery_protection = previous_forgery_protection
  end
end
