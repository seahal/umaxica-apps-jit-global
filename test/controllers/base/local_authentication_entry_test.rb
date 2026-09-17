# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseLocalAuthenticationEntryTest < ActionDispatch::IntegrationTest
  SURFACES = [
    {
      name: "app",
      host_env: "PUBLIC_BASE_SERVICE_URL",
      auth_host_env: "PUBLIC_AUTH_SERVICE_URL",
      root_path: :base_app_root_path,
      admission_path: :base_app_root_authentication_path,
      auth_path: :auth_app_sign_in_path,
    },
    {
      name: "com",
      host_env: "PUBLIC_BASE_CORPORATE_URL",
      auth_host_env: "PUBLIC_AUTH_CORPORATE_URL",
      root_path: :base_com_root_path,
      admission_path: :base_com_root_authentication_path,
      auth_path: :auth_com_sign_in_path,
    },
    {
      name: "org",
      host_env: "PUBLIC_BASE_STAFF_URL",
      auth_host_env: "PUBLIC_AUTH_STAFF_URL",
      root_path: :base_org_root_path,
      admission_path: :base_org_root_authentication_path,
      auth_path: :auth_org_sign_in_path,
    },
  ].freeze

  test "anonymous sign-in starts at a Base-owned CSRF-protected local admission for every surface" do
    SURFACES.each do |surface|
      base_host = ENV.fetch(surface.fetch(:host_env))
      auth_host = ENV.fetch(surface.fetch(:auth_host_env))
      host! base_host

      get public_send(surface.fetch(:root_path), ri: "jp")

      assert_response :success, surface.fetch(:name)

      action = inertia_props.fetch("sign_in")

      assert_equal "post", action.fetch("method")
      assert_equal "sign_in", action.fetch("intent")

      target_url = nil
      JumpRtIssuer.stub(:call, ->(**args) { target_url = args.fetch(:url); "signed-jump-token" }) do
        RedirectsJumpGatewayUrl.stub(
          :call,
          ->(_token) { RedirectsTargetResult.ok(kind: :external, source: :test, value: target_url) },
        ) do
          post public_send(surface.fetch(:admission_path), ri: "jp"),
               params: {
                 intent: action.fetch("intent"),
                 authenticity_token: action.fetch("authenticity_token"),
               }
        end
      end

      assert_response :see_other, surface.fetch(:name)
      location = URI.parse(response.location)

      assert_equal auth_host, location.host
      assert_equal public_send(surface.fetch(:auth_path)), location.path
      assert_predicate Rack::Utils.parse_nested_query(location.query)["admission"], :present?
    end
  end

  test "local authentication entry rejects a POST without the form authenticity token" do
    with_forgery_protection do
      host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      host! host

      post base_app_root_authentication_path(ri: "jp"),
           params: { intent: "sign_in" }, headers: { "Sec-Fetch-Site" => "cross-site" }

      assert_response :unprocessable_entity
      assert_nil response.location
    end
  end

  test "local authentication entry rejects an unknown intent before issuing an admission" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    get base_app_root_path(ri: "jp")
    token = inertia_props.fetch("sign_in").fetch("authenticity_token")

    post base_app_root_authentication_path(ri: "jp"),
         params: { intent: "reset_password", authenticity_token: token }

    assert_response :bad_request
    assert_nil response.location
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
