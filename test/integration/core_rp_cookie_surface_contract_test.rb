# typed: false
# frozen_string_literal: true

require "test_helper"

class CoreRpCookieSurfaceContractTest < ActionDispatch::IntegrationTest
  SURFACES = [
    {
      host: -> { ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost") },
      client_id: "core-app-jp",
      resource_type: "client",
      resource_fixture: [:clients, :one],
    },
    {
      host: -> { ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "core.com.localhost") },
      client_id: "core-com-jp",
      resource_type: "visitor",
      resource_fixture: [:visitors, :reserved_visitor],
    },
    {
      host: -> { ENV.fetch("PUBLIC_CORE_STAFF_URL", "core.org.localhost") },
      client_id: "core-org-jp",
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

  def root_and_grant_for(resource, resource_type)
    case resource_type
    when "client"
      [ClientToken.find_by(user_id: resource.id) || ClientToken.create!(
        user: resource, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
        user_token_status_id: ClientTokenStatus::ACTIVE,
      ), OpAppGrant, :client_token,]
    when "visitor"
      [VisitorToken.find_by(visitor_id: resource.id) || VisitorToken.create!(
        visitor: resource, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
        visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      ), OpComGrant, :visitor_token,]
    when "operator"
      [OperatorToken.find_by(staff_id: resource.id) || OperatorToken.create!(
        staff: resource, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
        staff_token_status_id: OperatorTokenStatus::ACTIVE,
      ), OpOrgGrant, :operator_token,]
    else
      raise ArgumentError, "unsupported resource type"
    end
  end

  def access_token_for(resource, resource_type:, client_id:)
    client = OidcClientRegistry.find!(client_id)
    root_token, grant_class, grant_foreign_key = root_and_grant_for(resource, resource_type)
    rp_grant = grant_class.create!(
      grant_foreign_key => root_token,
      :oidc_client_id => client.client_id,
      :oidc_scope => "openid profile",
      :oidc_jti => SecureRandom.uuid,
      :oidc_nonce => SecureRandom.hex(16),
      :oidc_auth_time => 1.minute.ago,
      :refresh_token_expires_at => 10.minutes.from_now,
    )
    AuthenticationTokenService.encode(
      resource,
      host: OidcIssuer.host_for_resource_type(resource_type),
      resource_type: resource_type,
      session_public_id: rp_grant.public_id,
      base_session_public_id: root_token.public_id,
      oidc_sid: rp_grant.public_id,
      oidc_jti: rp_grant.oidc_jti,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_resource_type(resource_type),
      audiences: [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      subject: OidcSubject.for(resource, resource_type: resource_type),
      client_id: client.client_id,
      authentication_context: root_token.strict_authentication_context_value.to_s,
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
