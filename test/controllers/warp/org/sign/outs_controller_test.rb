# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../../../support/rp_cell_sign_out_helper"
# require "helpers/global_test_support"

class Warp::Org::Sign::OutsControllerTest < ActionDispatch::IntegrationTest
  include RpCellSessionHelper
  include RpCellSignOutHelper

  fixtures :operators, :operator_token_kinds

  setup do
    @host = ENV.fetch("PUBLIC_WARP_STAFF_URL")
    host! @host
    https!
  end

  test "get sign out renders confirmation without mutation" do
    operator = operators(:one)
    token = OperatorToken.create!(authentication_epoch: 0, staff: operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    auth_refresh_token = token.rotate_refresh_token!
    auth_refresh_digest = token.reload.refresh_token_digest
    auth_refresh_generation = token.refresh_token_generation
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = auth_refresh_token

    get edit_warp_org_sign_out_url(ri: "jp"), headers: session_headers(operator, token)

    assert_response :success
    assert_equal "strict-origin", response.headers["Referrer-Policy"]
    assert_equal "warp/org/sign/outs/edit", inertia_component
    assert_equal warp_org_sign_out_path, URI.parse(inertia_props.dig("form", "action")).path
    assert_predicate token.reload, :currently_usable?
    assert_equal auth_refresh_digest, token.refresh_token_digest
    assert_equal auth_refresh_generation, token.refresh_token_generation
  end

  test "post sign out redirects to the registered Visa end-session endpoint" do
    operator = operators(:one)
    token = OperatorToken.create!(authentication_epoch: 0, staff: operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    auth_refresh_token = token.rotate_refresh_token!
    auth_refresh_digest = token.reload.refresh_token_digest
    auth_refresh_generation = token.refresh_token_generation
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = auth_refresh_token
    authenticate_rp!(operator, token)

    stops_before = OpOrgAuthorityStop.count
    post_rp_cell_sign_out(warp_org_sign_out_url(ri: "jp"))

    assert_equal stops_before, OpOrgAuthorityStop.count
    assert_rp_cell_sign_out_handoff!(client_id: "warp-org-jp", region: "jp")
    assert_predicate token.reload, :currently_usable?
    assert_equal auth_refresh_digest, token.refresh_token_digest
    assert_equal auth_refresh_generation, token.refresh_token_generation
  end

  test "sign out succeeds without an ID Token hint and retains the default strict referrer policy" do
    operator = operators(:one)
    token = OperatorToken.create!(authentication_epoch: 0, staff: operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    authenticate_rp!(operator, token)

    post_rp_cell_sign_out(warp_org_sign_out_url(ri: "jp"))

    assert_equal "strict-origin-when-cross-origin", response.headers["Referrer-Policy"]
    assert_rp_cell_sign_out_handoff!(client_id: "warp-org-jp", region: "jp")
  end

  test "same-origin proof permits sign out while cross-site requests remain refused" do
    operator = operators(:one)
    token = OperatorToken.create!(authentication_epoch: 0, staff: operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    authenticate_rp!(operator, token)
    previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    get(edit_warp_org_sign_out_url(ri: "jp"))

    assert_response :success
    csrf_token = css_select('meta[name="csrf-token"]').first["content"]
    headers = { "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin" }
    post_rp_cell_sign_out(
      warp_org_sign_out_url(ri: "jp"), params: { authenticity_token: csrf_token }, headers: headers,
    )

    assert_rp_cell_sign_out_handoff!(client_id: "warp-org-jp", region: "jp")

    operator = operators(:two)
    replacement_token = OperatorToken.create!(
      authentication_epoch: 0, staff: operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
    )
    authenticate_rp!(operator, replacement_token)
    get(edit_warp_org_sign_out_url(ri: "jp"))
    replacement_csrf = css_select('meta[name="csrf-token"]').first["content"]
    post_rp_cell_sign_out(
      warp_org_sign_out_url(ri: "jp"), params: { authenticity_token: replacement_csrf }, headers: {
        "Origin" => "https://attacker.example", "Sec-Fetch-Site" => "cross-site",
      },
    )

    assert_response :unprocessable_content
    assert_predicate @rp_cell_session.reload, :active?
    assert_empty @rp_cell_revocation_calls
  ensure
    ActionController::Base.allow_forgery_protection = previous_forgery_protection
  end

  test "sign-out launch does not issue a Visa Preference generation before logout commits" do
    operator = operators(:sample_staff)
    token = OperatorToken.create!(authentication_epoch: 0, staff: operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!
    authenticate_rp!(operator, token)
    post_rp_cell_sign_out(warp_org_sign_out_url(ri: "jp"))

    assert_response :see_other
    assert_nil cookies[PreferenceCookieName.anonymous_jwt]
  end

  test "get sign out without a one-shot notice is not found" do
    get warp_org_sign_out_url(ri: "jp")

    assert_response :not_found
    assert_equal "no-referrer", response.headers["Referrer-Policy"]
  end

  private

  def authenticate_rp!(operator, token)
    authenticate_rp_cell_for_sign_out!(client_id: "warp-org-jp", actor: operator, root_token: token)
  end

  def session_headers(operator, token)
    authenticate_rp!(operator, token) unless @rp_cell_session
    { "Host" => @host }
  end
end
