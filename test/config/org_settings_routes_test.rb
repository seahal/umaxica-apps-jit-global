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

  test "Auth APP and ORG retain their own identity settings and retire the ORG configuration entry" do
    helpers = Rails.application.routes.url_helpers
    routes = [["PUBLIC_AUTH_SERVICE_URL", "auth/app/settings"], ["PUBLIC_AUTH_STAFF_URL", "auth/org/settings"]]
    routes.each do |name, controller|
      host = ENV.fetch(name)
      route = Rails.application.routes.recognize_path("https://#{host}/settings", method: :get)

      assert_equal controller, route.fetch(:controller)
      assert_equal "show", route.fetch(:action)
    end
    assert_not_respond_to helpers, :auth_org_configuration_path
    auth_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("https://#{auth_host}/configuration", method: :get)
    end
  end

  test "Auth settings retain their surface-specific credential routes" do
    routes = [
      ["PUBLIC_AUTH_SERVICE_URL", "/settings/apple", "auth/app/settings/apples"],
      ["PUBLIC_AUTH_SERVICE_URL", "/settings/google", "auth/app/settings/googles"],
      ["PUBLIC_AUTH_STAFF_URL", "/settings/entra", "auth/org/settings/entras"],
    ]
    routes.each do |name, path, controller|
      host = ENV.fetch(name)
      route = Rails.application.routes.recognize_path("https://#{host}#{path}", method: :get)

      assert_equal controller, route.fetch(:controller)
      assert_equal "show", route.fetch(:action)
    end
  end
end
