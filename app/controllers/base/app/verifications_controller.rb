# typed: false
# frozen_string_literal: true

module Base
  module App
    class VerificationsController < Base::App::ApplicationController
      include BaseStepUpIntent

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_client!

      def show
        authorize!(current_client, to: :show?)
        redirect_to_step_up_ceremony!(
          surface: "app",
          actor: current_client,
          token: current_session_token,
          allowed_scopes: StepUpScopeCatalog::APP,
          sign_url_builder: ->(**query) {
            auth_app_verification_url(
              query.merge(host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), protocol: "https"),
            )
          },
        )
      end

      private

      def actor_verification_path(**args)
        base_app_verification_path(**args)
      end
    end
  end
end
