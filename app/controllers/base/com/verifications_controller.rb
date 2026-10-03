# typed: false
# frozen_string_literal: true

module Base
  module Com
    class VerificationsController < Base::Com::ApplicationController
      include BaseStepUpIntent
      include SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_visitor!

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
        redirect_to_step_up_ceremony!(
          actor: current_visitor, token: current_session_token, allowed_scopes: StepUpScopeCatalog::COM,
          sign_url_builder: ->(**query) {
            auth_com_verification_url(query.merge(host: ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"), protocol: "https"))
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
