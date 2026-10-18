# typed: false
# frozen_string_literal: true

require "test_helper"

class Core::Com::Api::V0::SessionsControllerTest < ActionDispatch::IntegrationTest
  HOST = ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "core.com.localhost")

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

  test "an anonymous com session summary has no actor" do
    get "/api/v0/session", headers: json_headers

    assert_response :success
    body = response.parsed_body

    assert_not body.fetch("authenticated")
    assert_predicate body.fetch("csrf_token"), :present?
    assert_not body.key?("actor")
  end

  test "an authenticated com session identifies the visitor by public id" do
    visitor = visitors(:reserved_visitor)
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = oidc_access_token_for(visitor)

    get "/api/v0/session", headers: json_headers

    assert_response :success
    body = response.parsed_body

    assert body.fetch("authenticated")
    assert_equal visitor.public_id, body.fetch("actor").fetch("id")
    assert_not_equal visitor.id.to_s, body.fetch("actor").fetch("id")
  end

  test "an OIDC RP credential cookie authenticates through its bound root VisitorToken" do
    visitor = visitors(:reserved_visitor)
    client = OidcClientRegistry.find!("core-com-jp")
    root_token = VisitorToken.create!(
      visitor: visitor,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
    )
    access_token = AuthenticationTokenService.encode(
      visitor,
      host: HOST,
      resource_type: "visitor",
      session_public_id: "rp-session-public-id",
      base_session_public_id: root_token.public_id,
      oidc_sid: "rp-session-public-id",
      oidc_jti: "rp-jti",
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_resource_type("visitor"),
      audiences: [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      subject: OidcSubject.for(visitor, resource_type: "visitor"),
      client_id: client.client_id,
      authentication_context: root_token.strict_authentication_context_value.to_s,
    )

    assert_predicate OidcRpBrowserCredentialContract.decode_access_token(
      token: access_token,
      host: HOST,
      resource_type: "visitor",
      client_id: client.client_id,
    ), :present?

    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token

    get "/api/v0/session", headers: json_headers

    assert_response :success
    body = response.parsed_body

    assert body.fetch("authenticated")
    assert_equal visitor.public_id, body.fetch("actor").fetch("id")
  end

  test "a credential with a sibling RP client claim is rejected" do
    visitor = visitors(:reserved_visitor)
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = oidc_access_token_for(
      visitor,
      client_id: "warp-com-jp",
    )

    get("/api/v0/session", headers: json_headers)

    assert_response :unauthorized
    assert_equal "urn:umaxica:problem:authentication-required", response.parsed_body.fetch("type")
  end

  test "a blank visitor public id is rejected without falling back to the database key" do
    visitor = visitors(:reserved_visitor)
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = oidc_access_token_for(visitor)
    visitor.update_columns(public_id: "")

    get("/api/v0/session", headers: json_headers)

    assert_response :unauthorized
    assert_equal "urn:umaxica:problem:authentication-required", response.parsed_body.fetch("type")
  ensure
    visitors(:reserved_visitor).update_columns(public_id: "reserved_visitor")
  end

  private

  def json_headers
    {
      "Accept" => "application/json",
      "Content-Type" => "application/json",
      "Client-Agent" =>
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    }
  end

  def oidc_access_token_for(visitor, client_id: "core-com-jp")
    client = OidcClientRegistry.find!("core-com-jp")
    root_token = VisitorToken.create!(
      visitor: visitor,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
    )
    rp_grant = OpComGrant.create!(
      visitor_token: root_token,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    AuthenticationTokenService.encode(
      visitor,
      host: OidcIssuer.host_for_resource_type("visitor"),
      resource_type: "visitor",
      session_public_id: rp_grant.public_id,
      base_session_public_id: root_token.public_id,
      oidc_sid: rp_grant.public_id,
      oidc_jti: rp_grant.oidc_jti,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_resource_type("visitor"),
      audiences: [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      subject: OidcSubject.for(visitor, resource_type: "visitor"),
      client_id: client_id,
      authentication_context: root_token.strict_authentication_context_value.to_s,
    )
  end
end
