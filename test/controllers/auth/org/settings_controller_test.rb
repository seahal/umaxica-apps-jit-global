# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @auth_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    @base_host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
  end

  test "Auth ORG settings routes are retired while Base owns Entra status" do
    %w(/settings /settings/entra /settings/entra/edit).each do |path|
      %i(get post put patch delete).each do |method|
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("https://#{@auth_host}#{path}", method: method)
        end
      end
    end

    route = Rails.application.routes.recognize_path(
      "https://#{@base_host}/identity/social_identities",
      method: :get,
    )

    assert_equal "base/org/identity/social_identities", route.fetch(:controller)
    assert_equal "index", route.fetch(:action)
  end
end
