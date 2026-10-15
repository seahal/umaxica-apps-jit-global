# frozen_string_literal: true

require "test_helper"
require_relative "../support/browser_rp_logout_flow_helper"

# AT-001: one global sign-out revokes the parent and every unrevoked RP row of it, below, at and
# above the sibling count boundary, leaves an already-revoked historical row untouched, and makes a
# sibling RP refuse and clear its still-unexpired credentials at the next request.
class OidcRpLogoutSiblingScopeTest < ActionDispatch::IntegrationTest
  include BrowserRpLogoutFlowHelper

  setup do
    @core_host = ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    @base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    @warp_host = ENV.fetch("PUBLIC_WARP_SERVICE_URL")
    https!
    @user = clients(:one)
    @root_token = ClientToken.create!(
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    @core_session = create_rp_session("core-app")
  end

  test "zero siblings: the parent and the origin row are revoked" do
    sign_out_globally

    assert_not_predicate @root_token.reload, :currently_usable?
    assert_predicate @core_session.reload, :revoked?
  end

  test "one sibling is revoked with the parent" do
    sibling = create_rp_session("warp-app")

    sign_out_globally

    assert_predicate sibling.reload, :revoked?
  end

  test "several siblings are revoked with the parent and another parent stays intact" do
    siblings = %w(warp-app palm-app).map { |client_id| create_rp_session(client_id) }
    other_root = ClientToken.create!(
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    other_child = create_rp_session("warp-app", root_token: other_root)

    sign_out_globally

    siblings.each { |sibling| assert_predicate sibling.reload, :revoked? }
    assert_predicate other_root.reload, :currently_usable?
    assert_predicate other_child.reload, :active?
  end

  test "an already-revoked historical row keeps its original revocation" do
    historical = create_rp_session("warp-app")
    historical.revoke!(status: "success")
    revoked_at = historical.reload.revoked_at
    status = historical.last_logout_status

    travel 1.minute do
      sign_out_globally
    end

    assert_equal revoked_at, historical.reload.revoked_at
    assert_equal status, historical.last_logout_status
  end

  test "a sibling RP refuses and clears its unexpired credentials at the next request" do
    sibling = create_rp_session("warp-app")
    access, refresh = warp_credentials(sibling)

    sign_out_globally

    # The sibling is another site in the same browser; start from its own cookie jar.
    reset!
    https!
    host!(@warp_host)
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = refresh
    get "/dashboard"

    assert_not_equal 200, response.status
    assert_credentials_cleared

    cookies.delete(OidcRpBrowserCredentialContract::ACCESS_COOKIE)
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = refresh
    get "/dashboard"

    assert_not_equal 200, response.status
    assert_credentials_cleared(OidcRpBrowserCredentialContract::REFRESH_COOKIE)
  end

  test "positive control: the sibling credentials are accepted before the sign-out" do
    sibling = create_rp_session("warp-app")
    access, refresh = warp_credentials(sibling)

    host!(@warp_host)
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = refresh
    get "/dashboard"

    assert_response :success
  end

  private

  def sign_out_globally
    challenge, origin_cookie = start_sign_out
    confirm_at_authority(challenge, origin_cookie)

    assert_response :see_other
  end

  def warp_credentials(rp_session)
    client = OidcClientRegistry.find!("warp-app")
    access = AuthenticationTokenService.encode(
      @user,
      host: @warp_host,
      resource_type: "client",
      session_public_id: @root_token.public_id,
      base_session_public_id: @root_token.public_id,
      oidc_sid: rp_session.public_id,
      oidc_jti: rp_session.oidc_jti,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(client),
      audiences: [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      subject: OidcSubject.for(@user, resource_type: "client"),
      client_id: client.client_id,
    )
    [access, rp_session.issue_refresh_token!]
  end

  def assert_credentials_cleared(*names)
    names = [OidcRpBrowserCredentialContract::ACCESS_COOKIE,
             OidcRpBrowserCredentialContract::REFRESH_COOKIE,] if names.empty?
    lines = Array(response.headers["Set-Cookie"]).flat_map { |value| value.to_s.split("\n") }
    names.each do |name|
      cleared = lines.find { |line| line.start_with?("#{name}=") }

      assert cleared, "expected #{name} to be cleared"
      assert_match(/max-age=0|expires=Thu, 01 Jan 1970/i, cleared)
    end
  end
end
