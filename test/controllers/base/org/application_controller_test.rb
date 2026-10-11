# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Base
  module Org
    class ApplicationControllerTest < ActionDispatch::IntegrationTest
      test "includes expected concerns" do
        controller = ApplicationController.new

        assert_includes controller.class, RateLimit
        assert_includes controller.class, ::PreferenceGlobal
        assert_includes controller.class, ::PreferenceAdoption
        assert_includes controller.class, ::AuthenticationOperator
        assert_includes controller.class, ::AuthorizationOperator
        assert_includes controller.class, ::VerificationOperator
        assert_includes controller.class, ActionPolicy::Controller
        assert_includes controller.class, ::OidcSsoInitiator
        assert_includes controller.class, ::ActorSupport
        assert_includes controller.class, ::Finisher
      end

      test "has preference-related before_action callbacks" do
        callbacks = ApplicationController._process_action_callbacks
        before_filters = callbacks.select { |c| c.kind == :before }.map(&:filter)

        assert_includes before_filters, :set_preferences_cookie
        assert_includes before_filters, :resolve_param_context
        assert_includes before_filters, :set_region
        assert_includes before_filters, :set_color_theme
      end

      test "has correct callback order" do
        callbacks = ApplicationController._process_action_callbacks
        before_filters = callbacks.select { |c| c.kind == :before }.map(&:filter)

        expected_order = %i(
          set_current_context
          reset_flash
          set_preferences_cookie
          resolve_param_context
          set_region
          transparent_refresh_access_token
          set_current_actor
          apply_localization_preferences
          set_color_theme
          enforce_verification_if_required
          enforce_access_policy!
        )

        expected_order.each_cons(2) do |first, second|
          assert_operator before_filters.index(first), :<, before_filters.index(second)
        end
      end

      test "clears actor context through around lifecycle" do
        callbacks = ApplicationController._process_action_callbacks
        around_filters = callbacks.select { |c| c.kind == :around }.map(&:filter)

        assert_includes around_filters, :with_actor_lifecycle
      end
    end
  end
end
