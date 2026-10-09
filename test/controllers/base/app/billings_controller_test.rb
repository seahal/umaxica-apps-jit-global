# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::BillingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    @client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @client_token = ClientToken.create!(user: @client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    host! @host
  end

  test "index declares private authentication" do
    assert_equal :private, Base::App::BillingsController.authentication_mode_for(:index)
  end

  test "index renders for signed in clients" do
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @client)
    BaseSelectorAuthority.prepare(surface: :app, principal: @client, session: @client_token)

    rp_cookie =
      begin
        fixture_root = @client_token
        fixture_actor = @client
        fixture_host = @host
        fixture_root.rotate_refresh_token! unless fixture_root.device_session.current_refresh_token_id
        fixture_client = OidcClientRegistry.find!("base-app-ww")
        @base_rp_fixture_credentials ||= {}
        fixture_key = [fixture_client.client_id, fixture_root.public_id]
        unless @base_rp_fixture_credentials[fixture_key]
          fixture_now = ClientRpSession.database_now
          fixture_rp = ClientRpSession.create!(
            client_token: fixture_root, oidc_client_id: fixture_client.client_id,
            oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
            oidc_nonce: SecureRandom.hex(16), oidc_auth_time: fixture_now,
            refresh_token_expires_at: fixture_now + 1.hour,
          )
          fixture_access = AuthenticationTokenService.encode(
            fixture_actor, host: fixture_host, resource_type: "client",
                           session_public_id: fixture_root.public_id, base_session_public_id: fixture_root.public_id,
                           oidc_sid: fixture_rp.public_id, oidc_jti: fixture_rp.oidc_jti,
                           expires_at: fixture_now + 1.hour, scopes: %w(openid profile),
                           issuer: OidcIssuer.for_client(fixture_client), audiences: [fixture_client.aud],
                           jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(fixture_client),
                           subject: OidcSubject.for(
                             fixture_actor,
                             resource_type: "client",
                           ), client_id: fixture_client.client_id,
          )
          fixture_refresh = fixture_rp.issue_refresh_token!
          @base_rp_fixture_credentials[fixture_key] = [
            "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(fixture_access)}",
            "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(fixture_refresh)}",
          ].join("; ")
        end
        @base_rp_fixture_credentials.fetch(fixture_key)
      end

    get base_app_billings_url(ri: "jp"), headers: {
      "Cookie" => rp_cookie,
      "Client-Agent" => "Mozilla/5.0",
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "X-TEST-CURRENT-USER" => @client.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @client_token.public_id,
    }

    assert_response :success
    assert_equal "base/app/billings/index", inertia_component
    assert_equal "Billings", inertia_props.fetch("title")
    assert_equal I18n.t("billings.signed_in_required"), inertia_props.fetch("description")
    assert_equal(
      { "label" => I18n.t("actions.up"), "href" => base_app_dashboard_path(ri: "jp") },
      inertia_props.fetch("up_link"),
    )
  end
end
