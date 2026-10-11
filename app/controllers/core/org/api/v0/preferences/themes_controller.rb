# typed: false
# frozen_string_literal: true

module Core
  module Org
    module Api
      module V0
        module Preferences
          class ThemesController < Core::Org::ApplicationController
            include ::PreferenceWebThemeEndpoint

            include ::PreferenceWebThemeActions

            AUTHENTICATION_MODE = :open

            declare_authentication_mode! :open

            skip_before_action :set_preferences_cookie, raise: false
            skip_before_action :set_current_actor, raise: false
          end
        end
      end
    end
  end
end
