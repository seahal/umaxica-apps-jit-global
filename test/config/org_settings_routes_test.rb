# typed: false
# frozen_string_literal: true

require "test_helper"

class OrgSettingsRoutesTest < ActiveSupport::TestCase
  test "Base ORG settings owns the management route and the old route is absent" do
    helper = Rails.application.routes.url_helpers
    base_host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    route = Rails.application.routes.recognize_path("https://#{base_host}/settings", method: :get)

    assert_equal "base/org/settings", route.fetch(:controller)
    assert_equal "show", route.fetch(:action)
    assert_equal "/settings", helper.base_org_settings_path
    assert_not_respond_to helper, :base_org_configuration_path
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("https://#{base_host}/configuration", method: :get)
    end
  end

  test "Auth APP keeps its current entry while Auth ORG settings are retired" do
    helpers = Rails.application.routes.url_helpers
    app_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    app_route = Rails.application.routes.recognize_path("https://#{app_host}/settings", method: :get)

    assert_equal "auth/app/settings", app_route.fetch(:controller)
    assert_equal "show", app_route.fetch(:action)
    assert_not_respond_to helpers, :auth_org_configuration_path
    auth_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")

    %w(/settings /settings/entra /settings/entra/edit /configuration).each do |path|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("https://#{auth_host}#{path}", method: :get)
      end
    end
  end

  test "Auth APP retains social link ceremony entry routes without Entra settings on Auth ORG" do
    routes = [
      ["PUBLIC_AUTH_SERVICE_URL", "/settings/apple", "auth/app/settings/apples"],
      ["PUBLIC_AUTH_SERVICE_URL", "/settings/google", "auth/app/settings/googles"],
    ]
    routes.each do |name, path, controller|
      host = ENV.fetch(name)
      route = Rails.application.routes.recognize_path("https://#{host}#{path}", method: :get)

      assert_equal controller, route.fetch(:controller)
      assert_equal "show", route.fetch(:action)
    end

    org_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("https://#{org_host}/settings/entra", method: :get)
    end

    base_host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    base_route = Rails.application.routes.recognize_path(
      "https://#{base_host}/identity/social_identities",
      method: :get,
    )

    assert_equal "base/org/identity/social_identities", base_route.fetch(:controller)
    assert_equal "index", base_route.fetch(:action)
  end
end
