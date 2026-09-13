# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::LobbiesControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_token_kinds, :client_token_statuses

  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    @user = clients(:one)
    host! @host
  end

  test "unauthenticated get renders the lobby" do
    get base_app_lobby_url(host: @host, ri: "jp")

    assert_response :success
    assert_equal "base/app/lobbies/show", inertia_component
    assert_equal I18n.t("base.shared.lobby.title"), inertia_props.fetch("title")
    assert_equal I18n.t("base.shared.lobby.sign_in"), inertia_props.fetch("sign_in").fetch("label")
    assert_includes inertia_props.fetch("sign_in").fetch("href"),
                    base_app_oidc_authorization_path(ri: "jp", screen_hint: "signin")
    assert_nil inertia_props["notice"]
  end

  test "authenticated get redirects to the dashboard" do
    token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    get base_app_lobby_url(host: @host, ri: "jp"),
        headers: as_user_headers(@user, host: @host, session_public_id: token.public_id)

    assert_response :found
    assert_equal base_app_dashboard_path(ri: "jp"), URI.parse(response.location).request_uri
  end
end
