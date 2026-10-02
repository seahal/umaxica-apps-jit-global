# typed: false
# frozen_string_literal: true

require "test_helper"

# Base's neutral entry: GET /sign only renders, POST /sign starts Auth at /sign/in, and the old
# root POST with its Sign in / Sign up choice is gone
# (adr/sign-neutral-entry-and-logout-target-authorization.md).
class BaseLocalAuthenticationEntryTest < ActionDispatch::IntegrationTest
  SURFACES = [
    {
      name: "app",
      host_env: "PUBLIC_BASE_SERVICE_URL",
      auth_host_env: "PUBLIC_AUTH_SERVICE_URL",
      root_path: :base_app_root_path,
      sign_path: :base_app_sign_show_path,
      auth_path: :auth_app_sign_in_path,
    },
    {
      name: "com",
      host_env: "PUBLIC_BASE_CORPORATE_URL",
      auth_host_env: "PUBLIC_AUTH_CORPORATE_URL",
      root_path: :base_com_root_path,
      sign_path: :base_com_sign_show_path,
      auth_path: :auth_com_sign_in_path,
    },
    {
      name: "org",
      host_env: "PUBLIC_BASE_STAFF_URL",
      auth_host_env: "PUBLIC_AUTH_STAFF_URL",
      root_path: :base_org_root_path,
      sign_path: :base_org_sign_show_path,
      auth_path: :auth_org_sign_in_path,
    },
  ].freeze

  test "the anonymous root offers one neutral link to GET sign and no sign up choice" do
    SURFACES.each do |surface|
      host! ENV.fetch(surface.fetch(:host_env))

      get public_send(surface.fetch(:root_path), ri: "jp")

      assert_response :success, surface.fetch(:name)
      assert_equal public_send(surface.fetch(:sign_path), ri: "jp"), inertia_props.fetch("sign_in").fetch("href")
      assert_nil inertia_props["sign_up"], surface.fetch(:name)
    end
  end

  test "GET sign renders one POST form and issues no admission" do
    SURFACES.each do |surface|
      host! ENV.fetch(surface.fetch(:host_env))

      BaseAuthAdmissionCoordinator.stub(:issue_local_entry!, ->(**) { flunk("GET /sign must not issue") }) do
        get public_send(surface.fetch(:sign_path), ri: "jp")
      end

      assert_response :success, surface.fetch(:name)
      assert_includes response.headers["Cache-Control"], "no-store"
      assert_includes response.body, %(action="#{public_send(surface.fetch(:sign_path), ri: "jp")}")
      assert_includes response.body, %(method="post")
      assert_not_includes response.body, "sign_up"
    end
  end

  test "POST sign starts Auth at sign in with a Base-issued admission, ignoring a sign up intent" do
    SURFACES.each do |surface|
      auth_host = ENV.fetch(surface.fetch(:auth_host_env))
      host! ENV.fetch(surface.fetch(:host_env))

      target_url = nil
      JumpRtIssuer.stub(:call, ->(**args) { target_url = args.fetch(:url); "signed-jump-token" }) do
        RedirectsJumpGatewayUrl.stub(
          :call,
          ->(_token) { RedirectsTargetResult.ok(kind: :external, source: :test, value: target_url) },
        ) do
          post public_send(surface.fetch(:sign_path), ri: "jp"), params: { intent: "sign_up" }
        end
      end

      assert_response :see_other, surface.fetch(:name)
      location = URI.parse(response.location)

      assert_equal auth_host, location.host
      assert_equal public_send(surface.fetch(:auth_path)), location.path
      query = Rack::Utils.parse_nested_query(location.query)

      assert_predicate query["entry_ref"], :present?
      assert_nil query["intent"]
    end
  end

  test "POST sign without the form authenticity token is rejected" do
    with_forgery_protection do
      host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")

      post base_app_sign_show_path(ri: "jp"), headers: { "Sec-Fetch-Site" => "cross-site" }

      assert_response :unprocessable_entity
      assert_nil response.location
    end
  end

  test "POST sign from an authenticated browser is refused with a plain 403 and issues nothing" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host

    BaseAuthAdmissionCoordinator.stub(:issue_local_entry!, ->(**) { flunk("must not issue") }) do
      post base_app_sign_show_path(ri: "jp"), headers: as_user_headers(clients(:one), host: host)
    end

    assert_response :forbidden
    assert_equal I18n.t("errors.messages.operation_not_permitted"), response.body
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_nil response.location
  end

  test "the old root POST is not routable" do
    SURFACES.each do |surface|
      host = ENV.fetch(surface.fetch(:host_env))

      assert_raises(ActionController::RoutingError, surface.fetch(:name)) do
        Rails.application.routes.recognize_path("https://#{host}/", method: :post)
      end
    end
  end

  private

  def with_forgery_protection
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end
end
