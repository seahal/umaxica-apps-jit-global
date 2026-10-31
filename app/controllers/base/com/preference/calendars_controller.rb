# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Preference
      class CalendarsController < Base::Com::PreferencesBaseController
        include ::BasePreferenceScreenDispatch
        include ::ComSelectablePreferenceScreen

        AUTHENTICATION_MODE = :open
        rescue_from PreferenceBase::ResolutionError, with: :render_preference_dependency_failure

        before_action :ensure_preferences_record
      end
    end
  end
end
