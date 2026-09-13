# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Org::LobbiesControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_token_kinds

  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    @staff = operators(:one)
    host! @host
  end

  test "unauthenticated get renders the lobby" do
    get base_org_lobby_url(host: @host, ri: "jp")

    assert_response :success
    assert_equal "base/org/lobbies/show", inertia_component
    assert_equal I18n.t("base.shared.lobby.title"), inertia_props.fetch("title")
    assert_nil inertia_props["notice"]
  end

  test "authenticated get redirects to the dashboard" do
    token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)

    get base_org_lobby_url(host: @host, ri: "jp"),
        headers: as_staff_headers(@staff, host: @host, session_public_id: token.public_id)

    assert_response :found
    assert_equal base_org_dashboard_path(ri: "jp"), URI.parse(response.location).request_uri
  end
end
