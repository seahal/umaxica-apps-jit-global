# typed: false
# frozen_string_literal: true

module Core
  module Org
    module Api
      module V0
        module Preferences
          class DbscController < Core::Org::ApplicationController
            include ::PreferenceWebCookieEndpoint

            include ::PreferenceDbscRegistrationEndpoint

            AUTHENTICATION_MODE = :deny_all
            declare_authentication_mode! :open

            skip_before_action :resolve_param_context, raise: false
            skip_before_action :set_region, raise: false

            skip_before_action :set_color_theme, raise: false
            skip_before_action :enforce_verification_if_required
            skip_before_action :transparent_refresh_access_token

            private

            def dbsc_url
              core_org_api_v0_preferences_dbsc_url
            end
          end
        end
      end
    end
  end
end
