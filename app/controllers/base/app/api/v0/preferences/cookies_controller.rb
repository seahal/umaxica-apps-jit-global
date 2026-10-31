# typed: false
# frozen_string_literal: true

module Base
  module App
    module Api
      module V0
        module Preferences
          class CookiesController < Base::App::ApplicationController
            include ::PreferenceWebCookieEndpoint

            include ::PreferenceWebCookieActions

            include ::PreferenceBrowserApi

            preference_browser_api!
            # `preference_browser_api!` re-fronts the availability gate; DefaultNoStore stays ahead of it.
            prepend_before_action :apply_default_no_store

            AUTHENTICATION_MODE = :open

            declare_authentication_mode! :open

            skip_before_action :set_preferences_cookie, raise: false
            skip_before_action :set_current_actor, raise: false

            rescue_from PreferenceBase::ResolutionError, with: :render_preference_dependency_failure
            rescue_from PreferenceBrowserBinding::MismatchError, with: :render_binding_mismatch

            private

            def render_preference_dependency_failure
              render_problem(:service_unavailable)
            end

            def render_binding_mismatch
              render_problem(:authorization_denied)
            end
          end
        end
      end
    end
  end
end
