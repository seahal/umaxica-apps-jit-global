# typed: false
# frozen_string_literal: true

module Base
  module App
    class PreferencesBaseController < Base::App::ApplicationController
      include ::PreferenceCore
      include ::BasePreferenceViewRouteAliases
      include ::SurfaceInertiaPage
      include ::PreferenceWebCookieEndpoint

      AUTHENTICATION_MODE = :open

      helper_method :preference_base_i18n_key, :preference_acme_i18n_key

      before_action :authorize_preference_write!, if: :preference_write_request?

      rescue_from PreferenceBase::ResolutionError, with: :render_preference_dependency_failure

      private

      def preference_write_request?
        !request.get? && !request.head?
      end

      def authorize_preference_write!
        authorize!(@preferences || preference_class, to: :update?)
      end

      def render_preference_dependency_failure
        head :service_unavailable
      end
    end
  end
end
