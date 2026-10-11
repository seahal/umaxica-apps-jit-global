# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Base
  module App
    class ApplicationControllerTest < ActiveSupport::TestCase
      def test_includes_expected_concerns
        controller = ApplicationController.new

        assert_includes controller.class, RateLimit
        assert_includes controller.class, ::PreferenceGlobal
        assert_includes controller.class, ::PreferenceAdoption
        assert_includes controller.class, ::AuthenticationClient
        assert_includes controller.class, ::AuthorizationClient
        assert_includes controller.class, ::VerificationClient
        assert_includes controller.class, ActionPolicy::Controller
        assert_includes controller.class, ::OidcSsoInitiator
        assert_includes controller.class, ::ActorSupport
        assert_includes controller.class, ::Finisher
      end

      def test_has_preference_related_before_action_callbacks
        callbacks = ApplicationController._process_action_callbacks
        before_filters = callbacks.select { |c| c.kind == :before }.map(&:filter)

        assert_includes before_filters, :set_preferences_cookie
        assert_includes before_filters, :resolve_param_context
        assert_includes before_filters, :set_region
        assert_includes before_filters, :set_color_theme
      end

      def test_has_correct_callback_order
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
          enforce_withdrawal_gate!
          enforce_verification_if_required
          enforce_access_policy!
        )

        expected_order.each_cons(2) do |first, second|
          first_idx = before_filters.index(first)
          second_idx = before_filters.index(second)

          next unless first_idx && second_idx

          assert_operator first_idx, :<, second_idx,
                          "#{first} should come before #{second}"
        end
      end

      def test_clears_actor_context_through_around_lifecycle
        callbacks = ApplicationController._process_action_callbacks
        around_filters = callbacks.select { |c| c.kind == :around }.map(&:filter)

        assert_includes around_filters, :with_actor_lifecycle
      end

      def test_trusts_only_the_base_app_origin_by_default
        trusted_origins = ApplicationController.forgery_protection_trusted_origins

        assert_includes trusted_origins, "https://#{ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")}"
        assert_not_includes trusted_origins, "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")}"
      end
    end
  end
end
