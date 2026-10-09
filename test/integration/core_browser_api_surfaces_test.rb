# frozen_string_literal: true

require "test_helper"

# The core browser session probe exists on the corporate and staff surfaces as
# well as the app surface (which CoreBrowserApiBoundaryTest covers). Each
# surface owns its own controller, so the anonymous contract is pinned per
# surface: no actor is disclosed, a CSRF token is issued, and the response is
# uncacheable.
class CoreBrowserApiSurfacesTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @previous_flag = ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"]
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = "1"
  end

  teardown do
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = @previous_flag
    Actor.clear if defined?(Actor)
  end

  test "com session probe answers unauthenticated without naming an actor" do
    host! ENV.fetch("PUBLIC_CORE_CORPORATE_URL")
    https!

    get "/api/v0/session", headers: json_probe_headers

    assert_response :success
    body = response.parsed_body

    assert_not body.fetch("authenticated")
    assert_predicate body.fetch("csrf_token"), :present?
    assert_nil body["actor"]
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "org session probe answers unauthenticated without naming an actor" do
    host! ENV.fetch("PUBLIC_CORE_STAFF_URL")
    https!

    get "/api/v0/session", headers: json_probe_headers

    assert_response :success
    body = response.parsed_body

    assert_not body.fetch("authenticated")
    assert_predicate body.fetch("csrf_token"), :present?
    assert_nil body["actor"]
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "com session probe is unavailable while the boundary feature flag is off" do
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = nil
    host! ENV.fetch("PUBLIC_CORE_CORPORATE_URL")
    https!

    get "/api/v0/session", headers: json_probe_headers

    assert_response :service_unavailable
    assert_equal "application/problem+json", response.media_type
  end

  test "org session probe is unavailable while the boundary feature flag is off" do
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = nil
    host! ENV.fetch("PUBLIC_CORE_STAFF_URL")
    https!

    get "/api/v0/session", headers: json_probe_headers

    assert_response :service_unavailable
    assert_equal "application/problem+json", response.media_type
  end

  # The refresh endpoint is the other half of the boundary and has its own refusals:
  # a missing CSRF token, no refresh cookie at all, and a cookie the issuer cannot
  # redeem. All three answer as problem+json rather than leaking whether the token
  # ever existed.
  test "com token refresh without the issued csrf token is refused" do
    host! ENV.fetch("PUBLIC_CORE_CORPORATE_URL")
    https!

    post "/api/v0/token/refresh", headers: json_probe_headers

    assert_response :forbidden
    assert_equal "application/problem+json", response.media_type
    assert_equal "urn:umaxica:problem:csrf-verification-failed", response.parsed_body.fetch("type")
  end

  test "com token refresh without a refresh cookie is refused as unauthenticated" do
    host! ENV.fetch("PUBLIC_CORE_CORPORATE_URL")
    https!
    get "/api/v0/session", headers: json_probe_headers
    csrf_token = response.parsed_body.fetch("csrf_token")

    post "/api/v0/token/refresh", headers: json_probe_headers.merge(
      "X-CSRF-Token" => csrf_token,
      "Origin" => "https://#{request.host}",
    )

    assert_response :unauthorized
    assert_equal "application/problem+json", response.media_type
  end

  test "com token refresh with an unredeemable refresh cookie reports an expired token" do
    host! ENV.fetch("PUBLIC_CORE_CORPORATE_URL")
    https!
    get "/api/v0/session", headers: json_probe_headers
    csrf_token = response.parsed_body.fetch("csrf_token")
    cookies[CoreBrowserCredentialContract::REFRESH_COOKIE] =
      "rt_#{SecureRandom.alphanumeric(21)}.#{SecureRandom.hex(16)}"

    post "/api/v0/token/refresh", headers: json_probe_headers.merge(
      "X-CSRF-Token" => csrf_token,
      "Origin" => "https://#{request.host}",
    )

    assert_response :unauthorized
    assert_equal "application/problem+json", response.media_type
  end

  test "org token refresh without a refresh cookie is refused as unauthenticated" do
    host! ENV.fetch("PUBLIC_CORE_STAFF_URL")
    https!
    get "/api/v0/session", headers: json_probe_headers
    csrf_token = response.parsed_body.fetch("csrf_token")

    post "/api/v0/token/refresh", headers: json_probe_headers.merge(
      "X-CSRF-Token" => csrf_token,
      "Origin" => "https://#{request.host}",
    )

    assert_response :unauthorized
    assert_equal "application/problem+json", response.media_type
  end

  private

  def json_probe_headers
    {
      "Accept" => "application/json",
      "Content-Type" => "application/json",
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    }
  end
end
