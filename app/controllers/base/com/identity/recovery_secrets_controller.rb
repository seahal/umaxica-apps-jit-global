# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      class RecoverySecretsController < ::Base::Com::ApplicationController
        include ::SurfaceInertiaPage
        include ::SignSettingsSecretCredentialCacheControl

        AUTHENTICATION_MODE = :private
        REVEAL_PURPOSE = "visitor.recovery_secret_credential"

        before_action :set_no_store_for_secret_credential_pages
        before_action :reject_head_reveal!, only: :show
        before_action :authorize_secrets!, only: :show
        prepend_after_action :set_no_store_for_secret_credential_pages, only: :show

        public

        def show
          response.headers["Referrer-Policy"] = "no-referrer"
          reveal = IdentityOneTimeReveal.consume!(
            actor: current_visitor,
            session_nonce: current_visitor.public_id,
            token: params[:token],
            purpose: REVEAL_PURPOSE,
          )

          render inertia: true, props: {
            title: t("sign.recovery_passcodes.show.title"),
            description: t("sign.recovery_passcodes.show.description"),
            one_time_notice: t("sign.recovery_passcodes.show.one_time_notice"),
            inventory_notice: t("sign.recovery_passcodes.show.inventory_notice"),
            missing_message: t("sign.recovery_passcodes.show.missing"),
            passcodes: Array(reveal&.value).map(&:to_s),
            back_link: {
              label: t("sign.recovery_passcodes.show.back_to_settings"),
              href: base_com_identity_path(ri: params[:ri]),
            },
          }
        end

        protected

        def track_authenticated_session_activity?
          return false if (request.get? || request.head?) && action_name == "show"

          super
        end

        private

        def reject_head_reveal!
          head :method_not_allowed if request.head?
          head :not_found if request.options?
        end

        def authorize_secrets!
          authorize!(current_visitor, to: :show?)
        end
      end
    end
  end
end
