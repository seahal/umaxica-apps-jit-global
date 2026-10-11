# typed: false
# frozen_string_literal: true

module Side
  module Org
    module Web
      module V0
        # Persists the theme chosen through the Side chrome control. Mirrors the auth and
        # core web preference authorities; behaviour lives in the shared concerns.
        class ThemesController < Side::Org::ApplicationController
          include ::PreferenceWebThemeEndpoint

          include ::PreferenceWebThemeActions

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
