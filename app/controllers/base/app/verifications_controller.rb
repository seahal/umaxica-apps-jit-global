# typed: false
# frozen_string_literal: true

module Base
  module App
    class VerificationsController < Base::App::ApplicationController
      include BaseStepUpIntent
      include SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_client!

      public

      def show
        authorize!(current_client, to: :show?)
        render_step_up_start!(
          actor: current_client, token: current_session_token, allowed_scopes: StepUpScopeCatalog::APP,
          title: t("sign.app.verification.new.title"),
          description: t("sign.app.verification.new.description"),
          action: base_app_verification_path(ri: params[:ri]),
          cancel: base_app_identity_path(ri: params[:ri]),
        )
      end

      def create
        authorize!(current_client, to: :show?)
        redirect_to_step_up_ceremony!(
          actor: current_client, token: current_session_token, allowed_scopes: StepUpScopeCatalog::APP,
          sign_url_builder: ->(**query) {
            auth_app_verification_url(query.merge(host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), protocol: "https"))
          },
          setup_url_builder: ->(**query) {
            new_auth_app_verification_setup_url(
              query.merge(host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), protocol: "https"),
            )
          },
        )
      end

      private

      def bootstrap_registration_methods = %i(passkey totp)

      def bootstrap_scope_permitted?(scope) = scope != "settings_secret_credential"

      def actor_verification_path(**args)
        base_app_verification_path(**args)
      end
    end
  end
end
