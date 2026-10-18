# typed: false
# frozen_string_literal: true

require "test_helper"

class GuidRouteContractTest < ActionDispatch::IntegrationTest
  GUID_HOST = ENV.fetch("PRIVATE_GUID_SERVICE_URL", "guid.net.localhost")

  test "guid host routes only the dedicated surface contract" do
    {
      "/" => ["guid/net/roots", "index"],
      "/health" => ["guid/net/healths", "show"],
      "/health/liveness" => ["guid/net/health/livenesses", "show"],
      "/health/readiness" => ["guid/net/health/readinesses", "show"],
      "/health/startup" => ["guid/net/health/startups", "show"],
      "/revision" => ["guid/net/revisions", "show"],
      "/api/v0/health.json" => ["guid/net/api/v0/healths", "show"],
      "/api/v0/revision.json" => ["guid/net/api/v0/revisions", "show"],
      "/api/v0/resources/example-guid" => ["guid/net/api/v0/resources", "show"],
    }.each do |path, (controller, action)|
      recognized = Rails.application.routes.recognize_path("http://#{GUID_HOST}#{path}", method: :get)

      assert_equal controller, recognized[:controller], path
      assert_equal action, recognized[:action], path
    end
  end

  test "guid resource route is not exposed through another surface host" do
    error =
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{ENV.fetch("PRIVATE_INFO_SERVICE_URL", "info.app.localhost")}/api/v0/resources/example-guid",
          method: :get,
        )
      end

    assert_match(/No route matches/, error.message)
  end
end
