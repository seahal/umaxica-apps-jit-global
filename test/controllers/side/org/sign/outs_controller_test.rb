# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Side::Org::Sign::OutsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_token_kinds

  setup do
    @host = ENV.fetch("PUBLIC_SIDE_STAFF_URL")
    host! @host
  end

  test "get sign out renders confirmation without mutation" do
    operator = operators(:one)
    token = OperatorToken.create!(staff: operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)

    get edit_side_org_sign_out_url(ri: "jp"), headers: session_headers(operator, token)

    assert_response :success
    assert_equal "side/org/sign/outs/edit", inertia_component
    assert_equal side_org_sign_out_path, URI.parse(inertia_props.dig("form", "action")).path
    assert_predicate token.reload, :currently_usable?
  end

  test "post sign out redirects to base oidc logout with completion state" do
    operator = operators(:one)
    token = OperatorToken.create!(staff: operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    authenticate_rp!(operator, token)

    post side_org_sign_out_url(ri: "jp")

    assert_response :success
    assert_select "form#sign-out-handoff-form[method=?]", "post", count: 1
    location = URI.parse(css_select("form#sign-out-handoff-form").first["action"])
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal ENV.fetch("PUBLIC_BASE_STAFF_URL", "www.org.localhost"), location.host
    assert_equal "/oidc/logout", location.path
    assert_predicate query["id_token_hint"], :present?
    assert_equal side_org_sign_out_url(ri: "jp", protocol: "https"), query["post_logout_redirect_uri"]
    assert_predicate query["logout_challenge"], :present?
    assert_predicate @rp_session.reload, :revoked?
    assert_predicate token.reload, :currently_usable?
  end

  test "get sign out without a one-shot notice is not found" do
    get side_org_sign_out_url(ri: "jp")

    assert_response :not_found
  end

  private

  def authenticate_rp!(operator, token)
    oidc_client = OidcClientRegistry.find!("side-org")
    @rp_session = OperatorRpSession.create!(
      operator_token: token,
      oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = AuthenticationTokenService.encode(
      operator,
      host: @host,
      resource_type: "operator",
      session_public_id: token.public_id,
      oidc_sid: @rp_session.public_id,
      oidc_jti: @rp_session.oidc_jti,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(oidc_client),
      audiences: [oidc_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(oidc_client),
      subject: OidcSubject.for(operator, resource_type: "operator"),
      client_id: oidc_client.client_id,
    )
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = @rp_session.issue_refresh_token!
  end

  def session_headers(operator, token)
    token_encoded = AuthenticationToken.encode(
      operator,
      host: @host,
      session_public_id: token.public_id,
      resource_type: "operator",
      jwt_issuer_id: "surface:SIGN_ORG",
    )
    { "Authorization" => "Bearer #{token_encoded}" }
  end
end
