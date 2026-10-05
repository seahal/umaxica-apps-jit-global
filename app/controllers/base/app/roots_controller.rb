# typed: false
# frozen_string_literal: true

module Base
  module App
    class RootsController < Base::App::ApplicationController
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
               clear_history: session.delete(:inertia_clear_history) == true
      end

      def show
        response.headers["Cache-Control"] = "private, no-store"
        authorize!(current_client, to: :show?)
        return unless require_selected_actor_context_for_dashboard!

        render inertia: "base/app/dashboards/show", props: dashboard_page_props
      end

      protected

      def track_authenticated_session_activity?
        return false if (request.get? || request.head?) && %w(index show).include?(action_name)

        super
      end

      private

      # Home/Dashboard resolve regional context without redirecting a direct request.
      def set_region
        return super unless (request.get? || request.head?) && %w(index show).include?(action_name)

        params[:ri] = normalized_param_ri.presence || get_region
      end

      def require_selected_actor_context_for_dashboard!
        return true if Actor.selection.selected?

        if request.format.json?
          render json: { status: "selection_required", next: base_app_selector_path(ri: params[:ri]) },
                 status: :forbidden
        else
          redirect_to(base_app_selector_path(ri: params[:ri]))
        end
        false
      end

      def dashboard_page_props
        {
          title: t("base.shared.dashboard.title"),
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

      def dashboard_current_identity
        persona = switcher.find_account(Actor.selection.account_public_id)
        raise ActiveRecord::RecordNotFound, "selected app Persona is not available to this principal" if persona.blank?

        display_name = persona.moniker
        raise RuntimeError, "selected app Persona has no display name" if display_name.blank?

        { display_name: display_name, avatar_image: dashboard_avatar_image }
      end

      # The app surface requires an Avatar; one without a stored image uses the static default.
      def dashboard_avatar_image
        avatar = switcher.selected_avatar || raise(RuntimeError, "selected app context has no Avatar")
        version = avatar.image ? avatar.image_cache_key : "default"

        { src: base_app_dashboard_avatar_image_path(v: version) }
      end

      def switcher
        @switcher ||= BaseSwitcherAuthority.new(
          surface: :app, principal: current_client, session: current_session,
        )
      end

      def menu_links
        [
          { label: t("base.shared.dashboard.links.preference"), href: base_app_preference_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.switcher"), href: base_app_switcher_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.logout"), href: new_base_app_sign_out_path(ri: params[:ri]) },
        ]
      end

      def primary_links
        [
          { label: t("base.shared.dashboard.links.root"), href: base_app_dashboard_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.account"), href: base_app_accounts_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.organization"), href: base_app_organizations_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.avatar"), href: base_app_avatars_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.identity"), href: base_app_identity_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.billings"), href: base_app_billings_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.groups"), href: base_app_groups_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.offline"), href: base_app_pwa_offline_path(ri: params[:ri]) },
        ]
      end

      def root_landing_props
        {
          title: nil,
          heading: "Base App",
          description: t("landing.thin_endpoint"),
          # One neutral entry; any allowed switch to registration happens inside Auth.
          sign_in: { label: t("actions.continue"), href: base_app_sign_show_path(ri: params[:ri]) },
          sign_up: nil,
        }
      end
    end
  end
end
