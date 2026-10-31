# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Preference
      class ScreensController < Base::Com::PreferencesBaseController
        include ::BasePreferenceScreenDispatch
        include ::ComPreferenceScreenWrites

        AUTHENTICATION_MODE = :open

        rescue_from PreferenceBase::ResolutionError, with: :render_preference_dependency_failure
        rescue_from PreferenceBrowserBinding::MismatchError, with: :render_binding_mismatch

        before_action :ensure_preferences_record

        private

        def preference_key = params[:preference_screen].to_s

        def preference_cookie_screen_state = cookie_consent_state

        def dispatch_preference_screen(action)
          @preference_screen = preference_key
          case action
          when :edit then dispatch_com_edit
          when :update then dispatch_com_update
          else head :unprocessable_content
          end
        end

        def dispatch_com_edit
          case @preference_screen
          when "region" then edit_region_preference_screen
          when "timezone" then edit_timezone_preference_screen
          when "language" then edit_language_preference_screen
          when "currency" then edit_selectable_preference_screen(:currency)
          when "calendar" then edit_selectable_preference_screen(:date_format)
          when "clock" then edit_selectable_preference_screen(:time_format)
          when "motion" then edit_selectable_preference_screen(:motion)
          when "density" then edit_selectable_preference_screen(:density)
          when "pagination" then edit_selectable_preference_screen(:page_size)
          when "theme" then edit_theme_preference_screen
          when "cookie" then edit_cookie_preference_screen
          else head :unprocessable_content
          end
        end

        def dispatch_com_update
          case @preference_screen
          when "region" then update_region_preference_screen
          when "timezone" then update_timezone_preference_screen
          when "language" then update_language_preference_screen
          when "currency" then update_selectable_preference_screen(:currency)
          when "calendar" then update_selectable_preference_screen(:date_format)
          when "clock" then update_selectable_preference_screen(:time_format)
          when "motion" then update_selectable_preference_screen(:motion)
          when "density" then update_selectable_preference_screen(:density)
          when "pagination" then update_selectable_preference_screen(:page_size)
          when "theme" then update_theme_preference_screen
          when "cookie" then update_cookie_preference_screen
          else head :unprocessable_content
          end
        end

        def render_binding_mismatch = head :forbidden
      end
    end
  end
end
