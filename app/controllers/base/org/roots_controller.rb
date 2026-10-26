# typed: false
# frozen_string_literal: true

module Base
  module Org
    class RootsController < Base::Org::ApplicationController
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
        authorize!(current_operator, to: :show?)
        return unless require_selected_actor_context_for_dashboard!

        render inertia: "base/org/dashboards/show", props: dashboard_page_props,
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
          render json: { status: "selection_required", next: base_org_selector_path(ri: params[:ri]) },
                 status: :forbidden
        else
          redirect_to(base_org_selector_path(ri: params[:ri]))
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
            administration_section,
          ].compact,
        }
      end

      # adr/operator-capability-authorization.md: administration is listed apart from the operator's
      # own links, and only for consoles this operator holds a capability for. Hiding a link is
      # presentation; every console authorizes again on its own.
      def administration_section
        items = []
        if allowed_to?(:support?, :org_console, with: OrgConsolePolicy)
          items << { label: t("base.org.admin.support.title"), href: base_org_support_index_path(ri: params[:ri]) }
        end
        if allowed_to?(:iam?, :org_console, with: OrgConsolePolicy)
          items << { label: t("base.org.admin.iam.title"), href: base_org_iam_index_path(ri: params[:ri]) }
        end
        return nil if items.empty?

        { heading: t("base.org.admin.dashboard.administration"), items: items }
      end

      # R5-WU14: persona display name and Avatar image version come from their owner over HTTPS.
      def dashboard_current_identity
        result = AvatarAuthorityClient.new(
          surface: "org",
          access_token: BrowserCredentialCookie.read(cookies, OidcRpBrowserCredentialContract::ACCESS_COOKIE),
          persona: Actor.selection.account_public_id,
        ).dashboard_identity
        raise ActiveRecord::RecordNotFound, "selected org Persona is not available to this principal" if
          result.status == :not_found
        raise RuntimeError, "Avatar owner is unavailable for the dashboard identity" unless result.ok?

        identity = { display_name: result.data.fetch("display_name") }
        # org Avatars are optional; without an Avatar or a stored image there is no image element.
        version = result.data["image_version"]
        identity[:avatar_image] = { src: base_org_dashboard_avatar_image_path(v: version) } if version
        identity
      end

      def menu_links
        [
          { label: t("base.shared.dashboard.links.preference"), href: base_org_identity_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.switcher"), href: base_org_switcher_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.logout"), href: new_base_org_sign_out_path(ri: params[:ri]) },
        ]
      end

      def primary_links
        [
          { label: t("base.shared.dashboard.links.root"), href: base_org_dashboard_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.account"), href: base_org_accounts_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.organization"), href: base_org_organizations_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.avatar"), href: base_org_avatar_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.identity"), href: base_org_identity_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.offline"), href: base_org_pwa_offline_path(ri: params[:ri]) },
        ]
      end

      def root_landing_props
        {
          title: nil,
          heading: "Base Org",
          description: t("landing.thin_endpoint"),
          # One neutral entry; any allowed switch to registration happens inside Auth.
          sign_in: { label: t("actions.continue"), href: base_org_sign_show_path(ri: params[:ri]) },
          sign_up: nil,
        }
      end
    end
  end
end
