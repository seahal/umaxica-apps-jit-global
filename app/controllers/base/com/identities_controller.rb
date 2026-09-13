# typed: false
# frozen_string_literal: true

module Base
  module Com
    class IdentitiesController < Base::Com::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_visitor!

      def show
        authorize!(current_visitor, to: :show?)
        render inertia: true, props: {
          title: "Identity",
          description: "Signed in",
          up_link: dashboard_up_link(label: t("base.shared.identity.up_link")),
          sections: identity_hub_sections,
        }
      end

      private

      def identity_hub_sections
        [
          {
            heading: t("base.shared.identity.sections.profile"),
            items: [
              identity_hub_link(:emails, base_com_identity_emails_path(ri: params[:ri])),
              identity_hub_link(:telephones, base_com_identity_telephones_path(ri: params[:ri])),
              identity_hub_link(:birthdate, base_com_identity_birthdate_path(ri: params[:ri])),
            ],
          },
          {
            heading: t("base.shared.identity.sections.security"),
            items: [
              identity_hub_link(:sessions, base_com_identity_sessions_path(ri: params[:ri])),
              identity_hub_link(:secrets, base_com_identity_secrets_path(ri: params[:ri])),
              identity_hub_link(:activities, base_com_identity_activities_path(ri: params[:ri])),
              identity_hub_link(:standing, base_com_identity_standing_path(ri: params[:ri])),
            ],
          },
          {
            heading: t("base.shared.identity.sections.account"),
            items: [
              identity_hub_link(:withdrawal, new_base_com_identity_withdrawal_path(ri: params[:ri])),
              {
                label: t("sign.app.settings.show.logout"),
                href: new_base_com_sign_out_path(ri: params[:ri]),
              },
            ],
          },
        ]
      end

      def identity_hub_link(key, href)
        { label: t(key, scope: "base.shared.identity.links"), href: href }
      end
    end
  end
end
