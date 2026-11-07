# typed: false
# frozen_string_literal: true

require "test_helper"

class Palm::App::RootsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_token_kinds

  setup do
    host! ENV.fetch("PUBLIC_PALM_SERVICE_URL")
    https!
  end

  test "renders the anonymous root without shared caching" do
    get palm_app_root_path(ri: "jp")

    assert_response :success
    assert_equal "palm/app/roots/index", inertia_component
    assert_nil response.location
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end

  test "treats an invalid RP access credential as signed out" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = "not-a-jwt"

    get palm_app_root_path(ri: "jp")

    assert_response :success
    assert_equal "palm/app/roots/index", inertia_component
    assert_nil response.location
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end

  test "refuses an authenticated root request without redirecting" do
    client = clients(:one)
    root_token = ClientToken.create!(
      authentication_epoch: 0,
      user: client,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )
    oidc_client = OidcClientRegistry.find!("palm-app-jp")
    rp_session = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: root_token,
      oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = AuthenticationTokenService.encode(
      client,
      host: ENV.fetch("PUBLIC_PALM_SERVICE_URL"),
      resource_type: "client",
      session_public_id: root_token.public_id,
      base_session_public_id: root_token.public_id,
      oidc_sid: rp_session.public_id,
      oidc_jti: rp_session.oidc_jti,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(oidc_client),
      audiences: [oidc_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(oidc_client),
      subject: OidcSubject.for(client, resource_type: "client"),
      client_id: oidc_client.client_id,
    )
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = rp_session.issue_refresh_token!

    get palm_app_root_path(ri: "jp")

    assert_response :forbidden
    assert_nil response.location
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end
end
