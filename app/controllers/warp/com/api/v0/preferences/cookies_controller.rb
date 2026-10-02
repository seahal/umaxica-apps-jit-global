# typed: false
# frozen_string_literal: true

module Warp
  module Com
    module Api
      module V0
        module Preferences
          # Records cookie-consent choices made through the Warp chrome banner on this host. The
          # shared behaviour lives in the endpoint, actions, and PreferenceBrowserApi concerns.
          class CookiesController < Warp::Com::ApplicationController
            include ::PreferenceWebCookieEndpoint

            include ::PreferenceWebCookieActions

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
