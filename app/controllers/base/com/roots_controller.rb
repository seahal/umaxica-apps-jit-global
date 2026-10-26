# typed: false
# frozen_string_literal: true

module Base
  module Com
    class RootsController < Base::Com::ApplicationController
      include ::SurfaceInertiaPage
      include ::SessionBoundaryNotFound

      AUTHENTICATION_MODE = :open
      declare_authentication_mode! :private, only: :show
      skip_before_action :set_preferences_cookie, only: %i(index show)

      public

      def index
        response.headers["Cache-Control"] = "private, no-store"
        return render_session_boundary_not_found if logged_in?

        render inertia: true, props: root_landing_props,
               clear_history: session[:inertia_clear_history] == true
      end

      def show
        response.headers["Cache-Control"] = "private, no-store"
        authorize!(current_visitor, to: :show?)
        return unless require_selected_actor_context_for_dashboard!

        render inertia: "base/com/dashboards/show", props: dashboard_page_props,
               clear_history: session[:inertia_clear_history] == true
      end

      protected

      def track_authenticated_session_activity?
        return false if (request.get? || request.head?) && %w(index show).include?(action_name)

        super
      end

      private

      # JSON keeps its existing in-request context; browser pages use the shared redirect.
      def set_region
        return super unless request.format.json? && %w(index show).include?(action_name)

        params[:ri] = normalized_param_ri.presence || get_region
      end

      def require_selected_actor_context_for_dashboard!
        return true if Actor.selection.selected?

        if request.format.json?
          render json: { status: "selection_required", next: base_com_selector_path(ri: params[:ri]) },
                 status: :forbidden
        else
          redirect_to(base_com_selector_path(ri: params[:ri]))
        end
        false
      end

      def dashboard_page_props
        {
          title: t("base.shared.dashboard.title"),
          description: t("base.shared.dashboard.description"),
          sections: [
            {
              heading: t("base.shared.dashboard.sections.menu_links"),
              current_identity: dashboard_current_identity,
              items: menu_links,
            },
            { heading: t("base.shared.dashboard.sections.primary_links"), items: primary_links },
          ],
        }
      end

      # R5-WU15: the persona display name comes from its owner over HTTPS.
      def dashboard_current_identity
        result = AvatarAuthorityClient.new(
          surface: "com",
          access_token: BrowserCredentialCookie.read(cookies, OidcRpBrowserCredentialContract::ACCESS_COOKIE),
          persona: Actor.selection.account_public_id,
        ).dashboard_identity
        raise ActiveRecord::RecordNotFound, "selected com Persona is not available to this principal" if
          result.status == :not_found
        raise RuntimeError, "identity owner is unavailable for the dashboard identity" unless result.ok?

        { display_name: result.data.fetch("display_name") }
      end

      def menu_links
        [
          { label: t("base.shared.dashboard.links.preference"), href: base_com_identity_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.switcher"), href: base_com_switcher_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.logout"), href: new_base_com_sign_out_path(ri: params[:ri]) },
        ]
      end

      def primary_links
        [
          { label: t("base.shared.dashboard.links.root"), href: base_com_dashboard_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.account"), href: base_com_accounts_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.organization"), href: base_com_organizations_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.identity"), href: base_com_identity_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.offline"), href: base_com_pwa_offline_path(ri: params[:ri]) },
        ]
      end

      def root_landing_props
        {
          title: nil,
          heading: "Base Com",
          description: t("landing.thin_endpoint"),
          # One neutral entry; any allowed switch to registration happens inside Auth.
          sign_in: { label: t("actions.continue"), href: base_com_sign_show_path(ri: params[:ri]) },
          sign_up: nil,
        }
      end
    end
  end
end
