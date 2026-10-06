# typed: false
# frozen_string_literal: true

module Base
  module Com
    class VerificationsController < Base::Com::ApplicationController
      include BaseStepUpIntent
      include SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      public

      def show
        authorize!(current_visitor, to: :show?)
        render_step_up_start!(
          actor: current_visitor, token: current_session_token, allowed_scopes: StepUpScopeCatalog::COM,
          title: t("sign.com.verification.new.title"),
          description: t("sign.com.verification.new.description"),
          action: base_com_verification_path(ri: params[:ri]),
          cancel: base_com_identity_path(ri: params[:ri]),
        )
      end

      def create
        authorize!(current_visitor, to: :show?)
        return redirect_to_bootstrap_choice if available_step_up_methods(current_visitor).blank?

        redirect_to_step_up_ceremony!(
          actor: current_visitor, token: current_session_token, allowed_scopes: StepUpScopeCatalog::COM,
          sign_url_builder: ->(**query) {
            auth_com_verification_url(query.merge(host: ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"), protocol: "https"))
          },
          setup_url_builder: ->(**query) {
            new_auth_com_verification_setup_url(
              query.merge(host: ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"), protocol: "https"),
            )
          },
        )
      end

      private

      def redirect_to_bootstrap_choice
        return if reject_step_up_for_authentication_context!

        scope = requested_step_up_scope(StepUpScopeCatalog::COM)
        requested_step_up_return_to(scope: scope, allowed_scopes: StepUpScopeCatalog::COM)
        redirect_to(
          base_com_verification_setup_path(scope: scope, pt: params[:pt], ri: params[:ri]),
          status: :see_other,
        )
      end

      def bootstrap_registration_methods = %i(passkey email_otp)

      def bootstrap_scope_permitted?(_scope) = true

      def actor_verification_path(**args)
        base_com_verification_path(**args)
      end
    end
  end
end
