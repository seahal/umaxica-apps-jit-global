# typed: false
# frozen_string_literal: true

require "test_helper"

class OpaqueResultTransportTest < ActionDispatch::IntegrationTest
  SURFACES = [
    {
      auth_host_env: "PUBLIC_AUTH_SERVICE_URL",
      auth_route: "auth/app/sign/oidc_handoffs",
      auth_host_fallback: "auth.app.localhost",
      base_host_env: "PUBLIC_BASE_SERVICE_URL",
      base_route: "base/app/oauth/authorizations",
      base_host_fallback: "base.app.localhost",
    },
    {
      auth_host_env: "PUBLIC_AUTH_CORPORATE_URL",
      auth_route: "auth/com/sign/oidc_handoffs",
      auth_host_fallback: "auth.com.localhost",
      base_host_env: "PUBLIC_BASE_CORPORATE_URL",
      base_route: "base/com/oauth/authorizations",
      base_host_fallback: "base.com.localhost",
    },
    {
      auth_host_env: "PUBLIC_AUTH_STAFF_URL",
      auth_route: "auth/org/sign/oidc_handoffs",
      auth_host_fallback: "auth.org.localhost",
      base_host_env: "PUBLIC_BASE_STAFF_URL",
      base_route: "base/org/oauth/authorizations",
      base_host_fallback: "base.org.localhost",
    },
  ].freeze

  test "Auth handoff and Base result routes are POST-capable for every surface" do
    SURFACES.each do |surface|
      auth_host = ENV.fetch(surface.fetch(:auth_host_env), surface.fetch(:auth_host_fallback))
      base_host = ENV.fetch(surface.fetch(:base_host_env), surface.fetch(:base_host_fallback))

      assert_recognizes(
        { controller: surface.fetch(:auth_route), action: "show" },
        { path: "http://#{auth_host}/sign/oidc/handoff", method: :get },
      )
      assert_recognizes(
        { controller: surface.fetch(:auth_route), action: "create" },
        { path: "http://#{auth_host}/sign/oidc/handoff", method: :post },
      )
      assert_recognizes(
        { controller: surface.fetch(:base_route), action: "create" },
        { path: "http://#{base_host}/oauth/authorize", method: :post },
      )
    end
  end

  test "GET result query never consumes an opaque result" do
    SURFACES.each do |surface|
      base_host = ENV.fetch(surface.fetch(:base_host_env), surface.fetch(:base_host_fallback))
      consumed = false

      BaseAuthAdmissionCoordinator.stub(
        :consume_result!,
        ->(**) { consumed = true; flunk("GET must not consume an OIDC result") },
      ) do
        get(
          "http://#{base_host}/oauth/authorize",
          params: { result: SecureRandom.urlsafe_base64(24) },
          headers: { "Host" => base_host },
        )
      end

      assert_response :bad_request
      assert_not consumed
    end
  end

  test "cross-site result POST is rejected by Rails forgery protection" do
    original_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    post(
      "http://#{base_host}/oauth/authorize",
      params: { result: SecureRandom.urlsafe_base64(24) },
      headers: {
        "Host" => base_host,
        "Origin" => "https://attacker.example",
        "Sec-Fetch-Site" => "cross-site",
      },
    )

    assert_response :unprocessable_content
  ensure
    ActionController::Base.allow_forgery_protection = original_forgery_protection
  end
end
