# typed: false
# frozen_string_literal: true

module Base
  module App
    module Preference
      class NotificationsController < Base::App::PreferencesBaseController
        include ::BasePreferenceNotificationScreen

        AUTHENTICATION_MODE = :open

        private

        def notification_back_link_path
          base_app_preference_path
        end

        def notification_form_action_path
          base_app_preference_notification_path
        end

        def notification_return_path
          edit_base_app_preference_notification_path
        end
      end
    end
  end
end
