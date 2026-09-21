# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Side::Com::Sign::OutsControllerTest < ActionDispatch::IntegrationTest
  fixtures :visitors, :visitor_token_kinds

  setup do
    @host = ENV.fetch("PUBLIC_SIDE_CORPORATE_URL")
    host! @host
  end

  test "get sign out renders confirmation without mutation" do
    visitor = visitors(:reserved_visitor)
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)

    get edit_side_com_sign_out_url(ri: "jp"), headers: session_headers(visitor, token)

    assert_response :success
    assert_equal "side/com/sign/outs/edit", inertia_component
    assert_equal side_com_sign_out_path, URI.parse(inertia_props.dig("form", "action")).path
    assert_predicate token.reload, :currently_usable?
  end

  test "post sign out redirects to base oidc logout with completion state" do
    visitor = visitors(:reserved_visitor)
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    authenticate_rp!(visitor, token)

    post side_com_sign_out_url(ri: "jp")

    assert_response :success
    assert_select "form#sign-out-handoff-form[method=?]", "post", count: 1
    location = URI.parse(css_select("form#sign-out-handoff-form").first["action"])
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "www.com.localhost"), location.host
    assert_equal "/oidc/logout", location.path
    assert_predicate query["id_token_hint"], :present?
    assert_equal side_com_sign_out_url(ri: "jp", protocol: "https"), query["post_logout_redirect_uri"]
    assert_predicate query["logout_challenge"], :present?
    assert_predicate @rp_session.reload, :revoked?
    assert_predicate token.reload, :currently_usable?
  end

  test "get sign out without a one-shot notice is not found" do
    get side_com_sign_out_url(ri: "jp")

    assert_response :not_found
  end

  private

  def authenticate_rp!(visitor, token)
    oidc_client = OidcClientRegistry.find!("side-com")
    @rp_session = VisitorRpSession.create!(
      visitor_token: token,
      oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = AuthenticationTokenService.encode(
      visitor,
      host: @host,
      resource_type: "visitor",
      session_public_id: token.public_id,
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
               jwt_issuer_id: "surface:SIGN_COM",
    )
    { "Authorization" => "Bearer #{token_encoded}" }
  end
end
