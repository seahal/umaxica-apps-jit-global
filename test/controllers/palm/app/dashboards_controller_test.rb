# typed: false
# frozen_string_literal: true

require "test_helper"

class Palm::App::DashboardsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_token_kinds

  setup do
    @host = ENV.fetch("PUBLIC_PALM_SERVICE_URL")
    host! @host
  end

  test "authenticated Palm browser credentials render the protected dashboard" do
    client = clients(:one)
    root_token = ClientToken.create!(user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    oidc_client = OidcClientRegistry.find!("palm-app")
    rp_session = ClientRpSession.create!(
      client_token: root_token,
      oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    access_token = AuthenticationTokenService.encode(
      client,
      host: @host,
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
    refresh_token = rp_session.issue_refresh_token!
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = refresh_token

    get "/dashboard", params: { ri: "jp" }

    assert_response :success
    assert_equal "palm/app/dashboards/show", inertia_component
    assert_equal I18n.t("palm.app.dashboard.title"), inertia_props.fetch("title")
    assert_equal I18n.t("palm.app.dashboard.description"), inertia_props.fetch("description")
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal edit_palm_app_sign_out_path(ri: "jp"),
                 inertia_props.fetch("sections").first.fetch("items").last.fetch("href")
  end

  test "anonymous dashboard request goes to passive Palm sign-in without creating an OIDC flow" do
    get "/dashboard", params: { ri: "jp" }

    assert_response :redirect
    location = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(location.query)

    assert_equal @host, location.host
    assert_equal palm_app_sign_show_path, location.path
    assert_equal "/dashboard?ri=jp", query.fetch("pt")
    assert_nil session[OidcSsoInitiator::OIDC_PENDING_FLOWS_SESSION_KEY]
  end
end
