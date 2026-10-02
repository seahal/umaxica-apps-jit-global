# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Api
      module V0
        module Preferences
          class ThemesController < PreferencesBaseController
            include ::PreferenceWebThemeEndpoint

            include ::PreferenceWebThemeActions

            include ::PreferenceBrowserApi

            preference_browser_api!
            # `preference_browser_api!` re-fronts the availability gate; DefaultNoStore stays ahead of it.
            prepend_before_action :apply_default_no_store

            AUTHENTICATION_MODE = :open

            declare_authentication_mode! :open

            skip_before_action :set_preferences_cookie, raise: false
            skip_before_action :set_current_actor, raise: false

            private

            def redirect_localhost_preference_authority!
              # This host serves its own UX preference transport (theme, cookie consent; see
              # adr/preference-browser-transport-family-capability.md). The localhost HTML redirect
              # to the Base preference screens must not intercept it.
            end
          end
        end
      end
    end
  end
end
