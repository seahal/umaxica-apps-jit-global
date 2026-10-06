# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      class BirthdatesController < BaseController
        include ::SurfaceInertiaPage
        include VerificationClient

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authorize_birthdate!, only: :show
        step_up only: :show
        def show
          render inertia: true, props: {
            title: t("sign.app.settings.birthdate.show.page_title"),
            description: t("sign.app.settings.birthdate.show.description"),
            change_unavailable: t("sign.app.settings.birthdate.show.change_unavailable"),
            birthdate_label: t("sign.app.settings.birthdate.show.birthdate_label"),
            not_set_label: t("sign.app.settings.birthdate.show.not_set"),
            birthdate: current_client.birthdate&.to_s,
            back_link: {
              label: t("sign.app.settings.show.back"),
              href: base_app_identity_path(ri: params[:ri]),
            },
          }
        end

        private

        def authorize_birthdate! = authorize!(current_client, to: :show?)

        def verification_scope = "settings_birthdate"
      end
    end
  end
end
