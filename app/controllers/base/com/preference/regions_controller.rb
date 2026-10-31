# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Preference
      class RegionsController < Base::Com::PreferencesBaseController
        include ::BasePreferenceScreenDispatch
        include ::ComPreferenceScreenWrites

        AUTHENTICATION_MODE = :open

        rescue_from PreferenceBase::ResolutionError, with: :render_preference_dependency_failure

        before_action :ensure_preferences_record

        private

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
      end
    end
  end
end
