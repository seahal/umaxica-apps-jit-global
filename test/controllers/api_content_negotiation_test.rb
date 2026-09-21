# typed: false
# frozen_string_literal: true

require "test_helper"

# Covers the media type contract on every `/api/v0` boundary: the cookie-authenticated Core BFF, the
# bearer-authenticated Palm API, and the public content endpoints. Each includes the same concern, so
# a regression in one would otherwise be caught in only one place.
class ApiContentNegotiationTest < ActionDispatch::IntegrationTest
  CORE_HOST = ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost")
  DOCS_HOST = ENV.fetch("PRIVATE_DOCS_SERVICE_URL", "docs.app.localhost")
  PALM_HOST = ENV.fetch("PUBLIC_PALM_SERVICE_URL")

  setup do
    @previous_flag = ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"]
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = "1"
    https!
  end

  teardown do
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = @previous_flag
    Actor.clear if defined?(Actor)
  end

  test "a caller that accepts only html is refused on every api boundary" do
    {
      CORE_HOST => "/api/v0/session",
      DOCS_HOST => "/api/v0/entries",
      PALM_HOST => "/api/v0/profile",
    }.each do |host, path|
      host! host
      get path, headers: { "Accept" => "text/html" }

      assert_response :not_acceptable, "#{path} on #{host} served an html-only caller"
      assert_equal "application/problem+json", response.media_type
      assert_equal "urn:umaxica:problem:not-acceptable", response.parsed_body.fetch("type")
    end
  end

  # RFC 9110 15.5.7 allows a 406 to carry a representation the client did not ask for, and an
  # explanation the caller can read beats an empty body.
  test "the refusal itself is still a problem document" do
    host! DOCS_HOST
    get "/api/v0/entries", headers: { "Accept" => "text/csv" }

    assert_response :not_acceptable

    body = response.parsed_body

    assert_equal 406, body.fetch("status")
    assert_predicate body.fetch("request_id"), :present?
  end

  test "negotiation runs before authentication so a refusal does not depend on credentials" do
    host! PALM_HOST
    get "/api/v0/profile", headers: { "Accept" => "text/html" }

    # Without a bearer token this endpoint answers 401. The media type is settled first.
    assert_response :not_acceptable
  end

  test "an absent Accept header accepts anything" do
    host! DOCS_HOST
    get "/api/v0/entries"

    assert_response :success
    assert_equal "application/json", response.media_type
  end

  test "wildcard and subtype ranges are accepted" do
    ["*/*", "application/*", "text/html,application/xhtml+xml,*/*;q=0.8"].each do |accept|
      host! DOCS_HOST
      get "/api/v0/entries", headers: { "Accept" => accept }

      assert_response :success, "Accept: #{accept} was refused"
    end
  end

  test "a caller that accepts only the problem media type is served" do
    host! DOCS_HOST
    get "/api/v0/entries", headers: { "Accept" => "application/problem+json" }

    assert_response :success
  end

  test "a request body of the wrong media type is refused" do
    host! CORE_HOST
    post "/api/v0/token/refresh",
         params: "not json",
         headers: { "Accept" => "application/json", "Content-Type" => "text/plain" }

    assert_response :unsupported_media_type
    assert_equal "application/problem+json", response.media_type
    assert_equal "urn:umaxica:problem:unsupported-media-type", response.parsed_body.fetch("type")
  end

  test "the body media type is settled before csrf verification" do
    host! CORE_HOST
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = oidc_refresh_token_for_client

    post "/api/v0/token/refresh",
         params: "not json",
         headers: { "Accept" => "application/json", "Content-Type" => "text/plain" }

    # Without the media type check this would be the 403 CSRF failure. A body that cannot be parsed
    # is rejected before anything tries to read it.
    assert_response :unsupported_media_type
  end

  test "a bodyless post is not refused for declaring no media type" do
    host! CORE_HOST
    get "/api/v0/session", headers: { "Accept" => "application/json" }
    csrf_token = response.parsed_body.fetch("csrf_token")
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = oidc_refresh_token_for_client

    post "/api/v0/token/refresh", headers: { "Accept" => "application/json", "X-CSRF-Token" => csrf_token }

    # The refresh endpoint carries its credential in a cookie and its CSRF token in a header, so it
    # sends no body at all. Refusing it for declaring nothing would break the endpoint.
    assert_response :success
  end

  test "a json request body is accepted" do
    host! CORE_HOST
    get "/api/v0/session", headers: { "Accept" => "application/json" }
    csrf_token = response.parsed_body.fetch("csrf_token")
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = oidc_refresh_token_for_client

    post "/api/v0/token/refresh",
         params: {}.to_json,
         headers: {
           "Accept" => "application/json",
           "Content-Type" => "application/json",
           "X-CSRF-Token" => csrf_token,
         }

    assert_response :success
  end

  private

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
