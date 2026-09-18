# typed: false
# frozen_string_literal: true

module Base
  module Com
    class RootsController < Base::Com::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :open

      def index
        response.headers["Cache-Control"] = "private, no-store"
        return render_authenticated_home if logged_in?

        render inertia: true, props: root_landing_props
      end

      public

      def create
        return redirect_to(base_com_root_path(ri: params[:ri]), status: :see_other) if logged_in?

        intent = params[:intent].to_s
        return render plain: "invalid authentication intent", status: :bad_request unless %w(sign_in
                                                                                             sign_up).include?(intent)

        admission = BaseAuthAdmissionCoordinator.issue_local_entry!(surface: "com", intent: intent)
        auth_url =
          if intent == "sign_up"
            auth_com_sign_up_url(
              ri: params[:ri], host: oidc_sign_host, protocol: "https",
              admission: admission.code,
            )
          else
            auth_com_sign_in_url(
              ri: params[:ri], host: oidc_sign_host, protocol: "https",
              admission: admission.code,
            )
          end
        redirect_to_jump_url(auth_url, status: :see_other)
      rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError => e
        Rails.logger.error("[Base::Com::RootsController] local admission failed: #{e.class}")
        render plain: "authentication service unavailable", status: :service_unavailable
      end

      private

      def render_authenticated_home
        return unless require_selected_actor_context_for_root!

        authorize!(current_visitor, to: :show?)
        render inertia: "base/com/dashboards/show", props: dashboard_page_props
      end

      def require_selected_actor_context_for_root!
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
            { heading: t("base.shared.dashboard.sections.primary_links"), items: primary_links },
          ],
        }
      end

      def primary_links
        [
          { label: t("base.shared.dashboard.links.root"), href: base_com_root_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.account"), href: base_com_accounts_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.organization"), href: base_com_organizations_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.identity"), href: base_com_identity_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.selector"), href: base_com_selector_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.preference"), href: base_com_preference_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.offline"), href: base_com_pwa_offline_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.logout"), href: new_base_com_sign_out_path(ri: params[:ri]) },
        ]
      end

      def root_landing_props
        {
          title: "Base Com",
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
