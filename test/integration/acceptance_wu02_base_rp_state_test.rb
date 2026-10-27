# typed: false
# frozen_string_literal: true

require "test_helper"

class AcceptanceWu02BaseRpStateTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "A02-12: Base Welcome and Selector work from RP credentials without an Auth Rails session" do
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    root = ClientToken.create!(
      authentication_epoch: 0,
      user: actor,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    client = OidcClientRegistry.find!("base-app-ww")
    rp_session = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: root,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      refresh_token_expires_at: 1.hour.from_now,
    )
    access_token = AuthenticationTokenService.encode(
      actor,
      host: base_host,
      resource_type: "client",
      session_public_id: root.public_id,
      base_session_public_id: root.public_id,
      oidc_sid: rp_session.public_id,
      oidc_jti: rp_session.oidc_jti,
      expires_at: 5.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(client),
      audiences: [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      subject: OidcSubject.for(actor, resource_type: "client"),
      client_id: client.client_id,
    )
    ["/welcome?ri=jp", "/selector?ri=jp"].each do |path|
      browser = open_session
      browser.https!
      browser.host!(base_host)
      browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token
      browser.get(path)

      if path.start_with?("/welcome")
        assert_equal 200, browser.response.status, path
      else
        assert_equal 302, browser.response.status, path
        assert_equal base_host, URI.parse(browser.response.location).host
        assert_equal "/dashboard", URI.parse(browser.response.location).path
      end

      assert_nil browser.cookies["__Host-auth_sid"], "Base must not need the Auth ceremony cookie"
      assert_nil browser.cookies["auth_sid"], "Base must not need the Auth ceremony cookie"
    end
  end
end
