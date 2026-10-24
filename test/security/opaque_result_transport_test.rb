# typed: false
# frozen_string_literal: true

require "test_helper"

class OpaqueResultTransportTest < ActionDispatch::IntegrationTest
  SURFACES = [
    {
      auth_host_env: "PUBLIC_AUTH_SERVICE_URL",
      auth_route: "auth/app/sign/oidc_handoffs",
      auth_host_fallback: "auth.app.localhost",
      visa_host_env: "PUBLIC_VISA_SERVICE_URL",
      visa_result_route: "visa/app/oidc/results",
      visa_cancellation_route: "visa/app/oidc/cancellations",
      visa_switch_route: "visa/app/oidc/switches",
      visa_host_fallback: "visa.app.localhost",
    },
    {
      auth_host_env: "PUBLIC_AUTH_CORPORATE_URL",
      auth_route: "auth/com/sign/oidc_handoffs",
      auth_host_fallback: "auth.com.localhost",
      visa_host_env: "PUBLIC_VISA_CORPORATE_URL",
      visa_result_route: "visa/com/oidc/results",
      visa_cancellation_route: "visa/com/oidc/cancellations",
      visa_switch_route: "visa/com/oidc/switches",
      visa_host_fallback: "visa.com.localhost",
    },
    {
      auth_host_env: "PUBLIC_AUTH_STAFF_URL",
      auth_route: "auth/org/sign/oidc_handoffs",
      auth_host_fallback: "auth.org.localhost",
      visa_host_env: "PUBLIC_VISA_STAFF_URL",
      visa_result_route: "visa/org/oidc/results",
      visa_cancellation_route: "visa/org/oidc/cancellations",
      visa_host_fallback: "visa.org.localhost",
    },
  ].freeze

  test "Auth handoff and Visa continuation routes are GET resources for every surface" do
    SURFACES.each do |surface|
      auth_host = ENV.fetch(surface.fetch(:auth_host_env), surface.fetch(:auth_host_fallback))
      visa_host = ENV.fetch(surface.fetch(:visa_host_env), surface.fetch(:visa_host_fallback))

      assert_recognizes(
        { controller: surface.fetch(:auth_route), action: "show" },
        { path: "http://#{auth_host}/sign/oidc/handoff", method: :get },
      )
      assert_recognizes(
        { controller: surface.fetch(:visa_result_route), action: "show" },
        { path: "http://#{visa_host}/oidc/result", method: :get },
      )
      assert_recognizes(
        { controller: surface.fetch(:visa_cancellation_route), action: "show" },
        { path: "http://#{visa_host}/oidc/cancellation", method: :get },
      )
      if surface[:visa_switch_route]
        assert_recognizes(
          { controller: surface.fetch(:visa_switch_route), action: "show" },
          { path: "http://#{visa_host}/oidc/switch", method: :get },
        )
      end

      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{auth_host}/sign/oidc/handoff", method: :post,
        )
      end
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{visa_host}/oidc/result", method: :post,
        )
      end
    end
  end

  test "GET result query never consumes an opaque result" do
    SURFACES.each do |surface|
      visa_host = ENV.fetch(surface.fetch(:visa_host_env), surface.fetch(:visa_host_fallback))
      consumed = false

      BaseAuthAdmissionCoordinator.stub(
        :read_result!,
        ->(**) {
          consumed = true

          flunk("GET must not consume an OIDC result")
        },
      ) do
        get(
          "http://#{visa_host}/oidc/result",
          params: {
            result_ref: SecureRandom.urlsafe_base64(24),
            transaction_ref: SecureRandom.uuid,
          },
          headers: {
            "Host" => visa_host,
            "Sec-Fetch-Mode" => "navigate",
            "Sec-Fetch-Dest" => "document",
          },
        )
      end

      assert_response :bad_request
      assert_not consumed
    end
  end

  test "result continuation rejects non-navigation requests" do
    visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL", "visa.app.localhost")

    get(
      "http://#{visa_host}/oidc/result",
      params: {
        result_ref: SecureRandom.urlsafe_base64(24),
        transaction_ref: SecureRandom.uuid,
      },
      headers: { "Host" => visa_host },
    )

    assert_response :bad_request
  end
end
