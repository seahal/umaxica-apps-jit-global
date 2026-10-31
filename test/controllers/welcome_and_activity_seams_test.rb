# frozen_string_literal: true

require "test_helper"

class WelcomeAndActivitySeamsTest < ActionController::TestCase
  tests Base::Org::WelcomesController
  fixtures :operators

  test "org authenticated welcome offers its own next step and spends the presentation gate once" do
    surface = :org
    actor = operators(:one)
    token = OperatorToken.create!(:authentication_epoch => 0, :staff => actor)
    token.rotate_refresh_token!
    BaseSelectorBootstrapAuthority.call(surface: surface, principal: actor)
    client = OidcClientRegistry.find!("base-#{surface}-ww")
    now = OpOrgGrant.database_now
    rp = OpOrgGrant.create!(
      :authentication_epoch => 0,
      :operator_token => token, :oidc_client_id => client.client_id, :oidc_scope => "openid profile",
      :oidc_jti => SecureRandom.uuid, :oidc_nonce => SecureRandom.hex(16), :oidc_auth_time => now,
      :refresh_token_expires_at => now + 10.minutes,
    )
    access = AuthenticationTokenService.encode(
      actor, host: ENV.fetch("PUBLIC_BASE_STAFF_URL"), resource_type: "operator", session_public_id: token.public_id,
             base_session_public_id: token.public_id, oidc_sid: rp.public_id, oidc_jti: rp.oidc_jti,
             expires_at: now + 10.minutes, scopes: %w(openid profile), issuer: OidcIssuer.for_client(client),
             audiences: [client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
             subject: OidcSubject.for(actor, resource_type: "operator"), client_id: client.client_id,
    )
    @controller = Base::Org::WelcomesController.new
    @request = ActionController::TestRequest.create(Base::Org::WelcomesController)
    @response = Base::Org::WelcomesController.make_response!(@request)
    @request.host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    @request.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access
    @request.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = rp.issue_refresh_token!
    gate = { "remaining" => 1, "expires_at" => (1.minute.from_now).to_i }
    get :show, params: { ri: "jp" }, session: { "org_sign_in_welcome" => gate }

    assert_response :success
    assert_equal "/dashboard?ri=jp",
                 JSON.parse(
                   css_select("script[data-page=app]")
                                        .first.text,
                 ).fetch("props").fetch("next_link").fetch("href")
    assert_nil session["org_sign_in_welcome"]
    get :show, params: { ri: "jp" }

    assert_redirected_to "/dashboard?ri=jp"
    assert_predicate token.reload, :currently_usable?
  end
end
