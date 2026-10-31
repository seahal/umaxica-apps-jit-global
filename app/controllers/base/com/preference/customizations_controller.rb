# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Preference
      class CustomizationsController < Base::Com::PreferencesBaseController
        include ::PreferenceSignScreenActions
        include ::BasePreferenceScreenPage

        AUTHENTICATION_MODE = :open

        rescue_from PreferenceBase::ResolutionError, with: :render_preference_dependency_failure

        before_action :ensure_preferences_record

        def edit
          edit_reset_preference_screen
          return if performed?

          render inertia: preference_customization_component, props: preference_customization_page_props
        end

        def destroy
          destroy_reset_preference_screen
        end

        protected

        def destroy_reset_preference_screen
          @preference = ComPreference.new.require_reset_confirmation(params[:confirm_reset])
          unless params[:confirm_reset] == "1"
            @preference.errors.add(:confirm_reset, :accepted)
            errors = @preference.errors.to_hash(true).transform_values(&:first)
            redirect_to(
              reset_preference_edit_url, inertia: { errors: errors },
            )
            return
          end

          write_preference!(operation: :reset, actor: Actor.current, submitted: {})
          cookies.delete(
            PreferenceBrowserBinding::COOKIE_NAME,
            path: "/", httponly: true, same_site: :lax, secure: true,
          )
          redirect_to(preference_index_path_without_context, status: :see_other)
        end

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
