# frozen_string_literal: true

require "test_helper"

# AT-008: a Browser RP decides from the parent state on the realm Ticket writer on every request. When
# that writer cannot be read the RP fails closed, and the decision is never served from a reading
# replica or a query cache: in the test environment the reading role points at a separate,
# unsynchronised replica database, so the positive control can only pass by reading the writer, and
# a revocation committed between two requests inside one cached block is still seen.
class BrowserRpParentStateFailClosedTest < ActionDispatch::IntegrationTest
  setup do
    @warp_host = ENV.fetch("PUBLIC_WARP_SERVICE_URL")
    host!(@warp_host)
    https!
    @user = clients(:one)
    @root_token = ClientToken.create!(
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    @client = OidcClientRegistry.find!("warp-app")
    @rp_session = ClientRpSession.create!(
      client_token: @root_token,
      oidc_client_id: @client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    present_credentials
  end

  test "positive control: an active parent is accepted from the writer" do
    get "/dashboard"

    assert_response :success
  end

  test "an unreadable Ticket writer fails closed without treating the user as authenticated" do
    unreadable = ->(*) { raise ActiveRecord::ConnectionNotEstablished, "app ticket writer unavailable" }

    ClientRpSession.stub(:includes, unreadable) do
      get "/dashboard"
    end

    assert_response :service_unavailable
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    assert_not_includes response.body, "warp/app/dashboards/show"
  end

  test "a revocation committed between requests is seen even with the query cache enabled" do
    ActiveRecord::Base.cache do
      get "/dashboard"

      assert_response :success

      AuthenticationLogoutCurrentSession.call(resource: @user, token: @root_token, reason: "user_logout")
      present_credentials
      get "/dashboard"
    end

    assert_not_equal 200, response.status
    assert_not_includes response.body, "warp/app/dashboards/show"
  end

  private

  def present_credentials
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = AuthenticationTokenService.encode(
      @user,
      host: @warp_host,
      resource_type: "client",
      session_public_id: @root_token.public_id,
      base_session_public_id: @root_token.public_id,
      oidc_sid: @rp_session.public_id,
      oidc_jti: @rp_session.oidc_jti,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(@client),
      audiences: [@client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(@client),
      subject: OidcSubject.for(@user, resource_type: "client"),
      client_id: @client.client_id,
    )
  end
end
