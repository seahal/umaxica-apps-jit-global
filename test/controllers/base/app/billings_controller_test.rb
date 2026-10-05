# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::BillingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
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

    access_token = AuthenticationToken.encode(
      @client,
      host: @host,
      session_public_id: @client_token.public_id,
      resource_type: "client",
      jwt_issuer_id: "surface:BASE_APP",
    )

    get base_app_billings_url(ri: "jp"), headers: {
      "Authorization" => "Bearer #{access_token}",
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
