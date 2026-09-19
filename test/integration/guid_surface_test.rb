# typed: false
# frozen_string_literal: true

require "test_helper"

class GuidSurfaceTest < ActionDispatch::IntegrationTest
  GUID_HOST = ENV.fetch("PRIVATE_GUID_SERVICE_URL", "guid.net.localhost")

  test "root identifies the GUID service without exposing application state" do
    get "/", headers: { "Host" => GUID_HOST }

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_select "title", /UMAXICA GUID/
    assert_select "h1", "UMAXICA GUID"
    assert_select "p", /Identifier/
    assert_nil response.headers["Set-Cookie"]
    assert_includes response.headers.fetch("Content-Security-Policy"), "default-src 'self'"
    assert_equal "SAMEORIGIN", response.headers["X-Frame-Options"]
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
  end

  test "text health endpoint uses the shared operational contract" do
    get "/health", headers: { "Host" => GUID_HOST }

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_includes response.body, "namespace: guid/net\n"
    assert_not_includes response.body, "exception"
  end

  test "machine health endpoint uses the shared JSON contract" do
    get "/api/v0/health.json", headers: { "Host" => GUID_HOST, "Accept" => "application/json" }

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "guid/net", response.parsed_body.fetch("namespace")
  end

  test "well-formed but unknown GUID returns not found without a redirect" do
    get "/api/v0/resources/example-guid", headers: { "Host" => GUID_HOST, "Accept" => "application/json" }

    assert_response :not_found
    assert_equal "application/problem+json", response.media_type
    assert_equal "urn:umaxica:problem:not-found", response.parsed_body.fetch("type")
    assert_nil response.headers["Location"]
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "malformed GUID is rejected at the request boundary" do
    get "/api/v0/resources/guid%20value", headers: { "Host" => GUID_HOST, "Accept" => "application/json" }

    assert_response :bad_request
    assert_equal "application/problem+json", response.media_type
    assert_equal "urn:umaxica:problem:bad-request", response.parsed_body.fetch("type")
  end

  test "GUID longer than the contract limit is rejected" do
    get "/api/v0/resources/#{"a" * 256}", headers: { "Host" => GUID_HOST, "Accept" => "application/json" }

    assert_response :bad_request
    assert_equal "application/problem+json", response.media_type
    assert_equal "urn:umaxica:problem:bad-request", response.parsed_body.fetch("type")
  end

  test "GUID endpoint is unavailable through an unrelated host" do
    get "/api/v0/resources/example-guid",
        headers: { "Host" => ENV.fetch("PRIVATE_INFO_SERVICE_URL", "info.app.localhost"),
                   "Accept" => "application/json", }

    assert_response :not_found
    assert_not_equal "guid/net/api/v0/resources", request.path_parameters[:controller]
  end

  test "GUID endpoint refuses an unacceptable representation" do
    get "/api/v0/resources/example-guid", headers: { "Host" => GUID_HOST, "Accept" => "text/html" }

    assert_response :not_acceptable
    assert_equal "application/problem+json", response.media_type
    assert_equal "urn:umaxica:problem:not-acceptable", response.parsed_body.fetch("type")
  end
end
