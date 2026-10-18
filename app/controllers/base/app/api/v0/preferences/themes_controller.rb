# typed: false
# frozen_string_literal: true

module Base
  module App
    module Api
      module V0
        module Preferences
          class ThemesController < Base::App::ApplicationController
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
            skip_before_action :set_color_theme, raise: false
          end
        end
      end
    end
  end
end
