# frozen_string_literal: true

require "test_helper"
require_relative "../support/openapi_contract"

# Validates the machine-readable health and revision endpoints against each surface description.
#
# The text operational endpoints -- `GET /health`, `GET /health/{startup,liveness,readiness}`,
# and `GET /revision` -- are absent from the descriptions on purpose: they render `text/plain`
# and do not negotiate, so they are not part of a JSON contract. That separation is asserted
# here too, because the previous description claimed the probes returned `application/json`.
class OpenapiHealthContractTest < ActionDispatch::IntegrationTest
  include OpenapiContract

  SURFACE_HOSTS = {
    "app" => ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"),
    "com" => ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"),
    "org" => ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"),
  }.freeze

  SURFACE_HOSTS.each do |surface, host|
    test "GET /api/v0/health.json conforms to the #{surface} description" do
      self.openapi_surface = surface

      get "/api/v0/health.json", headers: host_headers(host).merge("Accept" => "application/json")

      assert_response :success
      assert_equal "application/json", response.media_type
      assert_equal "no-store", response.headers["Cache-Control"]
      assert_openapi_conform 200
    end

    test "GET /api/v0/revision.json conforms to the #{surface} description" do
      self.openapi_surface = surface

      get "/api/v0/revision.json", headers: host_headers(host).merge("Accept" => "application/json")

      assert_response :success
      assert_equal "application/json", response.media_type
      assert_equal "no-store", response.headers["Cache-Control"]
      assert_includes response.parsed_body.keys, "revision"
      assert_openapi_conform 200
    end

    test "GET /api/v0/health.json refuses a non-JSON Accept with an undescribed 406 on #{surface}" do
      self.openapi_surface = surface

      get "/api/v0/health.json", headers: host_headers(host).merge("Accept" => "text/html")

      assert_response :not_acceptable
      assert_empty response.body
      assert_equal "no-store", response.headers["Cache-Control"]
    end
  end

  test "the text probes are not JSON endpoints" do
    host = SURFACE_HOSTS.fetch("app")

    %w(health health/startup health/liveness health/readiness).each do |path|
      get "/#{path}", headers: host_headers(host).merge("Accept" => "application/json")

      assert_response :success
      assert_equal "text/plain", response.media_type, "/#{path} media type"
      assert_not_equal "application/json", response.media_type
    end
  end
end
