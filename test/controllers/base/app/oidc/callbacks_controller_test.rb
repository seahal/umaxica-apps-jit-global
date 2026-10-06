# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class BaseAppOidcCallbackRouteTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
  end

  test "the self-RP callback route is owned by Base" do
    assert_routing(
      { method: :get, path: "http://#{@host}/oidc/callback" },
      { controller: "base/app/oidc/callbacks", action: "show" },
    )
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{@host}/oidc/authorization", method: :get)
    end
  end
end
