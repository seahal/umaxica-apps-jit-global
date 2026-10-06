# typed: false
# frozen_string_literal: true

module Base
  module App
    class VerificationsController < Base::App::ApplicationController
      include BaseStepUpIntent
      include SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

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
        # An actor without an authenticator chooses one on Base first; nothing is issued here.
        return redirect_to_bootstrap_choice if available_step_up_methods(current_client).blank?

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

      def redirect_to_bootstrap_choice
        return if reject_step_up_for_authentication_context!

        scope = requested_step_up_scope(StepUpScopeCatalog::APP)
        requested_step_up_return_to(scope: scope, allowed_scopes: StepUpScopeCatalog::APP)
        if current_session_token.established_authentication_method == "secret"
          return render plain: t("errors.messages.invalid_request"), status: :bad_request
        end

        redirect_to(
          base_app_verification_setup_path(scope: scope, pt: params[:pt], ri: params[:ri]), status: :see_other,
        )
      end

      def bootstrap_registration_methods = %i(passkey totp)

      def bootstrap_scope_permitted?(scope) = scope != "settings_secret_credential"

      def actor_verification_path(**args)
        base_app_verification_path(**args)
      end
    end
  end
end
