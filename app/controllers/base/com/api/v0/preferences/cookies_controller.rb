# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Api
      module V0
        module Preferences
          class CookiesController < Base::Com::ApplicationController
            include ::PreferenceWebCookieEndpoint

            include ::PreferenceWebCookieActions

            include ::PreferenceBrowserApi

            preference_browser_api!
            # `preference_browser_api!` re-fronts the availability gate; DefaultNoStore stays ahead of it.
            prepend_before_action :apply_default_no_store

            AUTHENTICATION_MODE = :open

            rescue_from PreferenceBase::ResolutionError, with: :render_preference_dependency_failure
            rescue_from PreferenceBrowserBinding::MismatchError, with: :render_binding_mismatch

            skip_before_action :set_preferences_cookie

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
