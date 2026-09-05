# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class EdgeHealthRoutesTest < ActionDispatch::IntegrationTest
  test "legacy edge health routes are not routed" do
    [
      ENV.fetch("PRIVATE_BASE_CORPORATE_URL", "www.com.localhost"),
      ENV.fetch("PRIVATE_BASE_SERVICE_URL", "www.app.localhost"),
      ENV.fetch("PRIVATE_BASE_STAFF_URL", "www.org.localhost"),
      ENV.fetch("PUBLIC_CORE_CORPORATE_URL", ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "core.com.localhost")),
      ENV.fetch("PUBLIC_CORE_SERVICE_URL", ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost")),
      ENV.fetch("PUBLIC_CORE_STAFF_URL", ENV.fetch("PUBLIC_CORE_STAFF_URL", "core.org.localhost")),
      ENV.fetch("PRIVATE_AUTH_CORPORATE_URL", "sign.com.localhost"),
      ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost"),
      ENV.fetch("PRIVATE_AUTH_STAFF_URL", "sign.org.localhost"),
    ].each do |host|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{host}/edge/v0/health", method: :get)
      end
    end
  end

  test "legacy sign web health routes are not routed" do
    [
      ENV.fetch("PRIVATE_AUTH_CORPORATE_URL", "sign.com.localhost"),
      ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost"),
      ENV.fetch("PRIVATE_AUTH_STAFF_URL", "sign.org.localhost"),
    ].each do |host|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{host}/web/v0/health", method: :get)
      end
    end
  end

  # The probe contract was unified on /health/liveness and /health/readiness.
  # The former /health/live and /health/ready paths were removed outright (no
  # compatibility shim); guard against their reintroduction on any surface.
  test "removed legacy probe paths are not routed" do
    [
      ENV.fetch("PRIVATE_BASE_CORPORATE_URL", "www.com.localhost"),
      ENV.fetch("PRIVATE_BASE_SERVICE_URL", "www.app.localhost"),
      ENV.fetch("PRIVATE_BASE_STAFF_URL", "www.org.localhost"),
      ENV.fetch("PUBLIC_CORE_CORPORATE_URL", ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "core.com.localhost")),
      ENV.fetch("PUBLIC_CORE_SERVICE_URL", ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost")),
      ENV.fetch("PUBLIC_CORE_STAFF_URL", ENV.fetch("PUBLIC_CORE_STAFF_URL", "core.org.localhost")),
      ENV.fetch("PRIVATE_AUTH_CORPORATE_URL", "sign.com.localhost"),
      ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost"),
      ENV.fetch("PRIVATE_AUTH_STAFF_URL", "sign.org.localhost"),
    ].each do |host|
      %w(/health/live /health/ready).each do |path|
        assert_raises(ActionController::RoutingError, "#{host}#{path} should not be routed") do
          Rails.application.routes.recognize_path("http://#{host}#{path}", method: :get)
        end
      end
    end
  end

  # The machine endpoints carry the literal ".json" as a path segment (`format: false`). The
  # bare paths and any other API version must not resolve.
  test "machine health and revision endpoints exist only at the exact /api/v0/*.json paths" do
    host = ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    %w(
      /api/v0/health /api/v0/revision /api/v1/health.json /api/v1/revision.json
      /api/v0/liveness.json /health.json/liveness
    ).each do |path|
      assert_raises(ActionController::RoutingError, "#{host}#{path} should not be routed") do
        Rails.application.routes.recognize_path("http://#{host}#{path}", method: :get)
      end
    end
  end
end
