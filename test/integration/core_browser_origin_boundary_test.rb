# frozen_string_literal: true

require "test_helper"

class CoreBrowserOriginBoundaryTest < ActionDispatch::IntegrationTest
  setup do
    @previous_flag = ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"]
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = "1"
  end

  teardown do
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = @previous_flag
  end

  test "app com and org reject missing Origin with sibling-site metadata despite valid csrf" do
    %w(PUBLIC_CORE_SERVICE_URL PUBLIC_CORE_CORPORATE_URL PUBLIC_CORE_STAFF_URL).each do |setting|
      host! ENV.fetch(setting)
      https!
      get "/api/v0/session", headers: { "Accept" => "application/json" }

      assert_response :success
      csrf = response.parsed_body.fetch("csrf_token")

      post "/api/v0/token/refresh", headers: {
        "Accept" => "application/json",
        "X-CSRF-Token" => csrf,
        "Sec-Fetch-Site" => "same-site",
      }

      assert_response :forbidden
      assert_equal "urn:umaxica:problem:csrf-verification-failed", response.parsed_body.fetch("type")
    end
  end

  test "exact same Origin keeps the existing explicit POST refresh refusal contract" do
    %w(PUBLIC_CORE_SERVICE_URL PUBLIC_CORE_CORPORATE_URL PUBLIC_CORE_STAFF_URL).each do |setting|
      host! ENV.fetch(setting)
      https!
      get "/api/v0/session", headers: { "Accept" => "application/json" }

      assert_response :success
      csrf = response.parsed_body.fetch("csrf_token")

      post "/api/v0/token/refresh", headers: {
        "Accept" => "application/json",
        "X-CSRF-Token" => csrf,
        "Origin" => "https://#{ENV.fetch(setting)}",
        "Sec-Fetch-Site" => "same-origin",
      }

      assert_response :unauthorized
      assert_equal "application/problem+json", response.media_type
    end
  end

  test "every surface rejects foreign malformed null and mismatched Origins before refresh" do
    %w(PUBLIC_CORE_SERVICE_URL PUBLIC_CORE_CORPORATE_URL PUBLIC_CORE_STAFF_URL).each do |setting|
      hostname = ENV.fetch(setting)
      host! hostname
      https!
      get "/api/v0/session", headers: { "Accept" => "application/json" }

      assert_response :success
      csrf = response.parsed_body.fetch("csrf_token")
      ["https://sibling.#{hostname}", "https://untrusted.example", "http://#{hostname}",
       "https://#{hostname}:444", "null", "invalid-origin",].each do |origin|
        post "/api/v0/token/refresh", headers: {
          "Accept" => "application/json",
          "X-CSRF-Token" => csrf,
          "Origin" => origin,
          "Sec-Fetch-Site" => "same-origin",
        }

        assert_response :forbidden
        assert_equal "urn:umaxica:problem:csrf-verification-failed", response.parsed_body.fetch("type")
      end
    end
  end

  test "same Origin contradicting cross-site metadata is refused on every surface" do
    %w(PUBLIC_CORE_SERVICE_URL PUBLIC_CORE_CORPORATE_URL PUBLIC_CORE_STAFF_URL).each do |setting|
      hostname = ENV.fetch(setting)
      host! hostname
      https!
      get "/api/v0/session", headers: { "Accept" => "application/json" }

      assert_response :success
      csrf = response.parsed_body.fetch("csrf_token")

      post "/api/v0/token/refresh", headers: {
        "Accept" => "application/json",
        "X-CSRF-Token" => csrf,
        "Origin" => "https://#{hostname}",
        "Sec-Fetch-Site" => "cross-site",
      }

      assert_response :forbidden
      assert_equal "urn:umaxica:problem:csrf-verification-failed", response.parsed_body.fetch("type")
    end
  end

  test "Origin rejection precedes changes to real app com and org refresh credentials" do
    %w(PUBLIC_CORE_SERVICE_URL PUBLIC_CORE_CORPORATE_URL PUBLIC_CORE_STAFF_URL).each do |setting|
      host! ENV.fetch(setting)
      https!
      get "/api/v0/session", headers: { "Accept" => "application/json" }

      assert_response :success
      csrf = response.parsed_body.fetch("csrf_token")
      expiry = 2.minutes.from_now.change(usec: 0)
      attributes = {
        oidc_scope: "openid profile",
        oidc_jti: SecureRandom.uuid,
        oidc_nonce: SecureRandom.hex(16),
        oidc_auth_time: 1.minute.ago,
        refresh_token_expires_at: expiry,
      }
      rp =
        case setting
        when "PUBLIC_CORE_SERVICE_URL"
          ClientRpSession.create!(client_token: client_tokens(:one), oidc_client_id: "core-app", **attributes)
        when "PUBLIC_CORE_CORPORATE_URL"
          visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, birthdate: "2000-01-01")
          token = VisitorToken.create!(visitor: visitor, discard_at: expiry)
          VisitorRpSession.create!(visitor_token: token, oidc_client_id: "core-com", **attributes)
        when "PUBLIC_CORE_STAFF_URL"
          OperatorRpSession.create!(
            operator_token: operator_tokens(:one), oidc_client_id: "core-org",
            **attributes,
          )
        else
          raise ArgumentError, "unsupported test surface"
        end
      cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = rp.issue_refresh_token!(expires_at: expiry)
      original_digest = rp.refresh_token_digest
      original_expiry = rp.refresh_token_expires_at

      post "/api/v0/token/refresh", headers: {
        "Accept" => "application/json",
        "X-CSRF-Token" => csrf,
        "Origin" => "https://untrusted.example",
        "Sec-Fetch-Site" => "same-origin",
      }

      assert_response :forbidden
      rp.reload

      assert_equal original_digest, rp.refresh_token_digest
      assert_equal original_expiry, rp.refresh_token_expires_at
      assert_nil rp.previous_refresh_token_digest
      assert_nil rp.refresh_token_rotated_at
      assert_nil rp.revoked_at
    end
  end
end
