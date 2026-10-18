# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Identity
      class BirthdatesController < ::Base::Org::ApplicationController
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :private

        # Object-level authorization (ActionPolicy): only the owner may view their own birthdate.
        # Step-up freshness is still enforced separately below.
        before_action :authorize_birthdate!, only: :show
        step_up only: :show

        def show
          render inertia: true, props: {
            title: t("sign.org.settings.birthdate.show.page_title"),
            description: t("sign.org.settings.birthdate.show.description"),
            birthdate_label: t("sign.org.settings.birthdate.show.birthdate_label"),
            birthdate: current_operator.birthdate.presence&.to_s,
            not_set: t("sign.org.settings.birthdate.show.not_set"),
            change_unavailable: t("sign.org.settings.birthdate.show.change_unavailable"),
            back_link: {
              label: t("sign.org.settings.show.back"),
              href: base_org_identity_path(ri: params[:ri]),
            },
          }
        end

        private

        def authorize_birthdate!
          authorize!(current_operator, to: :show?)
        end

        def verification_scope
          "settings_birthdate"
        end
      end
    end
  end
end
