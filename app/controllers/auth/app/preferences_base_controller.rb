# typed: false
# frozen_string_literal: true

module Auth
  module App
    class PreferencesBaseController < ::Auth::App::ApplicationController
      include ::SignAcmeAuthorityRedirect

      AUTHENTICATION_MODE = :open

      layout "auth/app/application"

      prepend_before_action :redirect_localhost_preference_authority!
      ensure_fqdn_gate_first!
      before_action :authorize_preference_write!, if: :preference_write_request?

      private

      def set_preferences_cookie
        return if request.host.end_with?(".localhost")

        super
      end

      def preference_write_request?
        !request.get? && !request.head?
      end

      def authorize_preference_write!
        authorize!(@preferences || preference_class, to: :update?)
      end

      def redirect_localhost_preference_authority!
        return if request.ssl?

        redirect_to_acme_authority!(request.path, query: request.query_parameters)
      end
    end
  end
end
