# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../../../support/oidc_rp_logout_hint_helper"
# require "helpers/global_test_support"

class Warp::Org::Sign::OutsControllerTest < ActionDispatch::IntegrationTest
  include OidcRpLogoutHintHelper

  fixtures :operators, :operator_token_kinds

  setup do
    @host = ENV.fetch("PUBLIC_WARP_STAFF_URL")
    host! @host
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
    post warp_org_sign_out_url(ri: "jp")

    assert_response :see_other
    assert_equal stops_before, OpOrgAuthorityStop.count
    location = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_visa_end_session_redirect(query, location, client_id: "warp-org-jp", region: "jp")
    assert_predicate @rp_session.reload, :active?
    assert_predicate token.reload, :currently_usable?
    assert_equal auth_refresh_digest, token.refresh_token_digest
    assert_equal auth_refresh_generation, token.refresh_token_generation
  end

  test "a write that creates the browser preference synchronizes the operator preference mirror" do
    operator = operators(:sample_staff)
    token = OperatorToken.create!(authentication_epoch: 0, staff: operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!
    authenticate_rp!(operator, token)
    mirror = -> { OrgZenithRecord.connected_to(role: :writing) { OperatorPreference.find_by(staff_id: operator.id) } }

    assert_nil mirror.call

    post warp_org_sign_out_url(ri: "jp")

    assert_response :see_other
    assert_predicate cookies[PreferenceCookieName.refresh(surface: :org)], :present?
    assert_not_nil mirror.call
  end

  test "get sign out without a one-shot notice is not found" do
    get warp_org_sign_out_url(ri: "jp")

    assert_response :not_found
  end

  private

  def authenticate_rp!(operator, token)
    oidc_client = OidcClientRegistry.find!("warp-org-jp")
    @rp_session = OpOrgGrant.create!(
      authentication_epoch: 0,
      operator_token: token,
      oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    store_oidc_rp_logout_hint!(@rp_session, operator, oidc_client)
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = AuthenticationTokenService.encode(
      operator,
      host: @host,
      resource_type: "operator",
      session_public_id: token.public_id,
      base_session_public_id: token.public_id,
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
      jwt_issuer_id: "surface:AUTH_ORG",
    )
    { "Authorization" => "Bearer #{token_encoded}" }
  end
end
