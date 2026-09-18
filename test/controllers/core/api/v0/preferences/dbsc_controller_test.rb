# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# The preference DBSC registration endpoint is `/api/v0/preferences/dbsc`. The controller lives
# beside the API route so route ownership is visible without preserving the old Edge namespace.
module Core
  module App
    module Api
      module V0
        module Preferences
          class DbscControllerTest < ActiveSupport::TestCase
            self.fixture_table_names = []

            ROUTED_CONTROLLERS = [
              ::Core::App::Api::V0::Preferences::DbscController,
              ::Core::Com::Api::V0::Preferences::DbscController,
              ::Core::Org::Api::V0::Preferences::DbscController,
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
end
