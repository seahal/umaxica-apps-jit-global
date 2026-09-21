# typed: false
# frozen_string_literal: true

require "test_helper"

class CoreRpCookieSurfaceContractTest < ActionDispatch::IntegrationTest
  SURFACES = [
    {
      host: -> { ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost") },
      client_id: "core-app",
      resource_type: "client",
      resource_fixture: [:clients, :one],
    },
    {
      host: -> { ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "core.com.localhost") },
      client_id: "core-com",
      resource_type: "visitor",
      resource_fixture: [:visitors, :reserved_visitor],
    },
    {
      host: -> { ENV.fetch("PUBLIC_CORE_STAFF_URL", "core.org.localhost") },
      client_id: "core-org",
      resource_type: "operator",
      resource_fixture: [:operators, :one],
    },
  ].freeze

  setup do
    @previous_flag = ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"]
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = "1"
  end

  teardown do
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = @previous_flag
    Actor.clear if defined?(Actor)
  end

  test "app com and org accept only their exact RP access credential" do
    SURFACES.each do |surface|
      fixture_method, fixture_name = surface.fetch(:resource_fixture)
      resource = public_send(fixture_method, fixture_name)
      browser = open_session
      browser.host!(surface.fetch(:host).call)
      browser.https!
      browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token_for(
        resource,
        resource_type: surface.fetch(:resource_type),
        client_id: surface.fetch(:client_id),
      )

      browser.get("/api/v0/session", headers: json_headers)

      assert_equal 200, browser.response.status, surface.fetch(:client_id)
      body = browser.response.parsed_body

      assert body.fetch("authenticated")
      assert_equal resource.public_id, body.dig("actor", "id"), surface.fetch(:client_id)
      assert_not_equal resource.id.to_s, body.dig("actor", "id"), surface.fetch(:client_id)
    end
  end

  private

  def access_token_for(resource, resource_type:, client_id:)
    client = OidcClientRegistry.find!(client_id)
    AuthenticationTokenService.encode(
      resource,
      host: OidcIssuer.host_for_resource_type(resource_type),
      resource_type: resource_type,
      session_public_id: "rp-session-#{client_id}",
      oidc_sid: "rp-session-#{client_id}",
      oidc_jti: SecureRandom.uuid,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_resource_type(resource_type),
      audiences: [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      subject: OidcSubject.for(resource, resource_type: resource_type),
      client_id: client.client_id,
    )
  end

  def json_headers
    {
      "Accept" => "application/json",
      "Content-Type" => "application/json",
      "Client-Agent" => "Mozilla/5.0 (Core RP contract test)",
    }
  end
end
