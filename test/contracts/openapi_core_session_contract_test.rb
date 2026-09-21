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
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = oidc_access_token_for(clients(:one))

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
        headers: json_headers.merge("Authorization" => "Bearer #{oidc_access_token_for(clients(:one))}")

    assert_response :unauthorized
    assert_equal "application/problem+json", response.media_type
  end

  test "a successful credential rotation conforms" do
    csrf = fetch_csrf_token
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = oidc_refresh_token_for_client

    post "/api/v0/token/refresh", headers: json_headers.merge("X-CSRF-Token" => csrf)

    # The rotated credentials travel as Set-Cookie, so there is no representation to return.
    assert_response :no_content
    assert_empty response.body
    assert_openapi_conform 204
  end

  test "a rotation without a csrf token conforms" do
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = oidc_refresh_token_for_client

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

  def oidc_access_token_for(client, audiences: nil)
    oidc_client = OidcClientRegistry.find!("core-app")
    AuthenticationTokenService.encode(
      client,
      host: OidcIssuer.host_for_resource_type("client"),
      resource_type: "client",
      session_public_id: "rp-session-public-id",
      oidc_sid: "rp-session-public-id",
      oidc_jti: SecureRandom.uuid,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_resource_type("client"),
      audiences: audiences || [oidc_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(oidc_client),
      subject: OidcSubject.for(client, resource_type: "client"),
      client_id: oidc_client.client_id,
    )
  end

  def oidc_refresh_token_for_client
    session = ClientRpSession.create!(
      client_token: client_tokens(:one),
      oidc_client_id: "core-app",
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    session.issue_refresh_token!
  end
end
