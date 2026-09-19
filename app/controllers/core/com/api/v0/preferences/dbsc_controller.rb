# typed: false
# frozen_string_literal: true

module Core
  module Com
    module Api
      module V0
        module Preferences
          class DbscController < Core::Com::ApplicationController
            include ::PreferenceWebCookieEndpoint

            include ::PreferenceDbscRegistrationEndpoint

            AUTHENTICATION_MODE = :deny_all
            declare_authentication_mode! :open

            skip_before_action :resolve_param_context, raise: false
            skip_before_action :set_region, raise: false

            skip_before_action :set_color_theme, raise: false
            skip_before_action :enforce_withdrawal_gate!
            skip_before_action :transparent_refresh_access_token
            skip_before_action :enforce_verification_if_required

            private

            def dbsc_url
              core_com_api_v0_preferences_dbsc_url
            end
          end
        end
      end
    end
  end
end
