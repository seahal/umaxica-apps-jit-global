# frozen_string_literal: true

require "test_helper"

class Edit::Org::DashboardsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("PUBLIC_EDIT_STAFF_URL", "edit.org.localhost")
    host! @host
    @staff = operators(:one)
  end

  test "shows a link to each publishing cell for a signed-in operator" do
    authenticate_rp!
    get edit_org_dashboard_path(ri: "jp")

    assert_response :success
    assert_select "a[href=?]", edit_org_publishing_docs_app_entries_path(ri: "jp")
    assert_select "a[href=?]", edit_org_publishing_help_org_entries_path(ri: "jp")
    assert_select "a[href=?]", edit_org_publishing_info_com_entries_path(ri: "jp")
    assert_select "a[href=?]", edit_org_publishing_news_app_entries_path(ri: "jp")
  end

  # The protected page is not a second Sign entry: it points the browser at the passive GET /sign and
  # starts no OIDC flow itself (plans/active/sign-fqdn-integrated-plan.md section 5).
  test "an unauthenticated HTML request is sent to the passive sign entry without starting a flow" do
    get edit_org_dashboard_path(ri: "jp")

    assert_response :redirect
    location = URI.parse(response.location)

    assert_equal @host, location.host
    assert_equal edit_org_sign_show_path, location.path
    assert_equal edit_org_dashboard_path(ri: "jp"), Rack::Utils.parse_nested_query(location.query).fetch("pt")
    assert_nil session["oidc_pending_flows"]
  end

  test "an unauthenticated JSON request keeps the 401 without a redirect" do
    get edit_org_dashboard_path(ri: "jp", format: :json)

    assert_response :unauthorized
    assert_nil response.location
    assert_nil session["oidc_pending_flows"]
  end

  private

  def authenticate_rp!
    client = OidcClientRegistry.find!("edit-org")
    token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    rp_session = OperatorRpSession.create!(
      operator_token: token,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = AuthenticationTokenService.encode(
      @staff,
      host: @host,
      resource_type: "operator",
      session_public_id: token.public_id,
      base_session_public_id: token.public_id,
      oidc_sid: rp_session.public_id,
      oidc_jti: rp_session.oidc_jti,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(client),
      audiences: [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      subject: OidcSubject.for(@staff, resource_type: "operator"),
      client_id: client.client_id,
    )
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = rp_session.issue_refresh_token!
  end
end
