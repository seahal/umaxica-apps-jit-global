# typed: false
# frozen_string_literal: true

module Base
  module Com
    class RootsController < Base::Com::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :open
      skip_before_action :set_preferences_cookie, only: %i(index show)

      public

      def index
        response.headers["Cache-Control"] = "private, no-store"
        raise ActiveRecord::RecordNotFound if logged_in?

        render inertia: true, props: root_landing_props,
               clear_history: session.delete(:inertia_clear_history) == true
      end

      def show
        response.headers["Cache-Control"] = "private, no-store"
        raise ActiveRecord::RecordNotFound unless logged_in?
        return unless require_selected_actor_context_for_dashboard!

        authorize!(current_visitor, to: :show?)
        render inertia: "base/com/dashboards/show", props: dashboard_page_props
      end

      def create
        return redirect_to(base_com_dashboard_path(ri: params[:ri]), status: :see_other) if logged_in?

        intent = params[:intent].to_s
        return render plain: "invalid authentication intent", status: :bad_request unless %w(sign_in
                                                                                             sign_up).include?(intent)

        admission = BaseAuthAdmissionCoordinator.issue_local_entry!(surface: "com", intent: intent)
        auth_url =
          if intent == "sign_up"
            auth_com_sign_up_url(
              ri: params[:ri], host: oidc_sign_host, protocol: "https",
              entry_ref: admission.reference,
            )
          else
            auth_com_sign_in_url(
              ri: params[:ri], host: oidc_sign_host, protocol: "https",
              entry_ref: admission.reference,
            )
          end
        redirect_to_jump_url(auth_url, status: :see_other)
      rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError => e
        Rails.logger.error("[Base::Com::RootsController] local admission failed: #{e.class}")
        render plain: "authentication service unavailable", status: :service_unavailable
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

      # The sign-in/sign-up start POST only issues an admission; it needs no preference authority,
      # so a stale preference credential must not refuse it.
      def preference_entry_recovery_action?
        action_name == "create"
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

      def dashboard_current_identity
        persona = switcher.find_account(Actor.selection.account_public_id)
        raise ActiveRecord::RecordNotFound, "selected com Persona is not available to this principal" if persona.blank?

        display_name = persona.moniker
        raise "selected com Persona has no display name" if display_name.blank?

        { display_name: display_name }
      end

      def switcher
        @switcher ||= BaseSwitcherAuthority.new(
          surface: :com, principal: current_visitor, session: current_session,
        )
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
          sign_in: local_entry_props("Sign in", "sign_in"),
          sign_up: local_entry_props("Sign up", "sign_up"),
        }
      end

      def local_entry_props(label, intent)
        {
          label: label,
          action: base_com_root_authentication_path(ri: params[:ri]),
          method: "post",
          intent: intent,
          authenticity_token: form_authenticity_token,
        }
      end
    end
  end
end
