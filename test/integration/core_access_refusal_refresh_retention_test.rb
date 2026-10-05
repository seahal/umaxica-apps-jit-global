# frozen_string_literal: true

require "test_helper"

class CoreAccessRefusalRefreshRetentionTest < ActionDispatch::IntegrationTest
  test "all surfaces refuse bad access without deleting or rotating an independently valid refresh credential" do
    previous_flag = ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"]
    previous_forgery = ActionController::Base.allow_forgery_protection
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = "1"
    ActionController::Base.allow_forgery_protection = true
    [
      [ENV.fetch("PUBLIC_CORE_SERVICE_URL"), "client", "core-app", clients(:one)],
      [ENV.fetch("PUBLIC_CORE_CORPORATE_URL"), "visitor", "core-com", visitors(:reserved_visitor)],
      [ENV.fetch("PUBLIC_CORE_STAFF_URL"), "operator", "core-org", operators(:one)],
    ].each do |hostname, resource_type, client_id, resource|
      reset!
      host!(hostname)
      https!
      deadline = 10.minutes.from_now.change(usec: 0)
      attributes = {
        oidc_scope: "openid profile",
        oidc_jti: SecureRandom.uuid,
        oidc_nonce: SecureRandom.hex(16),
        oidc_auth_time: 1.minute.ago,
        refresh_token_expires_at: deadline,
      }
      rp =
        case resource_type
        when "client"
          token = client_tokens(:one)
          token.update!(discard_at: deadline)
          ClientRpSession.create!(client_token: token, oidc_client_id: client_id, **attributes)
        when "visitor"
          token = VisitorToken.create!(visitor: resource, discard_at: deadline)
          VisitorRpSession.create!(visitor_token: token, oidc_client_id: client_id, **attributes)
        when "operator"
          token = operator_tokens(:one)
          token.update!(discard_at: deadline)
          OperatorRpSession.create!(operator_token: token, oidc_client_id: client_id, **attributes)
        else
          raise ArgumentError, "unsupported Core test surface"
        end
      refresh = rp.issue_refresh_token!(expires_at: deadline)
      snapshot = rp.reload.attributes
      client = OidcClientRegistry.find!(client_id)
      expired = AuthenticationTokenService.encode(
        resource, host: OidcIssuer.host_for_resource_type(resource_type), resource_type: resource_type,
                  session_public_id: rp.public_id, oidc_sid: rp.public_id, oidc_jti: rp.oidc_jti,
                  expires_at: Time.current - AuthenticationJwtConfiguration.leeway_seconds.seconds - 1.second,
                  scopes: %w(openid profile),
                  issuer: OidcIssuer.for_resource_type(resource_type), audiences: [client.aud],
                  jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
                  subject: OidcSubject.for(resource, resource_type: resource_type), client_id: client_id,
      )

      assert_predicate expired, :present?
      [expired, "malformed-access-fixture"].each do |access|
        # Rack::Test otherwise retains deletion expiry metadata when replacing
        # the previous case's access cookie. Each case is a fresh presentation.
        cookies.delete(OidcRpBrowserCredentialContract::ACCESS_COOKIE)
        cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access
        cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = refresh
        get("/api/v0/session", headers: { "Accept" => "application/json" })

        assert_response :unauthorized
        assert_equal "application/problem+json", response.media_type
        assert_equal "urn:umaxica:problem:authentication-required", response.parsed_body.fetch("type")
        assert_equal "no-store", response.headers["Cache-Control"]
        refresh_preserved = cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] == refresh

        assert refresh_preserved, "access refusal must preserve the independent refresh cookie"
        assert_predicate cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE], :blank?
        unchanged = snapshot == rp.reload.attributes

        assert unchanged, "session read must not rotate or revoke the RP row"
        assert_not response.parsed_body.key?("actor")
        assert_not_includes response.body, refresh
        assert_not_includes response.body, access
      end

      get("/api/v0/session", headers: { "Accept" => "application/json" })

      assert_response :success
      assert_not response.parsed_body.fetch("authenticated")
      csrf = response.parsed_body.fetch("csrf_token")
      post(
        "/api/v0/token/refresh", headers: {
          "Accept" => "application/json",
          "X-CSRF-Token" => csrf,
          "Origin" => "https://#{hostname}",
          "Sec-Fetch-Site" => "same-origin",
        },
      )

      assert_response :no_content
      assert_empty response.body
      rotated = rp.reload.refresh_token_digest != snapshot.fetch("refresh_token_digest")

      assert rotated, "existing explicit POST must rotate the real RP credential"
      assert_operator rp.refresh_token_expires_at, :<=, deadline, "rotation must not extend the root absolute expiry"
      assert_equal snapshot.fetch("oidc_auth_time"), rp.oidc_auth_time
      assert_equal snapshot.fetch("public_id"), rp.public_id
      get("/api/v0/session", headers: { "Accept" => "application/json" })

      assert_response :success
      assert response.parsed_body.fetch("authenticated"), "the next request must accept Rails-issued access"
      assert_equal resource.public_id, response.parsed_body.fetch("actor").fetch("id")
    end
  ensure
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = previous_flag
    ActionController::Base.allow_forgery_protection = previous_forgery
    Actor.clear
  end
end
