# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Com::LobbiesControllerTest < ActionDispatch::IntegrationTest
  fixtures :visitors, :visitor_statuses, :visitor_token_kinds, :visitor_token_statuses

  setup do
    @host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")
    @visitor = visitors(:reserved_visitor)
    host! @host
  end

  test "unauthenticated get renders the lobby" do
    get base_com_lobby_url(host: @host, ri: "jp")

    assert_response :success
    assert_equal "base/com/lobbies/show", inertia_component
    assert_equal I18n.t("base.shared.lobby.title"), inertia_props.fetch("title")
    assert_nil inertia_props["notice"]
  end

  test "authenticated get redirects to the dashboard" do
    token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)

    get base_com_lobby_url(host: @host, ri: "jp"),
        headers: as_visitor_headers(@visitor, host: @host, session_public_id: token.public_id)

    assert_response :found
    assert_equal base_com_dashboard_path(ri: "jp"), URI.parse(response.location).request_uri
  end
end
