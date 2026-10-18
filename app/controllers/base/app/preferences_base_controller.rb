# typed: false
# frozen_string_literal: true

module Base
  module App
    class PreferencesBaseController < Base::App::ApplicationController
      include ::PreferenceCore
      include ::BasePreferenceViewRouteAliases
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :open

      helper_method :preference_base_i18n_key, :preference_acme_i18n_key

      before_action :authorize_preference_write!, if: :preference_write_request?

      private

      def preference_write_request?
        !request.get? && !request.head?
      end

      def authorize_preference_write!
        authorize!(@preferences || preference_class, to: :update?)
      end
    end
  end
end
