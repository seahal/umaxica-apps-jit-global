# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Preference
      class CookiesController < Base::Com::PreferencesBaseController
        include ::BasePreferenceScreenDispatch
        include ::ComPreferenceScreenWrites
        include ::PreferenceWebCookieEndpoint

        AUTHENTICATION_MODE = :open

        rescue_from PreferenceBase::ResolutionError, with: :render_preference_dependency_failure
        rescue_from PreferenceBrowserBinding::MismatchError, with: :render_binding_mismatch

        before_action :ensure_preferences_record

        private

        def preference_cookie_screen_state
          cookie_consent_state
        end

        def set_preferences_cookie
          return if preference_write_request?

          super
        end

        def ensure_preferences_record
          return if preference_write_request?

          super
        end

        def render_preference_dependency_failure
          head :service_unavailable
        end

        def render_binding_mismatch
          head :forbidden
        end
      end
    end
  end
end
