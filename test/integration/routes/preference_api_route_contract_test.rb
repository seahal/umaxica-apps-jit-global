# frozen_string_literal: true

require "test_helper"

# Base's interactive preference controls use `/api/v0/preferences/{theme,cookie}`. Read-only
# families keep the GET/PATCH route shape so PATCH can return an explicit refusal; none keeps the
# retired `/web/v0` paths (adr/api-route-vocabulary-consolidation.md, 2026-10-02 amendment).
class PreferenceApiRouteContractTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  SURFACE_HOST_KEYS = { "app" => "SERVICE", "com" => "CORPORATE", "org" => "STAFF" }.freeze
  RESOURCES = { "theme" => "themes", "cookie" => "cookies" }.freeze

  test "Base, Auth, and Core serve the preference API route shape with GET and PATCH only" do
    # two.md WU-3: corporate Auth/Core own no Preference API; Base com keeps its anonymous one.
    [%w(base app), %w(base com), %w(base org), %w(auth app), %w(auth org), %w(core app),
     %w(core org),].each do |family, surface|
      host = ENV.fetch("PUBLIC_#{family.upcase}_#{SURFACE_HOST_KEYS.fetch(surface)}_URL")

      RESOURCES.each do |resource, controller|
        url = "http://#{host}/api/v0/preferences/#{resource}"
        expected = "#{family}/#{surface}/api/v0/preferences/#{controller}"

        assert_equal(
          { controller: expected, action: "show" },
          Rails.application.routes.recognize_path(url, method: :get).slice(:controller, :action), url,
        )
        assert_equal(
          { controller: expected, action: "update" },
          Rails.application.routes.recognize_path(url, method: :patch).slice(:controller, :action), url,
        )
        assert_raises(ActionController::RoutingError, "PUT #{url}") do
          Rails.application.routes.recognize_path(url, method: :put)
        end
      end
    end
  end

  test "the retired web theme and cookie paths resolve on no family" do
    %w(base auth core warp).product(%w(app com org)).each do |family, surface|
      host = ENV.fetch("PUBLIC_#{family.upcase}_#{SURFACE_HOST_KEYS.fetch(surface)}_URL")

      %w(theme cookie).product(%i(get patch put)).each do |resource, method|
        assert_raises(ActionController::RoutingError, "#{method} #{host}/web/v0/#{resource}") do
          Rails.application.routes.recognize_path("http://#{host}/web/v0/#{resource}", method: method)
        end
      end
    end
  end

  # Palm and Edit render no preference controls, so they serve no preference API.
  test "palm and edit serve no browser preference API" do
    [ENV.fetch("PUBLIC_PALM_SERVICE_URL"), ENV.fetch("PUBLIC_EDIT_STAFF_URL")].each do |host|
      %w(theme cookie).product(%i(get patch)).each do |resource, method|
        assert_raises(ActionController::RoutingError, "#{method} #{host}/api/v0/preferences/#{resource}") do
          Rails.application.routes.recognize_path("http://#{host}/api/v0/preferences/#{resource}", method: method)
        end
      end
    end
  end

  test "auth keeps the email OTP ceremony under the web namespace" do
    %w(app).each do |surface|
      host = ENV.fetch("PUBLIC_AUTH_#{SURFACE_HOST_KEYS.fetch(surface)}_URL")
      recognized = Rails.application.routes.recognize_path("http://#{host}/web/v0/in/email/otp", method: :post)

      assert_equal "auth/#{surface}/web/v0/in/email/otps", recognized[:controller]
    end
  end
end
