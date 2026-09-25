# typed: false
# frozen_string_literal: true

module Base
  module Org
    class RootsController < Base::Org::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :open
      skip_before_action :set_preferences_cookie, only: %i(index show)

      public

      def index
        response.headers["Cache-Control"] = "private, no-store"
        return render_authenticated_home if logged_in?

        render inertia: true, props: root_landing_props
      end

      def show
        response.headers["Cache-Control"] = "private, no-store"
        return redirect_to(base_org_root_path(ri: params[:ri]), status: :see_other) unless logged_in?

        render_authenticated_home
      end

      def create
        return redirect_to(base_org_root_path(ri: params[:ri]), status: :see_other) if logged_in?

        intent = params[:intent].to_s
        return render plain: "invalid authentication intent", status: :bad_request unless %w(sign_in
                                                                                             sign_up).include?(intent)

        admission = BaseAuthAdmissionCoordinator.issue_local_entry!(surface: "org", intent: intent)
        auth_url =
          if intent == "sign_up"
            auth_org_sign_up_url(
              ri: params[:ri], host: oidc_sign_host, protocol: "https",
              entry_ref: admission.reference,
            )
          else
            auth_org_sign_in_url(
              ri: params[:ri], host: oidc_sign_host, protocol: "https",
              entry_ref: admission.reference,
            )
          end
        redirect_to_jump_url(auth_url, status: :see_other)
      rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError => e
        Rails.logger.error("[Base::Org::RootsController] local admission failed: #{e.class}")
        render plain: "authentication service unavailable", status: :service_unavailable
      end

      protected

      def track_authenticated_session_activity?
        return false if (request.get? || request.head?) && %w(index show).include?(action_name)

        super
      end

      private

      def render_authenticated_home
        return unless require_selected_actor_context_for_root!

        authorize!(current_operator, to: :show?)
        render inertia: "base/org/dashboards/show", props: dashboard_page_props
      end

      def require_selected_actor_context_for_root!
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
          ],
        }
      end

      def dashboard_current_identity
        persona = switcher.find_account(Actor.selection.account_public_id)
        raise ActiveRecord::RecordNotFound, "selected org Persona is not available to this principal" if persona.blank?

        display_name = persona.moniker
        raise "selected org Persona has no display name" if display_name.blank?

        { display_name: display_name }
      end

      def switcher
        @switcher ||= BaseSwitcherAuthority.new(
          surface: :org, principal: current_operator, session: current_session,
        )
      end

      def menu_links
        [
          { label: t("base.shared.dashboard.links.preference"), href: base_org_preference_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.switcher"), href: base_org_switcher_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.logout"), href: new_base_org_sign_out_path(ri: params[:ri]) },
        ]
      end

      def primary_links
        [
          { label: t("base.shared.dashboard.links.root"), href: base_org_root_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.account"), href: base_org_accounts_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.organization"), href: base_org_organizations_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.avatar"), href: base_org_avatar_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.identity"), href: base_org_identity_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.offline"), href: base_org_pwa_offline_path(ri: params[:ri]) },
        ]
      end

      def root_landing_props
        {
          title: "Base Org",
          heading: "Base Org",
          description: t("landing.thin_endpoint"),
          sign_in: local_entry_props("Sign in", "sign_in"),
          sign_up: local_entry_props("Sign up", "sign_up"),
        }
      end

      def local_entry_props(label, intent)
        {
          label: label,
          action: base_org_root_authentication_path(ri: params[:ri]),
          method: "post",
          intent: intent,
          authenticity_token: form_authenticity_token,
        }
      end
    end
  end
end
