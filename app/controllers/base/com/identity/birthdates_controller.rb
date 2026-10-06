# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      class BirthdatesController < ::Base::Com::ApplicationController
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :private

        # Object-level authorization (ActionPolicy): only the owner may view their own birthdate.
        # Step-up freshness is still enforced separately below.
        before_action :authorize_birthdate!, only: :show
        step_up only: :show

        def show
          render inertia: true, props: show_page_props
        end

        private

        # The birthdate is displayed as the stored string, exactly as the ERB did. It is the
        # owner's own attribute, behind step-up freshness, and never leaves this owner-scoped page.
        def show_page_props
          birthdate = current_visitor.birthdate
          {
            title: t("sign.com.settings.birthdate.show.page_title"),
            description: t("sign.com.settings.birthdate.show.description"),
            back_link: {
              label: t("sign.app.settings.show.back"),
              href: base_com_identity_path(ri: params[:ri]),
            },
            birthdate_label: t("sign.com.settings.birthdate.show.birthdate_label"),
            birthdate: birthdate.presence&.to_s,
            not_set: t("sign.com.settings.birthdate.show.not_set"),
            change_unavailable: t("sign.com.settings.birthdate.show.change_unavailable"),
          }
        end

        def authorize_birthdate!
          authorize!(current_visitor, to: :show?)
        end

        def verification_scope
          "settings_birthdate"
        end
      end
    end
  end
end
