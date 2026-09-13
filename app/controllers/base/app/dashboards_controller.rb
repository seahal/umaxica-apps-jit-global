# typed: false
# frozen_string_literal: true

module Base
  module App
    class DashboardsController < Base::App::FullAccessController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def show
        authorize!(current_client, to: :show?)
        render inertia: true, props: show_page_props
      end

      private

      def show_page_props
        {
          title: t("base.shared.dashboard.title"),
          description: t("base.shared.dashboard.description"),
          sections: [
            { heading: t("base.shared.dashboard.sections.primary_links"), items: primary_links },
            { heading: t("base.shared.dashboard.sections.protocol_links"), items: protocol_links },
          ],
        }
      end

      def primary_links
        [
          { label: t("base.shared.dashboard.links.root"), href: base_app_root_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.dashboard"), href: base_app_dashboard_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.account"), href: base_app_accounts_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.organization"), href: base_app_organizations_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.avatar"), href: base_app_avatars_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.switcher"), href: base_app_switcher_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.identity"), href: base_app_identity_path(ri: params[:ri]) },
          {
            label: t("base.shared.identity.links.sessions"),
            href: base_app_identity_sessions_path(ri: params[:ri]),
          },
          { label: t("base.shared.dashboard.links.logout"), href: new_base_app_sign_out_path(ri: params[:ri]) },
        ]
      end

      def protocol_links
        [
          {
            label: t("base.shared.dashboard.links.authorize_sign_in"),
            href: base_app_oidc_authorization_path(ri: params[:ri], screen_hint: "signin"),
          },
          {
            label: t("base.shared.dashboard.links.authorize_sign_up"),
            href: base_app_oidc_authorization_path(ri: params[:ri], screen_hint: "signup"),
          },
          { label: t("base.shared.dashboard.links.oidc_discovery"),
            href: base_app_well_known_openid_configuration_path, },
          { label: t("base.shared.dashboard.links.jwks"), href: base_app_well_known_jwks_path },
          { label: t("base.shared.dashboard.links.userinfo"), href: base_app_oauth_userinfo_path },
        ]
      end
    end
  end
end
