# typed: false
# frozen_string_literal: true

module Side
  module Org
    module Web
      module V0
        # Persists cookie-consent choices made through the Side chrome banner. Mirrors the
        # auth and core web preference authorities.
        class CookiesController < Side::Org::ApplicationController
          include ::PreferenceWebCookieEndpoint

          include ::PreferenceWebCookieActions

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
