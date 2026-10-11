# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Palm
  module App
    module Oidc
      class CallbacksControllerTest < ActionDispatch::IntegrationTest
        # rubocop:disable I18n/RailsI18n/DecorateString
        STATIC_MESSAGE = "This URL is reserved for completing app authentication.\n" \
                         "Open the mobile app and try signing in again."
        # rubocop:enable I18n/RailsI18n/DecorateString

        test "reserved callback stub returns static no-store response without authentication" do
          host = ENV.fetch("PUBLIC_PALM_SERVICE_URL")

          get palm_app_oidc_callback_url(host: host)

          assert_response :ok
          assert_equal "text/plain", response.media_type
          assert_equal STATIC_MESSAGE, response.body
          assert_equal "no-store", response.headers["Cache-Control"]
          assert_nil response.headers["Set-Cookie"]
        end

        test "platform callback paths do not route" do
          host = ENV.fetch("PUBLIC_PALM_SERVICE_URL")

          assert_no_oauth_mutation do
            OidcTokenExchangeCoordinator.stub(:call, ->(**) { flunk("Palm callback must not call token exchange") }) do
              assert_raises(ActionController::RoutingError) do
                Rails.application.routes.recognize_path("https://#{host}/oauth/callback/ios", method: :get)
              end

              assert_raises(ActionController::RoutingError) do
                Rails.application.routes.recognize_path("https://#{host}/oauth/callback/android", method: :get)
              end
            end
          end
        end

        private

        def assert_no_oauth_mutation(&)
          assert_no_difference(
            [
              "ClientOidcAuthorizationTransaction.count",
              "ClientOidcConnection.count",
              "ClientToken.count",
            ],
            &
          )
        end
      end
    end
  end
end
