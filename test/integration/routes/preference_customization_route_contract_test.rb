# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Prefer::reset legacy shim must not return. The preference customization
# singleton resource must be the only vocabulary on every base surface.
class PreferenceCustomizationRouteContractTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  BASE_APP_HOST = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
  BASE_COM_HOST = ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")
  BASE_ORG_HOST = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")

  SURFACES = {
    app: { host: BASE_APP_HOST, controller_prefix: "base/app" },
    com: { host: BASE_COM_HOST, controller_prefix: "base/com" },
    org: { host: BASE_ORG_HOST, controller_prefix: "base/org" },
  }.freeze

  test "preference customization edit is recognized on every surface" do
    SURFACES.each do |_surface, config|
      recognized = Rails.application.routes.recognize_path(
        "http://#{config.fetch(:host)}/preference/customization/edit",
        method: :get,
      )

      assert_equal "#{config.fetch(:controller_prefix)}/preference/customizations",
                   recognized[:controller]
      assert_equal "edit", recognized[:action]
    end
  end

  test "preference customization destroy is recognized on every surface" do
    SURFACES.each do |_surface, config|
      recognized = Rails.application.routes.recognize_path(
        "http://#{config.fetch(:host)}/preference/customization",
        method: :delete,
      )

      assert_equal "#{config.fetch(:controller_prefix)}/preference/customizations",
                   recognized[:controller]
      assert_equal "destroy", recognized[:action]
    end
  end

  test "preference customization helpers generate expected paths on every surface" do
    helpers = Rails.application.routes.url_helpers

    SURFACES.each do |surface, config|
      edit_helper = "edit_base_#{surface}_preference_customization_path"
      destroy_helper = "base_#{surface}_preference_customization_path"

      assert_respond_to helpers, edit_helper.to_sym
      assert_respond_to helpers, destroy_helper.to_sym

      assert_equal "/preference/customization/edit",
                   helpers.public_send(edit_helper, host: config.fetch(:host))
      assert_equal "/preference/customization",
                   helpers.public_send(destroy_helper, host: config.fetch(:host))
    end
  end

  test "preference reset helpers are no longer exposed on any surface" do
    helpers = Rails.application.routes.url_helpers

    SURFACES.each_key do |surface|
      assert_not_respond_to helpers, :"edit_base_#{surface}_preference_reset_path"
      assert_not_respond_to helpers, :"base_#{surface}_preference_reset_path"
    end
  end

  test "preference reset paths are no longer routable on any surface" do
    SURFACES.each do |_surface, config|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{config.fetch(:host)}/preference/reset/edit",
          method: :get,
        )
      end

      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{config.fetch(:host)}/preference/reset",
          method: :delete,
        )
      end
    end
  end

  test "host constraint excludes preference customization routes from foreign base hosts" do
    SURFACES.each do |surface, config|
      # The app pairing uses com as the foreign host for app and org surfaces
      # (a surface is never gated on a foreign base host).
      foreign_surface = (surface == :app) ? :org : :app

      recognized = Rails.application.routes.recognize_path(
        "http://#{SURFACES.fetch(foreign_surface).fetch(:host)}/preference/customization/edit",
        method: :get,
      )

      assert_not_equal "#{config.fetch(:controller_prefix)}/preference/customizations", recognized[:controller]
      assert_equal "#{SURFACES.fetch(foreign_surface).fetch(:controller_prefix)}/preference/customizations",
                   recognized[:controller]
    end
  end
end
