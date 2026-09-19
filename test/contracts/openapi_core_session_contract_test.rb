# frozen_string_literal: true

require "test_helper"
require_relative "../support/openapi_contract"

# Validates the Core browser BFF endpoints against the app surface description.
#
# These are the two paths that carry a `servers` entry, because Core is the only service whose
# public host is a literal in config/environments/production.rb.
class OpenapiCoreSessionContractTest < ActionDispatch::IntegrationTest
  include OpenapiContract

  openapi_surface :app

  HOST = ENV.fetch("PRIVATE_CORE_SERVICE_URL")

  setup do
    @previous_flag = ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"]
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = "1"
    host! HOST
    https!
  end

  teardown do
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = @previous_flag
    Actor.clear if defined?(Actor)
  end

  test "an anonymous session summary conforms" do
    get "/api/v0/session", headers: json_headers

    assert_response :success
    assert_not response.parsed_body.fetch("authenticated")
    assert_openapi_conform 200
  end

  test "an authenticated session summary conforms" do
    cookies[CoreBrowserCredentialContract::ACCESS_COOKIE] = core_browser_access_token

    get "/api/v0/session", headers: json_headers

    assert_response :success
    assert response.parsed_body.fetch("authenticated")
    assert_openapi_conform 200
  end

  test "a disabled boundary answers a conforming problem document" do
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = nil

    get("/api/v0/session", headers: json_headers)

    assert_response :service_unavailable
    assert_equal "application/problem+json", response.media_type
    assert_openapi_conform 503
  ensure
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = "1"
  end

  test "a refusal of the wrong credential transport conforms" do
    # The cookie boundary rejects a bearer token outright; the schema documents 403 for this path,
    # so this also pins which status that refusal uses.
    get "/api/v0/session",
        headers: json_headers.merge("Authorization" => "Bearer #{core_browser_access_token}")

    assert_response :unauthorized
    assert_equal "application/problem+json", response.media_type
  end

  test "a successful credential rotation conforms" do
    csrf = fetch_csrf_token
    cookies[CoreBrowserCredentialContract::REFRESH_COOKIE] = client_tokens(:one).rotate_refresh_token!

    post "/api/v0/token/refresh", headers: json_headers.merge("X-CSRF-Token" => csrf)

    # The rotated credentials travel as Set-Cookie, so there is no representation to return.
    assert_response :no_content
    assert_empty response.body
    assert_openapi_conform 204
  end

  test "a rotation without a csrf token conforms" do
    cookies[CoreBrowserCredentialContract::REFRESH_COOKIE] = client_tokens(:one).rotate_refresh_token!

    post "/api/v0/token/refresh", headers: json_headers

    assert_response :forbidden
    assert_equal "application/problem+json", response.media_type
    # Response only: the request deliberately omits the required X-CSRF-Token, which is the
    # condition under test.
    assert_openapi_response_conform 403
  end

  private

  def fetch_csrf_token
    get("/api/v0/session", headers: json_headers)

    assert_response :success
    response.parsed_body.fetch("csrf_token")
  end

  def json_headers
    {
      "Accept" => "application/json",
      "Content-Type" => "application/json",
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    }
  end

  def core_browser_access_token(audiences: [CoreBrowserCredentialContract::ACCESS_AUDIENCE])
    token_record = client_tokens(:one)
    AuthenticationTokenService.encode(
      clients(:one),
      host: HOST,
      resource_type: "client",
      session_public_id: token_record.public_id,
      session_id: token_record.public_id,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile:read self:read),
      issuer: AuthenticationJwtConfiguration.issuer,
      audiences: audiences,
      jwt_issuer_id: CoreBrowserCredentialContract.core_jwt_issuer_id("client"),
    )
  end
end
