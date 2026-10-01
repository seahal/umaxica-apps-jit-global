# typed: false
# frozen_string_literal: true

module Base
  module Com
    class VerificationsController < Base::Com::ApplicationController
      include BaseStepUpIntent

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_visitor!

      def show
        authorize!(current_visitor, to: :show?)
        redirect_to_step_up_ceremony!(
          surface: "com",
          actor: current_visitor,
          token: current_session_token,
          allowed_scopes: StepUpScopeCatalog::COM,
          sign_url_builder: ->(**query) {
            auth_com_verification_url(
              query.merge(
                host: ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
                protocol: "https",
              ),
            )
          },
        )
      end

      private

      def actor_verification_path(**args)
        base_com_verification_path(**args)
      end
    end
  end
end
