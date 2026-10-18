# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class CoreRouteNamingTest < ActionDispatch::IntegrationTest
  BOOT_HOSTS = Rails.configuration.x.boot_config.fetch(:hosts)
  SURFACES = {
    app: ENV.fetch("PUBLIC_CORE_SERVICE_URL", BOOT_HOSTS.core_service.host),
    com: ENV.fetch("PUBLIC_CORE_CORPORATE_URL", BOOT_HOSTS.core_corporate.host),
    org: ENV.fetch("PUBLIC_CORE_STAFF_URL", BOOT_HOSTS.core_staff.host),
  }.freeze

  test "preference csp jwks and token refresh routes use the current core vocabulary" do
    SURFACES.each do |surface, host|
      assert_respond_to self, :"core_#{surface}_well_known_jwks_path"
      assert_equal "/.well-known/jwks.json", public_send(:"core_#{surface}_well_known_jwks_path")

      assert_respond_to self, :"core_#{surface}_api_v0_preferences_cookie_path"
      assert_equal "/api/v0/preferences/cookie",
                   public_send(:"core_#{surface}_api_v0_preferences_cookie_path")

      assert_respond_to self, :"core_#{surface}_api_v0_preferences_theme_path"
      assert_equal "/api/v0/preferences/theme",
                   public_send(:"core_#{surface}_api_v0_preferences_theme_path")

      assert_respond_to self, :"core_#{surface}_api_v0_preferences_dbsc_path"
      assert_equal "/api/v0/preferences/dbsc",
                   public_send(:"core_#{surface}_api_v0_preferences_dbsc_path")

      assert_respond_to self, :"core_#{surface}_csp_violation_report_path"
      assert_equal "/csp-violation-report", public_send(:"core_#{surface}_csp_violation_report_path")

      assert_recognizes_core_route(host, "/.well-known/jwks.json", :get, "core/#{surface}/well_known/jwks", "show")
      assert_recognizes_core_route(
        host,
        "/csp-violation-report",
        :post,
        "core/#{surface}/csp_violation_reports",
        "create",
      )
      assert_recognizes_core_route(
        host,
        "/api/v0/token/refresh",
        :post,
        "core/#{surface}/api/v0/token/refreshes",
        "create",
      )
      assert_unrecognized(host, "/oidc/backchannel/logout", :post)
      assert_unrecognized(host, "/oidc/backchannel_logout", :post)
      assert_unrecognized(host, "/accounts", :get)
      assert_unrecognized(host, "/robots.txt", :get)
      assert_unrecognized(host, "/sitemap.xml", :get)
    end
  end

  private

  def assert_recognizes_core_route(host, path, method, controller_name, action)
    route = Rails.application.routes.recognize_path("https://#{host}#{path}", method: method)

    assert_equal controller_name, route.fetch(:controller)
    assert_equal action, route.fetch(:action)
  end

  def assert_unrecognized(host, path, method)
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("https://#{host}#{path}", method: method)
    end
  end
end
