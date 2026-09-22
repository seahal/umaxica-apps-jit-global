# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Palm
  module App
    class OidcBoundaryTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      test "palm app exposes only the generic reserved oidc callback stub and no issuer endpoints" do
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

      test "palm app exposes bearer profile api under the api namespace" do
        host = ENV.fetch("PUBLIC_PALM_SERVICE_URL")

        assert_equal(
          "palm/app/api/v0/profiles#show",
          route_to("https://#{host}/api/v0/profile", method: :get),
        )
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
