# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Palm
  module App
    class OidcBoundaryTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      test "palm app exposes the Browser RP callback and no issuer endpoints" do
        host = ENV.fetch("PUBLIC_PALM_SERVICE_URL")

        assert_equal(
          "palm/app/oidc/callbacks#show",
          route_to("https://#{host}/oidc/callback", method: :get),
        )

        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("https://#{host}/oidc/authorization", method: :get)
        end

        source = Rails.root.join("config/routes/palm.rb").read

        assert_not_includes source, "ios"
        assert_not_includes source, "android"
        assert_not_includes source, 'controller: "ios"'
        assert_not_includes source, 'controller: "android"'

        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("https://#{host}/oauth/callback/ios", method: :get)
        end
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("https://#{host}/oauth/callback/android", method: :get)
        end
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("https://#{host}/oauth/authorize", method: :get)
        end
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("https://#{host}/oauth/token", method: :post)
        end
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("https://#{host}/api/v0/token/refresh", method: :post)
        end
      end

      test "palm native profile and authorization endpoints are retired" do
        host = ENV.fetch("PUBLIC_PALM_SERVICE_URL")

        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("https://#{host}/api/v0/profile", method: :get)
        end

        %w(app-ios-rp app-android-rp).each do |client_id|
          assert_nil OidcClientRegistry.find(client_id), client_id
        end
      end

      test "retired Palm clients cannot exchange authorization codes or refresh tokens" do
        palm_host = ENV.fetch("PUBLIC_PALM_SERVICE_URL")

        %w(app-ios-rp app-android-rp).each do |client_id|
          authorization_code_result = OidcTokenExchangeCoordinator.call(
            grant_type: "authorization_code",
            code: "retired-palm-code",
            redirect_uri: "https://#{palm_host}/oauth/callback",
            client_id: client_id,
            client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
            client_assertion: "retired-palm-assertion",
            token_endpoint_uri: OidcIssuer.token_endpoint("client"),
            code_verifier: "retired-palm-verifier",
            expected_resource_type: "client",
          )
          refresh_token_result = OidcTokenExchangeCoordinator.call(
            grant_type: "refresh_token",
            refresh_token: "retired-palm-refresh-token",
            client_id: client_id,
            client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
            client_assertion: "retired-palm-assertion",
            token_endpoint_uri: OidcIssuer.token_endpoint("client"),
            expected_resource_type: "client",
          )

          assert_equal "invalid_client", authorization_code_result.error, client_id
          assert_equal "invalid_client", refresh_token_result.error, client_id
        end
      end

      test "sign does not own native client registration or oauth issuance routes" do
        native_ids = OidcClientRegistry.client_ids.grep(/\Asign.*(?:ios|android|native)|(?:ios|android|native).*sign/i)

        assert_empty native_ids

        sign_host = ENV.fetch("PRIVATE_AUTH_SERVICE_URL")
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("https://#{sign_host}/oauth/authorize", method: :get)
        end
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("https://#{sign_host}/oauth/token", method: :post)
        end
      end

      private

      def route_to(path, method:)
        Rails.application.routes.recognize_path(path, method: method).values_at(:controller, :action).join("#")
      end
    end
  end
end
