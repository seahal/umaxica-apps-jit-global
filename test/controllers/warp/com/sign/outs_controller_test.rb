# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Warp::Com::Sign::OutsControllerTest < ActionDispatch::IntegrationTest
  fixtures :visitors, :visitor_token_kinds

  setup do
    @host = ENV.fetch("PUBLIC_WARP_CORPORATE_URL")
    host! @host
  end

  test "get sign out renders confirmation without mutation" do
    visitor = visitors(:reserved_visitor)
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    auth_refresh_token = token.rotate_refresh_token!
    auth_refresh_digest = token.reload.refresh_token_digest
    auth_refresh_generation = token.refresh_token_generation
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = auth_refresh_token

    get edit_warp_com_sign_out_url(ri: "jp"), headers: session_headers(visitor, token)

    assert_response :success
    assert_equal "warp/com/sign/outs/edit", inertia_component
    assert_equal warp_com_sign_out_path, URI.parse(inertia_props.dig("form", "action")).path
    assert_predicate token.reload, :currently_usable?
    assert_equal auth_refresh_digest, token.refresh_token_digest
    assert_equal auth_refresh_generation, token.refresh_token_generation
  end

  test "post sign out redirects to the registered base authority" do
    visitor = visitors(:reserved_visitor)
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    auth_refresh_token = token.rotate_refresh_token!
    auth_refresh_digest = token.reload.refresh_token_digest
    auth_refresh_generation = token.refresh_token_generation
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = auth_refresh_token
    authenticate_rp!(visitor, token)

    post warp_com_sign_out_url(ri: "jp")

    assert_response :see_other
    location = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(location.query.to_s)
    transaction = AcmeLogoutTransaction.find_by!(public_id: query.fetch("logout_challenge"))

    assert_equal "warp", transaction.origin_surface

    assert_equal ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "www.com.localhost"), location.host
    assert_equal "/oidc/logout", location.path
    assert_predicate query["logout_challenge"], :present?
    assert_equal "jp", query["ri"]
    assert_predicate @rp_session.reload, :active?
    assert_predicate token.reload, :currently_usable?
    assert_equal auth_refresh_digest, token.refresh_token_digest
    assert_equal auth_refresh_generation, token.refresh_token_generation
  end

  test "get sign out without a one-shot notice is not found" do
    get warp_com_sign_out_url(ri: "jp")

    assert_response :not_found
  end

  private

  def authenticate_rp!(visitor, token)
    oidc_client = OidcClientRegistry.find!("warp-com")
    @rp_session = VisitorRpSession.create!(
      visitor_token: token,
      oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = AuthenticationTokenService.encode(
      visitor,
      host: @host,
      resource_type: "visitor",
      session_public_id: token.public_id,
      base_session_public_id: token.public_id,
      oidc_sid: @rp_session.public_id,
      oidc_jti: @rp_session.oidc_jti,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(oidc_client),
      audiences: [oidc_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(oidc_client),
      subject: OidcSubject.for(visitor, resource_type: "visitor"),
      client_id: oidc_client.client_id,
    )
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = @rp_session.issue_refresh_token!
  end

  def session_headers(visitor, token)
    token_encoded = AuthenticationToken.encode(
      visitor, host: @host, session_public_id: token.public_id, resource_type: "visitor",
               jwt_issuer_id: "surface:AUTH_COM",
    )
    { "Authorization" => "Bearer #{token_encoded}" }
  end
end
