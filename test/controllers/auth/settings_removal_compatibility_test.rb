# typed: false
# frozen_string_literal: true

require "test_helper"

# Credential lifecycle moved to Base. The old Auth removal endpoints must remain absent:
# accepting an alias would recreate an Auth-owned mutation boundary.
class AuthSettingsRemovalCompatibilityTest < ActionDispatch::IntegrationTest
  test "retired Auth passkey removal endpoints are unroutable on every surface" do
    {
      app: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
      com: ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
      org: ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
    }.each_value do |host|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("https://#{host}/settings/passkeys/any/removal", method: :post)
      end
    end
  end
end
