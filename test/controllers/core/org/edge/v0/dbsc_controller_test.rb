# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# The preference DBSC registration endpoint is `core/*/edge/v0/dbsc#create`. This assertion used to
# name `base/org/edge/v0/dbsc`, a rename leftover that no route mounted, so it guarded a class no
# request could reach; it was removed as dead code. Pointing the same guarantee at the routed core
# controllers makes it hold for the classes that actually serve the endpoint, on every surface.
module Core
  module Org
    module Edge
      module V0
        class DbscControllerTest < ActiveSupport::TestCase
          self.fixture_table_names = []

          ROUTED_CONTROLLERS = [
            ::Core::App::Edge::V0::DbscController,
            ::Core::Com::Edge::V0::DbscController,
            ::Core::Org::Edge::V0::DbscController,
          ].freeze

          test "the preference dbsc endpoint skips the token callbacks and keeps the preferences cookie" do
            ROUTED_CONTROLLERS.each do |controller|
              before_filters = before_filters_of(controller)

              assert_not_includes before_filters, :transparent_refresh_access_token, controller.name
              assert_not_includes before_filters, :enforce_verification_if_required, controller.name
              assert_includes before_filters, :set_preferences_cookie, controller.name
            end
          end

          # The callback contract above is only meaningful for a class the router reaches.
          test "every controller asserted here is mounted by the router" do
            ROUTED_CONTROLLERS.each do |controller|
              path = controller.name.delete_suffix("Controller").underscore

              mounted =
                Rails.application.routes.routes.any? do |route|
                  route.defaults[:controller] == path && route.defaults[:action] == "create"
                end

              assert mounted, "#{path}#create is asserted on but no route mounts it"
            end
          end

          private

          def before_filters_of(controller)
            controller._process_action_callbacks
              .select { |callback| callback.kind == :before }
              .map(&:filter)
          end
        end
      end
    end
  end
end
