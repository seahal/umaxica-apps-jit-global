# typed: false
# frozen_string_literal: true

module Warp
  module Org
    module Api
      module V0
        module Preferences
          # Persists the theme chosen through the Warp chrome control on this host. The shared
          # behaviour lives in the endpoint, actions, and PreferenceBrowserApi concerns.
          class ThemesController < Warp::Org::ApplicationController
            include ::PreferenceWebThemeEndpoint

            include ::PreferenceWebThemeActions

            include ::PreferenceBrowserApi

            preference_browser_api!

            AUTHENTICATION_MODE = :open

            declare_authentication_mode! :open

            skip_before_action :set_preferences_cookie, raise: false
            skip_before_action :set_current_actor, raise: false
            skip_before_action :set_color_theme, raise: false
          end
        end
      end
    end
  end
end
